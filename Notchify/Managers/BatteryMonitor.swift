import Foundation
import IOKit
import IOKit.hid
import IOKit.ps


class BatteryMonitor {
    static let shared = BatteryMonitor()
    
    var onPowerStateChanged: ((_ isAC: Bool, _ isCharging: Bool, _ level: Int) -> Void)?
    
    private(set) var currentIsAC: Bool = true
    private(set) var currentLevel: Int = 100
    private(set) var currentIsCharging: Bool = false
    
    private var lastIsAC: Bool = true
    private var lastLevel: Int = 100
    private var lastIsCharging: Bool = false
    private var isFirstCheck = true
    
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?
    
    private init() {}
    
    func start() {
        let info = readPowerInfo()
        self.lastIsAC = info.isAC
        self.lastLevel = info.level
        self.lastIsCharging = info.isCharging
        self.currentIsAC = info.isAC
        self.currentLevel = info.level
        self.currentIsCharging = info.isCharging
        self.isFirstCheck = false
        
        // Setup IOKit Power Source notification
        let context = Unmanaged.passUnretained(self).toOpaque()
        let loopSource = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.evaluatePowerChange()
        }, context)
        
        if let source = loopSource?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            self.runLoopSource = source
        }
        
        // Fallback polling timer (every 2.0s) for robust Hackintosh hardware EC compatibility
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.evaluatePowerChange()
        }
    }
    
    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    func evaluatePowerChange() {
        let info = readPowerInfo()
        self.currentIsAC = info.isAC
        self.currentLevel = info.level
        self.currentIsCharging = info.isCharging
        
        guard !isFirstCheck else { return }
        
        let acChanged = (lastIsAC != info.isAC)
        let chargingStarted = (info.isAC && !lastIsCharging && info.isCharging)
        
        if acChanged || chargingStarted {
            self.lastIsAC = info.isAC
            self.lastLevel = info.level
            self.lastIsCharging = info.isCharging
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onPowerStateChanged?(info.isAC, info.isCharging, info.level)
            }
        } else {
            self.lastLevel = info.level
            self.lastIsCharging = info.isCharging
        }
    }
    
    func readPowerInfo() -> (isAC: Bool, isCharging: Bool, level: Int) {
        var isAC = true
        var level = 100
        var isCharging = false
        var foundBattery = false
        
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeRetainedValue() as? String
            if type == (kIOPSBatteryPowerValue as String) {
                isAC = false
            } else if type == (kIOPSACPowerValue as String) {
                isAC = true
            }
            
            if let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
                for ps in sources {
                    if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                        if let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                            if state == (kIOPSACPowerValue as String) {
                                isAC = true
                            } else if state == (kIOPSBatteryPowerValue as String) {
                                isAC = false
                            }
                        }
                        if let curCap = desc[kIOPSCurrentCapacityKey as String] as? Int,
                           let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
                           maxCap > 0 {
                            level = min(100, max(0, Int((Double(curCap) / Double(maxCap)) * 100)))
                            foundBattery = true
                        }
                        if let charging = desc[kIOPSIsChargingKey as String] as? Bool {
                            isCharging = charging
                        }
                    }
                }
            }
        }
        
        // If IOKit.ps list did not report battery details, read directly from IOKit AppleSmartBattery registry
        if !foundBattery {
            let smart = readAppleSmartBattery()
            if let ac = smart.isAC { isAC = ac }
            if let lvl = smart.level { level = lvl }
            if let chg = smart.isCharging { isCharging = chg }
        }
        
        return (isAC, isCharging, level)
    }
    
    private func readAppleSmartBattery() -> (isAC: Bool?, isCharging: Bool?, level: Int?) {
        let matching = IOServiceMatching("AppleSmartBattery")
        let service = IOServiceGetMatchingService(0, matching)
        guard service != 0 else { return (nil, nil, nil) }
        defer { IOObjectRelease(service) }
        
        var propDict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propDict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = propDict?.takeRetainedValue() as? [String: Any] else {
            return (nil, nil, nil)
        }
        
        let isAC = props["ExternalConnected"] as? Bool
        let isCharging = props["IsCharging"] as? Bool
        var level: Int? = nil
        if let curCap = props["CurrentCapacity"] as? Int,
           let maxCap = props["MaxCapacity"] as? Int,
           maxCap > 0 {
            level = min(100, Swift.max(0, Int((Double(curCap) / Double(maxCap)) * 100)))
        }
        return (isAC, isCharging, level)
    }
}
