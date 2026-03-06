import Foundation
import os

/// Centralized diagnostic logging using os.Logger.
/// Logs are visible in Console.app — filter by subsystem "dev.getGOAT.app".
/// Enable verbose logging via UserDefaults key "diagnosticLogging".
final class DiagnosticLogger {
    static let shared = DiagnosticLogger()

    // MARK: - Category Loggers

    let terminal = Logger(subsystem: "dev.getGOAT.app", category: "terminal")
    let backlog = Logger(subsystem: "dev.getGOAT.app", category: "backlog")
    let observation = Logger(subsystem: "dev.getGOAT.app", category: "observation")
    let fileIO = Logger(subsystem: "dev.getGOAT.app", category: "fileIO")

    // MARK: - Counters (for detecting runaway loops)

    private let lock = NSLock()
    private var counters: [String: (count: Int, windowStart: Date)] = [:]

    /// Whether verbose (debug-level) logging is enabled.
    /// Toggle at runtime: `defaults write dev.getGOAT.app diagnosticLogging -bool YES`
    var isVerbose: Bool {
        UserDefaults.standard.bool(forKey: "diagnosticLogging")
    }

    private init() {}

    // MARK: - Rate Detection

    /// Increments a named counter and logs a warning if the rate exceeds
    /// `threshold` events within `windowSeconds`. Returns the current count.
    @discardableResult
    func trackRate(_ name: String, threshold: Int = 20, windowSeconds: TimeInterval = 5, logger: Logger) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        var entry = counters[name] ?? (count: 0, windowStart: now)

        if now.timeIntervalSince(entry.windowStart) > windowSeconds {
            entry = (count: 0, windowStart: now)
        }

        entry.count += 1
        counters[name] = entry

        if entry.count == threshold {
            logger.warning("High rate detected: \(name, privacy: .public) fired \(entry.count) times in \(windowSeconds)s — possible runaway loop")
        }

        return entry.count
    }

    // MARK: - Memory Snapshot

    /// Logs current process memory usage.
    func logMemoryUsage(context: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let mb = Double(info.resident_size) / (1024 * 1024)
            if mb > 500 {
                observation.critical("Memory: \(String(format: "%.1f", mb), privacy: .public) MB — \(context, privacy: .public)")
            } else if mb > 200 {
                observation.warning("Memory: \(String(format: "%.1f", mb), privacy: .public) MB — \(context, privacy: .public)")
            } else if isVerbose {
                observation.debug("Memory: \(String(format: "%.1f", mb), privacy: .public) MB — \(context, privacy: .public)")
            }
        }
    }
}
