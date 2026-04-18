//
//  AppLogger.swift
//  Life@USTC
//
//  Unified logging system with in-memory ring buffer for debug viewer
//  and os.log forwarding for Console.app / device diagnostics.
//

import Foundation
import os.log

// MARK: - Log Entry

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String

    enum LogLevel: String, Sendable {
        case debug, info, warning, error
    }
}

// MARK: - AppLogger

/// Centralized logger that buffers entries in-memory (for the debug viewer)
/// and forwards to os.log (for Console.app / device diagnostics).
///
/// Thread-safe via `OSAllocatedUnfairLock`. Logging never blocks the caller.
final class AppLogger: Sendable {

    static let shared = AppLogger()

    /// Maximum number of entries kept in the ring buffer.
    private static let bufferCapacity = 1000

    private let _entries = OSAllocatedUnfairLock(initialState: [LogEntry]())

    /// Internal os.log loggers keyed by category, guarded by a lock.
    private let _loggers = OSAllocatedUnfairLock(initialState: [String: Logger]())

    private init() {}

    // MARK: - Public API

    /// Current snapshot of buffered log entries (newest first).
    var entries: [LogEntry] {
        _entries.withLock { Array($0.reversed()) }
    }

    /// Number of buffered entries.
    var count: Int {
        _entries.withLock { $0.count }
    }

    /// Clear all buffered entries.
    func clear() {
        _entries.withLock { $0.removeAll() }
    }

    // MARK: - Logging Methods

    func debug(_ message: String, category: String) {
        log(level: .debug, message: message, category: category)
    }

    func info(_ message: String, category: String) {
        log(level: .info, message: message, category: category)
    }

    func warning(_ message: String, category: String) {
        log(level: .warning, message: message, category: category)
    }

    func error(_ message: String, category: String) {
        log(level: .error, message: message, category: category)
    }

    // MARK: - Convenience factory

    /// Returns a category-bound logger for use as a drop-in replacement.
    /// Usage: `private let log = AppLogger.logger(for: "ServerClient")`
    static func logger(for category: String) -> CategoryLogger {
        CategoryLogger(category: category, appLogger: shared)
    }

    // MARK: - Internal

    private func log(level: LogEntry.LogLevel, message: String, category: String) {
        let entry = LogEntry(timestamp: Date(), level: level, category: category, message: message)

        // Buffer the entry
        _entries.withLock { entries in
            entries.append(entry)
            if entries.count > Self.bufferCapacity {
                entries.removeFirst(entries.count - Self.bufferCapacity)
            }
        }

        // Forward to os.log
        let osLogger = osLogger(for: category)
        switch level {
        case .debug:
            osLogger.debug("\(message, privacy: .public)")
        case .info:
            osLogger.info("\(message, privacy: .public)")
        case .warning:
            osLogger.warning("\(message, privacy: .public)")
        case .error:
            osLogger.error("\(message, privacy: .public)")
        }
    }

    private func osLogger(for category: String) -> Logger {
        _loggers.withLock { loggers in
            if let existing = loggers[category] { return existing }
            let new = Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "dev.tiankaima.Life-USTC",
                category: category
            )
            loggers[category] = new
            return new
        }
    }
}

// MARK: - CategoryLogger

/// Lightweight category-bound wrapper so each module can use `log.info("...")`
/// syntax without passing the category string every time.
struct CategoryLogger: Sendable {
    let category: String
    let appLogger: AppLogger

    func debug(_ message: String) { appLogger.debug(message, category: category) }
    func info(_ message: String) { appLogger.info(message, category: category) }
    func warning(_ message: String) { appLogger.warning(message, category: category) }
    func error(_ message: String) { appLogger.error(message, category: category) }
}
