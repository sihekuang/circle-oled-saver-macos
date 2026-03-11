import Foundation
import IOKit.ps

public final class SystemInfoProvider: BaseContentProvider {
    private let showBattery: Bool

    public override var refreshInterval: TimeInterval { 2.0 }

    public init(showBattery: Bool = true) {
        self.showBattery = showBattery
        super.init()
    }

    public override func fetchData() async {
        let cpu = Self.cpuUsage()
        let mem = Self.memoryUsage()

        var text = "\u{2699}\u{FE0F} \(cpu)%  \u{1F4BE} \(mem.used)/\(mem.total) GB"

        if showBattery, let battery = Self.batteryLevel() {
            text += "\n\u{1F50B} \(battery)%"
        }

        cachedData = ContentData(
            icon: "\u{1F4CA}",
            text: text
        )
    }

    // MARK: - System Info Helpers

    private static func cpuUsage() -> Int {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }

        var totalLoad: Int32 = 0
        var totalTicks: Int32 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = cpuInfo[offset + Int(CPU_STATE_USER)]
            let system = cpuInfo[offset + Int(CPU_STATE_SYSTEM)]
            let idle = cpuInfo[offset + Int(CPU_STATE_IDLE)]
            let nice = cpuInfo[offset + Int(CPU_STATE_NICE)]

            let used = user + system + nice
            let total = used + idle
            totalLoad += used
            totalTicks += total
        }

        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)

        guard totalTicks > 0 else { return 0 }
        return Int((Double(totalLoad) / Double(totalTicks)) * 100)
    }

    private static func memoryUsage() -> (used: String, total: String) {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let totalGB = Double(totalBytes) / 1_073_741_824

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (String(format: "%.1f", 0), String(format: "%.0f", totalGB))
        }

        let pageSize = vm_kernel_page_size
        let activeBytes = UInt64(stats.active_count) * UInt64(pageSize)
        let wiredBytes = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressedBytes = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let usedBytes = activeBytes + wiredBytes + compressedBytes
        let usedGB = Double(usedBytes) / 1_073_741_824

        return (String(format: "%.1f", usedGB), String(format: "%.0f", totalGB))
    }

    private static func batteryLevel() -> Int? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
              let capacity = info[kIOPSCurrentCapacityKey] as? Int else {
            return nil
        }
        return capacity
    }
}
