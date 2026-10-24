import Foundation
import CoreAudio
import CoreMediaIO
import AppKit
import SwiftUI

class PrivacyMonitor: ObservableObject {
    static let shared = PrivacyMonitor()
    
    @Published var isCameraActive: Bool = false
    @Published var isMicActive: Bool = false
    
    private var manualCameraOverride: Bool? = nil
    private var manualMicOverride: Bool? = nil
    private var monitorTimer: Timer?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        checkDevices()
        setupAudioListener()
        
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkDevices()
        }
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    func toggleCamera() {
        if let current = manualCameraOverride {
            manualCameraOverride = !current
        } else {
            manualCameraOverride = !isCameraActive
        }
        checkDevices()
    }
    
    func toggleMic() {
        if let current = manualMicOverride {
            manualMicOverride = !current
        } else {
            manualMicOverride = !isMicActive
        }
        checkDevices()
    }
    
    func resolveActiveApp() -> String {
        if CameraMirrorManager.shared.isRunning || CameraMirrorManager.shared.isRecordingVideo {
            return "Notchify"
        }
        
        let ws = NSWorkspace.shared
        let frontmost = ws.frontmostApplication
        let frontBundle = frontmost?.bundleIdentifier?.lowercased() ?? ""
        let frontName = frontmost?.localizedName ?? ""
        
        let videoAudioApps: [(keyword: String, name: String)] = [
            ("facetime", "FaceTime"),
            ("photobooth", "Photo Booth"),
            ("zoom", "Zoom"),
            ("teams", "Microsoft Teams"),
            ("webex", "Webex"),
            ("skype", "Skype"),
            ("slack", "Slack"),
            ("discord", "Discord"),
            ("chrome", "Google Chrome"),
            ("safari", "Safari"),
            ("brave", "Brave"),
            ("edge", "Microsoft Edge"),
            ("quicktime", "QuickTime Player"),
            ("voicememos", "Voice Memos"),
            ("logic", "Logic Pro"),
            ("garageband", "GarageBand"),
            ("obs", "OBS Studio"),
            ("telegram", "Telegram"),
            ("whatsapp", "WhatsApp")
        ]
        
        for item in videoAudioApps {
            if frontBundle.contains(item.keyword) || frontName.lowercased().contains(item.keyword) {
                return item.name
            }
        }
        
        let running = ws.runningApplications.filter { $0.activationPolicy == .regular }
        for item in videoAudioApps {
            if let matched = running.first(where: {
                let b = $0.bundleIdentifier?.lowercased() ?? ""
                let n = $0.localizedName?.lowercased() ?? ""
                return b.contains(item.keyword) || n.contains(item.keyword)
            }) {
                return matched.localizedName ?? item.name
            }
        }
        
        if let front = frontmost, let name = front.localizedName, !name.isEmpty && name != "Finder" {
            return name
        }
        
        return isCameraActive ? LanguageManager.tr("System Camera") : LanguageManager.tr("System Microphone")
    }
    
    @objc func checkDevices() {
        let cameraRunning = manualCameraOverride ?? checkIfAnyCameraIsInUse()
        let micRunning = manualMicOverride ?? checkIfAnyMicIsInUse()
        
        DispatchQueue.main.async {
            if self.isCameraActive != cameraRunning {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65)) {
                    self.isCameraActive = cameraRunning
                }
            }
            if self.isMicActive != micRunning {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65)) {
                    self.isMicActive = micRunning
                }
            }
        }
    }
    
    // MARK: - CoreMediaIO Camera Detection
    private func checkIfAnyCameraIsInUse() -> Bool {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        var status = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == 0 && dataSize > 0 else { return false }
        
        let deviceCount = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        guard deviceCount > 0 else { return false }
        var devices = [CMIODeviceID](repeating: 0, count: deviceCount)
        var dataUsed: UInt32 = 0
        
        status = CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &dataUsed,
            &devices
        )
        guard status == 0 else { return false }
        
        for deviceId in devices {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            var isRunning: UInt32 = 0
            let runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningUsed: UInt32 = 0
            
            let runningStatus = CMIOObjectGetPropertyData(
                deviceId,
                &runningAddress,
                0,
                nil,
                runningSize,
                &runningUsed,
                &isRunning
            )
            if runningStatus == 0 && isRunning != 0 {
                return true
            }
        }
        return false
    }
    
    // MARK: - CoreAudio Microphone Detection
    private func setupAudioListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.checkDevices()
        }
    }
    
    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        return status == noErr ? deviceID : kAudioObjectUnknown
    }
    
    private func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        guard deviceID != kAudioObjectUnknown else { return false }
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &runningAddress,
            0,
            nil,
            &size,
            &isRunning
        )
        return status == noErr && isRunning != 0
    }
    
    private func checkIfAnyMicIsInUse() -> Bool {
        // 1. Check Default Input Device
        let defaultDev = getDefaultInputDeviceID()
        if defaultDev != kAudioObjectUnknown && isDeviceRunning(defaultDev) {
            return true
        }
        
        // 2. Check all other audio devices that have input streams
        var allDevicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var allDevicesSize: UInt32 = 0
        if AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &allDevicesAddress, 0, nil, &allDevicesSize) == noErr && allDevicesSize > 0 {
            let count = Int(allDevicesSize) / MemoryLayout<AudioDeviceID>.size
            var devices = [AudioDeviceID](repeating: 0, count: count)
            if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &allDevicesAddress, 0, nil, &allDevicesSize, &devices) == noErr {
                for dev in devices {
                    guard dev != defaultDev else { continue }
                    var streamAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyStreams,
                        mScope: kAudioObjectPropertyScopeInput,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    var streamSize: UInt32 = 0
                    if AudioObjectGetPropertyDataSize(dev, &streamAddress, 0, nil, &streamSize) == noErr && streamSize > 0 {
                        var outStreamAddress = AudioObjectPropertyAddress(
                            mSelector: kAudioDevicePropertyStreams,
                            mScope: kAudioObjectPropertyScopeOutput,
                            mElement: kAudioObjectPropertyElementMain
                        )
                        var outStreamSize: UInt32 = 0
                        let hasOutput = AudioObjectGetPropertyDataSize(dev, &outStreamAddress, 0, nil, &outStreamSize) == noErr && outStreamSize > 0
                        if !hasOutput && isDeviceRunning(dev) {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
}
