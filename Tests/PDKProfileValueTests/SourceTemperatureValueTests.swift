import Foundation
import PDKCore
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SourceTemperatureValueTests {
    @Test func circuitNominalTemperatureRemainsDistinctAcrossCodec() throws {
        let reference = try ProfileValueTests().reference()
        let source = try PDKSourceTemperatureFact(kind: "circuitNominalTemperature", temperatureCelsius: 30,
            sourceReference: reference, evidenceIdentity: "actual.circuit.tnom")
        let decoded = try JSONDecoder().decode(PDKSourceTemperatureFact.self, from: JSONEncoder().encode(source))
        #expect(decoded == source)
        #expect(decoded.kind != "operatingTemperature")
        #expect(decoded.kind != "modelNominalTemperature")
        #expect(throws: PDKProfileValueError.self) {
            try PDKSourceTemperatureFact(kind: "unknownTemperature", temperatureCelsius: 30,
                sourceReference: reference, evidenceIdentity: "actual.unknown")
        }
    }
}
