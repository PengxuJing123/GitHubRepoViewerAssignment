//
//  Logger.swift
//  GitHubRepoViewer
//
//  Created by Holdenjing on 2026/4/18.
//

import Foundation
import os.log

public enum LogLevel: Int {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
}

public struct Logger {
    // Log level control (Debug mode: displays all, Release mode: shows only warnings and errors)
    private static let minLogLevel: LogLevel = {
#if DEBUG
        // .verbose（Record all logs）
        return .verbose
#else
        // .warning（Filter out redundant information）
        return .warning
#endif
    }()
    
    // Get concise file name (remove path)
    // Full file path → Short file name
    // Purpose：Keep logs concise and readable
    private static func simpleFileName(_ file: String) -> String {
        return URL(fileURLWithPath: file).lastPathComponent
    }
    
    // Core logging method
    private static func log(
        _ message: String,
        level: LogLevel = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Log level filtering
        // Only print logs that are not lower than the minimum level of the current mode, for example, ignore verbose/debug/info levels in Release mode
        guard level.rawValue >= minLogLevel.rawValue else { return }
        
        // Format logs using a more efficient FormatStyle
        // Calling this function: .formatted() provides a reasonable default value, which uses your device's current locale and calendar to display the value.
        let timestamp = Date().formatted()
        let fileName = simpleFileName(file)
        let logPrefix: String
        
        switch level {
        case .verbose:
            logPrefix = "[VERBOSE]"
        case .debug:
            logPrefix = "[DEBUG]"
        case .info:
            logPrefix = "[INFO]"
        case .warning:
            logPrefix = "[WARNING]"
        case .error:
            logPrefix = "[ERROR]"
        }
        
        // Build complete log information
        let fullMessage = "\(logPrefix) \(timestamp) \(fileName):\(line) - \(function)\n   → \(message)"
        
        // Different output methods
#if DEBUG
        os_log("%{public}@", type: .debug, fullMessage)
#else
        // Release mode uses system logging (performance optimization)
        // Advantages: automatically hides sensitive data, supports Instruments/Logging tools, supports multiple levels
        // Automatic hiding examples: %{private}@ by default only shows <private> (visible when developer device is unlocked), %{sensitive}@ by default only shows <redacted> (visible with special certificates)
        // Users can only see content printed with %{public}@
        // File name and line number are not sensitive information
        // The Logger API was not used because it is only supported on iOS 14 and above systems.
        os_log("%{public}@", type: .default, fullMessage)
#endif
    }
    
    // Public logging method, these parameters do not need to be passed in when calling, the compiler will automatically obtain them：
    // #file, #function, #line are Swift compiler directives that automatically get the current code location
    // #file：The full path of the current source file
    // #function：The name of the current method
    // #line：The current line number
    public static func verbose(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line) {
            log(message, level: .verbose, file: file, function: function, line: line)
        }
    
    public static func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
            log(message, level: .debug, file: file, function: function, line: line)
        }
    
    public static func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
            log(message, level: .info, file: file, function: function, line: line)
        }
    
    public static func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
            log(message, level: .warning, file: file, function: function, line: line)
        }
    
    public static func error(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
            log(message, level: .error, file: file, function: function, line: line)
        }
}

