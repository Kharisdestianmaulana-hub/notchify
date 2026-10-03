import Foundation
import CoreMediaIO
import CoreAudio

func isCameraOn() -> Bool {
    var opa = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )
    var dataSize: UInt32 = 0
    var dataUsed: UInt32 = 0
    CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize)
    let deviceCount = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
    var devices = [CMIODeviceID](repeating: 0, count: deviceCount)
    CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataUsed, &devices)
    
    for device in devices {
        var runningOpa = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if CMIOObjectGetPropertyData(device, &runningOpa, 0, nil, size, &dataUsed, &isRunning) == 0 {
            if isRunning == 1 { return true }
        }
    }
    return false
}

func isMicOn() -> Bool {
    var opa = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID = kAudioObjectUnknown
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &opa, 0, nil, &size, &deviceID)
    
    if deviceID != kAudioObjectUnknown {
        var runningOpa = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeWildcard,
            mElement: kAudioObjectPropertyElementWildcard
        )
        var isRunning: UInt32 = 0
        var rSize = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(deviceID, &runningOpa, 0, nil, &rSize, &isRunning) == 0 {
            return isRunning != 0
        }
    }
    return false
}

print("Camera On: \(isCameraOn())")
print("Mic On: \(isMicOn())")
