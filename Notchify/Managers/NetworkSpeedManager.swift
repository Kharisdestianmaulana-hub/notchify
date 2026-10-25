import Foundation
import SystemConfiguration
import CoreWLAN
import Network
import SwiftUI

class NetworkSpeedManager: ObservableObject {
    static let shared = NetworkSpeedManager()
    
    @Published var downloadSpeed: Double = 0.0
    @Published var uploadSpeed: Double = 0.0
    @Published var downloadHistory: [CGFloat] = Array(repeating: 0, count: 16)
    @Published var uploadHistory: [CGFloat] = Array(repeating: 0, count: 16)
    
    @Published var wifiSSID: String = "Wi-Fi"
    @Published var signalBars: Int = 3
    @Published var frequencyBand: String = "5 GHz"
    @Published var pingMs: Int = 24
    @Published var localIP: String = "127.0.0.1"
    @Published var publicIP: String = "..."
    @Published var isFetchingPublicIP: Bool = false
    
    var signalIcon: String {
        switch signalBars {
        case 1: return "wifi.exclamationmark"
        case 2: return "wifi"
        case 3: return "wifi"
        default: return "wifi"
        }
    }
    
    var pingColor: Color {
        if pingMs <= 50 { return .green }
        if pingMs <= 120 { return .yellow }
        return .red
    }
    
    private var timer: Timer?
    private var prevInBytes: UInt64 = 0
    private var prevOutBytes: UInt64 = 0
    private var lastSampleTime: Date = Date()
    
    private init() {
        refreshIPs()
        checkWiFi()
        testPing()
    }
    
    func startMonitoring() {
        stopMonitoring()
        sampleBytes()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        refreshIPs()
        checkWiFi()
        testPing()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        let (inBytes, outBytes) = getNetworkBytes()
        let now = Date()
        let interval = max(now.timeIntervalSince(lastSampleTime), 0.5)
        lastSampleTime = now
        
        if prevInBytes > 0 && inBytes >= prevInBytes {
            let dBytes = inBytes - prevInBytes
            let speed = Double(dBytes) / interval
            DispatchQueue.main.async {
                self.downloadSpeed = speed
                self.downloadHistory.removeFirst()
                self.downloadHistory.append(CGFloat(speed))
            }
        }
        if prevOutBytes > 0 && outBytes >= prevOutBytes {
            let uBytes = outBytes - prevOutBytes
            let speed = Double(uBytes) / interval
            DispatchQueue.main.async {
                self.uploadSpeed = speed
                self.uploadHistory.removeFirst()
                self.uploadHistory.append(CGFloat(speed))
            }
        }
        prevInBytes = inBytes
        prevOutBytes = outBytes
        
        if Int(Date().timeIntervalSince1970) % 5 == 0 {
            checkWiFi()
            testPing()
        }
    }
    
    private func sampleBytes() {
        let (inBytes, outBytes) = getNetworkBytes()
        prevInBytes = inBytes
        prevOutBytes = outBytes
        lastSampleTime = Date()
    }
    
    private func getNetworkBytes() -> (UInt64, UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }
        
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            let name = String(cString: ifa.ifa_name)
            guard !name.hasPrefix("lo"), (name.hasPrefix("en") || name.hasPrefix("bridge") || name.hasPrefix("pdp_ip")) else { continue }
            
            if ifa.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = ifa.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(networkData.ifi_ibytes)
                    totalOut += UInt64(networkData.ifi_obytes)
                }
            }
        }
        return (totalIn, totalOut)
    }
    
    func checkWiFi() {
        if let client = CWWiFiClient.shared().interface() {
            let ssid = client.ssid() ?? "Wi-Fi Connected"
            let rssi = client.rssiValue()
            let band = client.wlanChannel()?.channelBand == .band2GHz ? "2.4 GHz" : (client.wlanChannel()?.channelBand == .band5GHz ? "5 GHz" : "Wi-Fi")
            
            var bars = 3
            if rssi < -80 { bars = 1 }
            else if rssi < -70 { bars = 2 }
            else if rssi < -55 { bars = 3 }
            else { bars = 4 }
            
            DispatchQueue.main.async {
                self.wifiSSID = ssid
                self.signalBars = bars
                self.frequencyBand = band
            }
        } else {
            DispatchQueue.main.async {
                self.wifiSSID = "Network Active"
                self.signalBars = 4
                self.frequencyBand = "LAN"
            }
        }
    }
    
    func refreshIPs() {
        var localAddress = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name.hasPrefix("en") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        localAddress = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        DispatchQueue.main.async {
            self.localIP = localAddress
        }
        
        guard !isFetchingPublicIP else { return }
        isFetchingPublicIP = true
        guard let url = URL(string: "https://api.ipify.org") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isFetchingPublicIP = false
                if let data = data, let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !ip.isEmpty {
                    self?.publicIP = ip
                } else if self?.publicIP == "..." {
                    self?.publicIP = "Unavailable"
                }
            }
        }.resume()
    }
    
    func testPing() {
        guard let url = URL(string: "https://1.1.1.1") else { return }
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0
        
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            DispatchQueue.main.async {
                self?.pingMs = max(ms, 8)
            }
        }.resume()
    }
    
    static func formatSpeed(_ bytesPerSec: Double) -> (value: String, unit: String) {
        if bytesPerSec >= 1_048_576 {
            return (String(format: "%.1f", bytesPerSec / 1_048_576), "MB/s")
        } else if bytesPerSec >= 1024 {
            return (String(format: "%.0f", bytesPerSec / 1024), "KB/s")
        } else {
            return (String(format: "%.0f", bytesPerSec), "B/s")
        }
    }
}

enum NetworkSubMode: String, CaseIterable {
    case radar = "Radar"
    case speedtest = "Speed Test"
    
    var localizedTitle: String {
        switch self {
        case .radar: return LanguageManager.tr("Radar")
        case .speedtest: return LanguageManager.tr("Speed Test")
        }
    }
}

enum SpeedTestPhase: Equatable {
    case idle
    case pinging
    case downloading
    case uploading
    case completed
    case failed
}

class SpeedTestManager: NSObject, ObservableObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    static let shared = SpeedTestManager()
    
    @Published var phase: SpeedTestPhase = .idle
    @Published var liveSpeedMbps: Double = 0.0
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = ""
    
    @Published var pingResultMs: Int = 0
    @Published var downloadResultMbps: Double = 0.0
    @Published var uploadResultMbps: Double = 0.0
    
    // Historical results saved in UserDefaults
    @Published var lastDownload: Double = UserDefaults.standard.double(forKey: "lastSpeedTestDown")
    @Published var lastUpload: Double = UserDefaults.standard.double(forKey: "lastSpeedTestUp")
    @Published var lastPing: Int = UserDefaults.standard.integer(forKey: "lastSpeedTestPing")
    @Published var lastTimestamp: Double = UserDefaults.standard.double(forKey: "lastSpeedTestTime")
    
    private var activeSession: URLSession?
    private var currentTask: URLSessionTask?
    private var phaseTimer: Timer?
    private let targetDownloadDuration: TimeInterval = 4.5
    private let targetUploadDuration: TimeInterval = 3.5
    
    private var phaseStartTime: Date = Date()
    private var bytesTransferred: Int64 = 0
    private var expectedTotalBytes: Int64 = 50_000_000
    private var isCancelled: Bool = false
    
    override init() {
        super.init()
    }
    
    func startTest() {
        guard phase == .idle || phase == .completed || phase == .failed else { return }
        isCancelled = false
        phase = .pinging
        liveSpeedMbps = 0.0
        progress = 0.0
        statusMessage = LanguageManager.tr("Testing Ping...")
        
        runPingMeasurement { [weak self] avgPing in
            guard let self = self, !self.isCancelled else { return }
            self.pingResultMs = avgPing
            self.startDownloadTest()
        }
    }
    
    func cancelTest() {
        isCancelled = true
        phaseTimer?.invalidate()
        phaseTimer = nil
        currentTask?.cancel()
        currentTask = nil
        activeSession?.invalidateAndCancel()
        activeSession = nil
        phase = .idle
        liveSpeedMbps = 0.0
        progress = 0.0
        statusMessage = ""
    }
    
    private func runPingMeasurement(completion: @escaping (Int) -> Void) {
        var samples: [Int] = []
        let group = DispatchGroup()
        
        for i in 0..<3 {
            group.enter()
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.15) { [weak self] in
                guard let self = self, !self.isCancelled else {
                    group.leave()
                    return
                }
                guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0") else {
                    group.leave()
                    return
                }
                var req = URLRequest(url: url)
                req.httpMethod = "HEAD"
                req.timeoutInterval = 3.0
                
                let start = Date()
                let task = URLSession.shared.dataTask(with: req) { _, _, _ in
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    if ms > 0 { samples.append(ms) }
                    group.leave()
                }
                task.resume()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            let avg = samples.isEmpty ? 22 : (samples.reduce(0, +) / samples.count)
            completion(avg)
        }
    }
    
    private func startDownloadTest() {
        phase = .downloading
        statusMessage = LanguageManager.tr("Testing Download...")
        bytesTransferred = 0
        expectedTotalBytes = 50_000_000 // 50 MB stream for sustained testing
        phaseStartTime = Date()
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15.0
        activeSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(expectedTotalBytes)") else {
            failTest(reason: "Invalid URL")
            return
        }
        
        let task = activeSession?.dataTask(with: url)
        currentTask = task
        task?.resume()
        
        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self = self, self.phase == .downloading, !self.isCancelled else {
                t.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(self.phaseStartTime)
            self.progress = min(elapsed / self.targetDownloadDuration, 0.99)
            if elapsed >= self.targetDownloadDuration {
                t.invalidate()
                self.phaseTimer = nil
                self.finishDownloadPhase()
            }
        }
    }
    
    private func finishDownloadPhase() {
        guard phase == .downloading, !isCancelled else { return }
        phaseTimer?.invalidate()
        phaseTimer = nil
        currentTask?.cancel()
        currentTask = nil
        let elapsed = max(Date().timeIntervalSince(phaseStartTime), 0.2)
        let finalMbps = (Double(bytesTransferred) * 8.0) / (elapsed * 1_000_000.0)
        downloadResultMbps = max(finalMbps, 0.5)
        progress = 1.0
        liveSpeedMbps = downloadResultMbps
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.startUploadTest()
        }
    }
    
    private func startUploadTest() {
        phase = .uploading
        statusMessage = LanguageManager.tr("Testing Upload...")
        bytesTransferred = 0
        expectedTotalBytes = 25_000_000 // 25 MB payload
        phaseStartTime = Date()
        
        let dummyData = Data(count: Int(expectedTotalBytes))
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else {
            failTest(reason: "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0
        
        let task = activeSession?.uploadTask(with: request, from: dummyData)
        currentTask = task
        task?.resume()
        
        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self = self, self.phase == .uploading, !self.isCancelled else {
                t.invalidate()
                return
            }
            let elapsed = Date().timeIntervalSince(self.phaseStartTime)
            self.progress = min(elapsed / self.targetUploadDuration, 0.99)
            if elapsed >= self.targetUploadDuration {
                t.invalidate()
                self.phaseTimer = nil
                self.finishUploadPhase()
            }
        }
    }
    
    private func finishUploadPhase() {
        guard phase == .uploading, !isCancelled else { return }
        phaseTimer?.invalidate()
        phaseTimer = nil
        currentTask?.cancel()
        currentTask = nil
        let elapsed = max(Date().timeIntervalSince(phaseStartTime), 0.2)
        let finalMbps = (Double(bytesTransferred) * 8.0) / (elapsed * 1_000_000.0)
        uploadResultMbps = max(finalMbps, 0.5)
        progress = 1.0
        liveSpeedMbps = uploadResultMbps
        completeTest()
    }
    
    // MARK: - URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard phase == .downloading, !isCancelled else { return }
        bytesTransferred += Int64(data.count)
        let elapsed = max(Date().timeIntervalSince(phaseStartTime), 0.05)
        let mbps = (Double(bytesTransferred) * 8.0) / (elapsed * 1_000_000.0)
        
        DispatchQueue.main.async {
            self.liveSpeedMbps = mbps
        }
    }
    
    // MARK: - URLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard phase == .uploading, !isCancelled else { return }
        bytesTransferred = totalBytesSent
        let elapsed = max(Date().timeIntervalSince(phaseStartTime), 0.05)
        let mbps = (Double(totalBytesSent) * 8.0) / (elapsed * 1_000_000.0)
        
        DispatchQueue.main.async {
            self.liveSpeedMbps = mbps
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isCancelled else { return }
        
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled { return }
            DispatchQueue.main.async {
                self.failTest(reason: error.localizedDescription)
            }
            return
        }
        
        DispatchQueue.main.async {
            if self.phase == .downloading {
                self.finishDownloadPhase()
            } else if self.phase == .uploading {
                self.finishUploadPhase()
            }
        }
    }
    
    private func completeTest() {
        phase = .completed
        statusMessage = LanguageManager.tr("Test Completed")
        liveSpeedMbps = 0.0
        
        lastDownload = downloadResultMbps
        lastUpload = uploadResultMbps
        lastPing = pingResultMs
        lastTimestamp = Date().timeIntervalSince1970
        
        UserDefaults.standard.set(lastDownload, forKey: "lastSpeedTestDown")
        UserDefaults.standard.set(lastUpload, forKey: "lastSpeedTestUp")
        UserDefaults.standard.set(lastPing, forKey: "lastSpeedTestPing")
        UserDefaults.standard.set(lastTimestamp, forKey: "lastSpeedTestTime")
    }
    
    private func failTest(reason: String) {
        phase = .failed
        statusMessage = LanguageManager.tr("Test Failed")
        liveSpeedMbps = 0.0
        progress = 0.0
    }
}

