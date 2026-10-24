import Foundation
import Darwin


// MARK: - System Monitor
class SystemMonitor {
    static func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }
        
        var totalUser: Int32 = 0, totalSystem: Int32 = 0, totalIdle: Int32 = 0
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += info[offset + Int(CPU_STATE_USER)]
            totalSystem += info[offset + Int(CPU_STATE_SYSTEM)]
            totalIdle += info[offset + Int(CPU_STATE_IDLE)]
        }
        
        let total = Double(totalUser + totalSystem + totalIdle)
        let used = Double(totalUser + totalSystem)
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride))
        
        return total > 0 ? (used / total) * 100 : 0
    }
    
    static func getMemoryUsage() -> (used: Double, total: Double, percent: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0, 0) }
        
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        
        let used = active + wired + compressed
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let percent = (used / total) * 100
        
        return (used, total, percent)
    }
    
    static func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }
}
