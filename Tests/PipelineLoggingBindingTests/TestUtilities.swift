import LoggingInterfaces
import Pipeline
import PipelineLoggingBinding
import Foundation

// ************************************
// Taken from "BasicLogging":
// ************************************

/// A concurrent wraper around some logging action.
/// The logging is done asynchronously, so the close() method
/// is to be called at the end of a process in order to be sure
/// that all logging is done.
///
/// In the case of a crash some logging might get lost, so the
/// use of an additional `ConcurrentCrashLogger` is sensible.
open class ConcurrentLogger<Message: Sendable & CustomStringConvertible,Mode: Sendable>: Logger, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = Mode
    
    internal let queue: DispatchQueue
    
    public var loggingAction: (@Sendable (Message,Mode?) -> ())? = nil
    public var closeAction: (@Sendable () -> ())? = nil
    
    public init(
        loggingAction: (@Sendable (Message,Mode?) -> ())? = nil,
        closeAction: (@Sendable () -> ())? = nil,
        qualityOfService: DispatchQoS = .userInitiated
    ) {
        self.loggingAction = loggingAction
        self.closeAction = closeAction
        queue = DispatchQueue(label: "ConcurrentLogger", qos: qualityOfService)
    }
    
    private var closed = false
    
    open func log(_ message: Message, withMode mode: Mode? = nil) {
        self.queue.async {
            if !self.closed {
                self.loggingAction?(message, mode)
            }
        }
    }
    
    open func close() throws {
        self.queue.sync {
            if !self.closed {
                self.closeAction?()
                self.loggingAction = nil
                self.closeAction = nil
                self.closed = true
            }
        }
    }
    
}

/// A logger just collecting all logging messages.
public class CollectingLogger<Message: Sendable & CustomStringConvertible,Mode: Sendable>: ConcurrentLogger<Message,Mode>, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = Mode
    
    private var messages = [Message]()
    
    public init(errorsToStandard: Bool = false) {
        super.init()
        loggingAction = { message,printMode in
            self.messages.append(message)
        }
    }
    
    /// Get all collected message events.
    public func getMessages() -> [Message] {
        var messages: [Message]? = nil
        self.queue.sync {
            messages = self.messages
        }
        return messages!
    }
}

func printToErrorOut(_ message: CustomStringConvertible) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}

/// A logger that just prints to the standard output.
public final class PrintLogger<Message: Sendable & CustomStringConvertible,Mode>: ConcurrentLogger<Message,PrintMode>, @unchecked Sendable {
    
    public typealias Message = Message
    public typealias Mode = PrintMode
    
    let errorsToStandard: Bool
    
    public init(errorsToStandard: Bool = false) {
        self.errorsToStandard = errorsToStandard
        super.init()
        loggingAction = { message,printMode in
            if errorsToStandard {
                print(message.description)
            } else {
                switch printMode {
                case .standard, nil:
                    print(message.description)
                case .error:
                    printToErrorOut(message.description)
                }
            }
        }
    }
    
}

// ************************************
// Taken from "PipelineBasicLogging":
// ************************************

/// A logger that just prints to the standard output.
public final class LogEntryPrinter: Logger, @unchecked Sendable {
    
    public typealias Message = ExecutionLogEntry
    public typealias Mode = InfoType
    
    private let printLogger: PrintLogger<ExecutionLogEntry,PrintMode>
    
    public init(errorsToStandard: Bool = false) {
        printLogger = PrintLogger(errorsToStandard: errorsToStandard)
    }
    
    public func log(_ message: ExecutionLogEntry, withMode mode: InfoType? = nil) {
        if let mode, mode >= .error {
            printLogger.log(message, withMode: .error)
        } else {
            printLogger.log(message, withMode: .standard)
        }
        
    }
    
    public func close() throws {
        try printLogger.close()
    }
    
}
