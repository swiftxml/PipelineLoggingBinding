import Pipeline
import LoggingInterfaces

public protocol SeverityTracker: Sendable {
    func process(_ newSeverity: InfoType)
    func wait()
    var value: InfoType { get }
}

public struct ExecutionLogEntry: Sendable, CustomStringConvertible {
    
    let executionEvent: ExecutionEvent
    let metadataInfo: String
    let excutionInfoFormat: ExecutionInfoFormat?
    
    public var description: String {
        if let excutionInfoFormat {
            executionEvent.description(format: excutionInfoFormat, withMetaDataInfo: metadataInfo)
        } else {
            executionEvent.description(withMetaDataInfo: metadataInfo)
        }
    }
}

public struct EventProcessorForLogger: ExecutionEventProcessor {
    
    public let metadataInfo: String
    public let metadataInfoForUserInteraction: String
    
    private let logger: any Logger<ExecutionLogEntry,InfoType>
    private let severityTracker: SeverityTracker?
    private let minimalInfoType: InfoType?
    private let excutionInfoFormat: ExecutionInfoFormat?
    
    /// The the severity i.e. the worst message type.
    var severity: InfoType? { severityTracker?.value }
    
    /// This closes all loggers.
    public func closeEventProcessing() throws {
        try logger.close()
    }
    
    public init(
        withMetaDataInfo metadataInfo: String,
        withMetaDataInfoForUserInteraction metadataInfoForUserInteraction: String? = nil,
        logger: any Logger<ExecutionLogEntry,InfoType>,
        severityTracker: SeverityTracker? = nil,
        withMinimalInfoType minimalInfoType: InfoType? = nil,
        excutionInfoFormat: ExecutionInfoFormat? = nil
    ) {
        self.metadataInfo = metadataInfo
        self.metadataInfoForUserInteraction = metadataInfoForUserInteraction ?? metadataInfo
        self.logger = logger
        self.severityTracker = severityTracker
        self.minimalInfoType = minimalInfoType
        self.excutionInfoFormat = excutionInfoFormat
    }
    
    public func process(_ executionEvent: ExecutionEvent) {
        severityTracker?.process(executionEvent.type)
        if let minimalInfoType, executionEvent.type < minimalInfoType {
            return
        }
        logger.log(ExecutionLogEntry(executionEvent: executionEvent, metadataInfo: metadataInfo, excutionInfoFormat: excutionInfoFormat), withMode: executionEvent.type)
    }
    
}
