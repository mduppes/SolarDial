import Foundation

public struct Coordinates: Codable, Equatable, Hashable, Sendable {
    /// Degrees, positive north.
    public var latitude: Double
    /// Degrees, positive east.
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}
