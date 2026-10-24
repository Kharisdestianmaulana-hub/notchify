import Foundation
import IOKit
import IOKit.hid


class HardwareMonitor {
    static let shared = HardwareMonitor()
    
    var onDeviceConnected: ((String) -> Void)?
    var onDeviceDisconnected: ((String) -> Void)?
    
    private var hidManager: IOHIDManager?
    
    private init() {}
    
    func start() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else { return }
        
        IOHIDManagerSetDeviceMatching(manager, nil) // Match all HID devices
        
        // Setup Callbacks
        let connectCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let mySelf = Unmanaged<HardwareMonitor>.fromOpaque(context!).takeUnretainedValue()
            if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                DispatchQueue.main.async {
                    mySelf.onDeviceConnected?(name)
                }
            }
        }
        
        let disconnectCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let mySelf = Unmanaged<HardwareMonitor>.fromOpaque(context!).takeUnretainedValue()
            if let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                DispatchQueue.main.async {
                    mySelf.onDeviceDisconnected?(name)
                }
            }
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, connectCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, disconnectCallback, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    func stop() {
        guard let manager = hidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
}
