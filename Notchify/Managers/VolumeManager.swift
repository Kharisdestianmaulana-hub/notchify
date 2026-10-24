import Cocoa
import CoreGraphics
import AudioToolbox
import CoreAudio


class VolumeManager {
    static let shared = VolumeManager()
    
    var onVolumeChanged: ((Float) -> Void)?
    private var eventTap: CFMachPort?
    
    private init() {}
    
    func start() {
        // Accessibility permissions check
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("Accessibility not granted")
        }
        
        // systemDefined is 14
        let mask = (1 << UInt64(14))
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            if type.rawValue == 14 {
                let nsEvent = NSEvent(cgEvent: event)
                guard let nsEvent = nsEvent, nsEvent.type == .systemDefined else { return Unmanaged.passUnretained(event) }
                let data1 = nsEvent.data1
                let keyCode = (data1 & 0xFFFF0000) >> 16
                let keyFlags = (data1 & 0x0000FFFF)
                let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA
                
                let manager = Unmanaged<VolumeManager>.fromOpaque(refcon!).takeUnretainedValue()
                
                if keyState {
                    // 0 = SoundUp, 1 = SoundDown, 7 = Mute
                    if keyCode == 0 || keyCode == 1 || keyCode == 7 {
                        manager.handleVolumeKey(Int(keyCode))
                        return nil // Swallow event
                    }
                } else {
                    // Handle key up for swallow as well to prevent beep
                    if keyCode == 0 || keyCode == 1 || keyCode == 7 {
                        return nil
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    private func getSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutputDeviceID)
        
        var volume: Float32 = 0.0
        var volSize = UInt32(MemoryLayout.size(ofValue: volume))
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        if AudioObjectHasProperty(defaultOutputDeviceID, &volAddress) {
            AudioObjectGetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, &volSize, &volume)
        }
        return volume
    }
    
    private func setSystemVolume(_ volume: Float) {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &defaultOutputDeviceID)
        
        var newVolume = max(0.0, min(1.0, volume))
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        
        if AudioObjectHasProperty(defaultOutputDeviceID, &volAddress) {
            AudioObjectSetPropertyData(defaultOutputDeviceID, &volAddress, 0, nil, UInt32(MemoryLayout.size(ofValue: newVolume)), &newVolume)
        }
    }
    
    private func handleVolumeKey(_ key: Int) {
        var currentVol = getSystemVolume()
        let step: Float = 0.0625 // 1/16th like default macOS
        
        if key == 0 { // UP
            currentVol += step
        } else if key == 1 { // DOWN
            currentVol -= step
        } else if key == 7 { // MUTE
            currentVol = (currentVol > 0.0) ? 0.0 : 0.2
        }
        
        setSystemVolume(currentVol)
        
        DispatchQueue.main.async {
            self.onVolumeChanged?(currentVol)
        }
    }
}
