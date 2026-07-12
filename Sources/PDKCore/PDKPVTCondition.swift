import Foundation

public struct PDKPVTCondition: Sendable, Hashable, Codable {
    public var process: PDKProcessCorner
    public var voltage: Double
    public var temperatureCelsius: Double

    public init(
        process: PDKProcessCorner,
        voltage: Double,
        temperatureCelsius: Double
    ) {
        self.process = process
        self.voltage = voltage
        self.temperatureCelsius = temperatureCelsius
    }
}
