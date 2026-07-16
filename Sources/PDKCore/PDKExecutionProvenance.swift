import CircuiteFoundation
import Foundation

public enum PDKExecutionProvenance {
    public static func make(
        engineID: String,
        implementationID: String,
        implementationVersion: String,
        inputs: [ArtifactReference] = [],
        startedAt: Date,
        completedAt: Date
    ) throws -> ExecutionProvenance {
        try ExecutionProvenance(
            producer: ProducerIdentity(
                kind: .engine,
                identifier: engineID,
                version: implementationVersion,
                build: implementationID
            ),
            inputs: inputs,
            invocation: ExecutionInvocation.inProcess(
                entryPoint: "\(implementationID).execute"
            ),
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
}
