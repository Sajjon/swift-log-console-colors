import Foundation
import Logging


public enum LogIconType {
    /** Displays cool icons like bug, lightning bolt, and fire. */
    case cool
    
    /** Displays more colors based on rainbow */
    case rainbow
    
    func toIcon(logLevel: Logger.Level) -> String {
        switch self {
        case .cool:
            switch logLevel {
            case .trace:
                return "📣"
            case .debug:
                return "🐛"
            case .info:
                return "ℹ️"
            case .notice:
                return "📖"
            case .warning:
                return "⚠️"
            case .error:
                return "⚡"
            case .critical:
                return "🔥"
            }
            
        case .rainbow:
            switch logLevel {
            case .trace:
                return "⬜️"
            case .debug:
                return "🟪"
            case .info:
                return "🟦"
            case .notice:
                return "🟩"
            case .warning:
                return "🟨"
            case .error:
                return "🟧"
            case .critical:
                return "🟥"
            }
        }
    }
}


/// `ColorStreamLogHandler` is a simple implementation of `LogHandler` for directing
/// `Logger` output to either `stderr` or `stdout` via the factory methods.
public struct ColorStreamLogHandler: LogHandler {
   
    /// Factory that makes a `ColorStreamLogHandler` to directs its output to `stdout`
    public static func standardOutput(
        label: String,
        logIconType: LogIconType = .cool,
        timeformat: String = Self.timeformatDefault
    ) -> ColorStreamLogHandler {
        return ColorStreamLogHandler(
            label: label,
            stream: CustomStdioOutputStream.stdout,
            logIconType: logIconType,
            timeformat: timeformat
        )
    }

    /// Factory that makes a `ColorStreamLogHandler` to directs its output to `stderr`
    public static func standardError(
        label: String,
        logIconType: LogIconType = .cool,
        timeformat: String = Self.timeformatDefault
    ) -> ColorStreamLogHandler {
        return ColorStreamLogHandler(
            label: label,
            stream: CustomStdioOutputStream.stderr,
            logIconType: logIconType,
            timeformat: timeformat
        )
    }

    private let stream: TextOutputStream
    private let label: String
    public static let timeformatDefault = "%Y-%m-%dT%H:%M:%S%z"
    private let timeformat: String
    private let logIconType:LogIconType

    public var logLevel: Logger.Level = .info

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    // internal for testing only
    internal init(
        label: String,
        stream: TextOutputStream,
        logIconType: LogIconType,
        timeformat: String = Self.timeformatDefault
    ) {
        self.label = label
        self.stream = stream
        self.logIconType = logIconType
        self.timeformat = timeformat
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source _: String, // unused
        file: String,
        function: String,
        line: UInt
    ) {
        let entry = logEntry(
            level: level,
            message: message,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        
        var stream = self.stream
        stream.write(entry + "\n")
    }
    
    internal func logEntry(
        level: Logger.Level? = nil,
        message: Logger.Message,
        metadata: Logger.Metadata? = nil,
        hardcodedTime: UnsafePointer<tm>? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> String {
        let level = level ?? self.logLevel
        let prettyMetadata = metadata?.isEmpty ?? true
        ? self.prettyMetadata
        : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))
        
        
        let icon = logIconType.toIcon(logLevel: level)

        return "\(self.timestamp(from: hardcodedTime)) \(icon) \(level) \(self.label) :\(prettyMetadata.map { " \($0)" } ?? "") \(message)"
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty
            ? metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: " ")
            : nil
    }

    private func timestamp(from hardcodedTime: UnsafePointer<tm>? = nil) -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        let time_ = hardcodedTime ?? {
            var timestamp = time(nil)
            let localTime = localtime(&timestamp)
            return UnsafePointer(localTime)
        }()
        strftime(&buffer, buffer.count, timeformat, time_)
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
    
}

/// A wrapper to facilitate `print`-ing to stderr and stdio that
/// ensures access to the underlying `FILE` is locked to prevent
/// cross-thread interleaving of output.
internal struct CustomStdioOutputStream: TextOutputStream {
    #if canImport(WASILibc)
    internal let file: OpaquePointer
    #else
    internal let file: UnsafeMutablePointer<FILE>
    #endif
    internal let flushMode: FlushMode

    internal func write(_ string: String) {
        string.withCString { ptr in
            #if os(Windows)
            _lock_file(self.file)
            #elseif canImport(WASILibc)
            // no file locking on WASI
            #else
            flockfile(self.file)
            #endif
            defer {
                #if os(Windows)
                _unlock_file(self.file)
                #elseif canImport(WASILibc)
                // no file locking on WASI
                #else
                funlockfile(self.file)
                #endif
            }
            _ = fputs(ptr, self.file)
            if case .always = self.flushMode {
                self.flush()
            }
        }
    }

    /// Flush the underlying stream.
    /// This has no effect when using the `.always` flush mode, which is the default
    internal func flush() {
        _ = fflush(self.file)
    }

    internal static let stderr = CustomStdioOutputStream(file: systemStderr, flushMode: .always)
    internal static let stdout = CustomStdioOutputStream(file: systemStdout, flushMode: .always)

    /// Defines the flushing strategy for the underlying stream.
    internal enum FlushMode {
        case undefined
        case always
    }
}


// Prevent name clashes
#if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
let systemStderr = Darwin.stderr
let systemStdout = Darwin.stdout
#elseif os(Windows)
let systemStderr = CRT.stderr
let systemStdout = CRT.stdout
#elseif canImport(Glibc)
let systemStderr = Glibc.stderr!
let systemStdout = Glibc.stdout!
#elseif canImport(WASILibc)
let systemStderr = WASILibc.stderr!
let systemStdout = WASILibc.stdout!
#else
#error("Unsupported runtime")
#endif
