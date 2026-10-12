import Foundation

/// Parser for the IANA `zone.tab` file (shipped by macOS at `/usr/share/zoneinfo/zone.tab`),
/// which gives a representative coordinate for every time-zone identifier.
public struct ZoneTab: Sendable {
    public static let systemPath = "/usr/share/zoneinfo/zone.tab"

    public let coordinatesByZone: [String: Coordinates]

    public init(contents: String) {
        var result: [String: Coordinates] = [:]
        for line in contents.split(whereSeparator: \.isNewline) {
            guard !line.hasPrefix("#") else { continue }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 3, let coordinates = ZoneTab.parseISO6709(String(fields[1])) else { continue }
            result[String(fields[2])] = coordinates
        }
        coordinatesByZone = result
    }

    public func coordinates(for identifier: String) -> Coordinates? {
        coordinatesByZone[identifier]
    }

    /// Parses `±DDMM±DDDMM` or `±DDMMSS±DDDMMSS`.
    public static func parseISO6709(_ text: String) -> Coordinates? {
        let chars = Array(text)
        guard chars.count >= 11, chars[0] == "+" || chars[0] == "-",
              let split = chars.indices.dropFirst().first(where: { chars[$0] == "+" || chars[$0] == "-" })
        else { return nil }
        guard let latitude = angle(chars[0..<split], degreeDigits: 2),
              let longitude = angle(chars[split...], degreeDigits: 3)
        else { return nil }
        return Coordinates(latitude: latitude, longitude: longitude)
    }

    private static func angle(_ chars: ArraySlice<Character>, degreeDigits: Int) -> Double? {
        guard let sign = chars.first else { return nil }
        let digits = chars.dropFirst()
        guard digits.allSatisfy(\.isNumber),
              digits.count == degreeDigits + 2 || digits.count == degreeDigits + 4
        else { return nil }
        let string = String(digits)
        func part(_ offset: Int, _ length: Int) -> Double {
            let start = string.index(string.startIndex, offsetBy: offset)
            return Double(string[start..<string.index(start, offsetBy: length)]) ?? 0
        }
        var value = part(0, degreeDigits) + part(degreeDigits, 2) / 60
        if digits.count == degreeDigits + 4 { value += part(degreeDigits + 2, 2) / 3600 }
        return sign == "-" ? -value : value
    }
}
