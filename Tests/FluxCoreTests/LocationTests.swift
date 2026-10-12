import CoreGraphics
import Foundation
import Testing
@testable import FluxCore

struct ZoneTabTests {
    let sample = """
        # tz zone descriptions
        BR\t-2332-04637\tAmerica/Sao_Paulo\tBrazil (southeast)
        GB\t+513030-0000731\tEurope/London
        HR\t+4548+01558\tEurope/Zagreb
        bogus line
        """

    @Test func parsesMinuteAndSecondPrecision() throws {
        let tab = ZoneTab(contents: sample)
        let sp = try #require(tab.coordinates(for: "America/Sao_Paulo"))
        #expect(abs(sp.latitude - (-23.5333)) < 0.001)
        #expect(abs(sp.longitude - (-46.6167)) < 0.001)
        let london = try #require(tab.coordinates(for: "Europe/London"))
        #expect(abs(london.latitude - 51.5083) < 0.001)
        #expect(abs(london.longitude - (-0.1253)) < 0.001)
        #expect(tab.coordinatesByZone.count == 3)
    }

    @Test func rejectsMalformedCoordinates() {
        #expect(ZoneTab.parseISO6709("2332-04637") == nil)
        #expect(ZoneTab.parseISO6709("-2332-046") == nil)
        #expect(ZoneTab.parseISO6709("-23a2-04637") == nil)
    }

    @Test func systemFileCoversCurrentZoneWhenPresent() throws {
        guard let contents = try? String(contentsOfFile: ZoneTab.systemPath, encoding: .utf8) else { return }
        let tab = ZoneTab(contents: contents)
        #expect(tab.coordinatesByZone.count > 300)
        #expect(tab.coordinates(for: "America/Sao_Paulo") != nil)
    }
}

struct LocationResolverTests {
    let tab = ZoneTab(contents: "BR\t-2332-04637\tAmerica/Sao_Paulo\n")
    let saoPauloTZ = TimeZone(identifier: "America/Sao_Paulo")!
    let dubrovnik = Coordinates(latitude: 42.6, longitude: 18.1)

    @Test func manualWins() {
        let result = LocationResolver.resolve(
            manual: dubrovnik, lastFix: nil, timeZone: saoPauloTZ, zoneTab: tab)
        #expect(result.source == .manual)
        #expect(result.coordinates == dubrovnik)
    }

    @Test func fixFromAnotherTimeZoneIsIgnored() {
        let stale = LocationFix(coordinates: dubrovnik, timeZoneIdentifier: "Europe/Zagreb")
        let result = LocationResolver.resolve(manual: nil, lastFix: stale, timeZone: saoPauloTZ, zoneTab: tab)
        #expect(result.source == .timeZone("America/Sao_Paulo"))
    }

    @Test func fixFromCurrentTimeZoneIsUsed() {
        let here = Coordinates(latitude: -23.6, longitude: -46.7)
        let fix = LocationFix(coordinates: here, timeZoneIdentifier: "America/Sao_Paulo")
        let result = LocationResolver.resolve(manual: nil, lastFix: fix, timeZone: saoPauloTZ, zoneTab: tab)
        #expect(result.source == .coreLocation)
        #expect(result.coordinates == here)
    }

    @Test func unknownZoneEstimatesLongitudeFromOffset() {
        let tz = TimeZone(secondsFromGMT: -3 * 3600)!
        let result = LocationResolver.resolve(manual: nil, lastFix: nil, timeZone: tz, zoneTab: tab)
        #expect(result.source == .unknown)
        #expect(result.coordinates.longitude == -45)
    }
}

struct SettingsTests {
    @Test func decodesPartialJSONWithDefaults() throws {
        let json = #"{"sunsetKelvin": 3000, "disabledBundleIDs": ["com.apple.FinalCut"]}"#
        let settings = try JSONDecoder().decode(UserSettings.self, from: Data(json.utf8))
        #expect(settings.sunsetKelvin == 3000)
        #expect(settings.dayKelvin == 6500)
        #expect(settings.disabledBundleIDs == ["com.apple.FinalCut"])
    }

    @Test func roundTrips() throws {
        var settings = UserSettings()
        settings.manualCoordinates = Coordinates(latitude: 1, longitude: 2)
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(UserSettings.self, from: data) == settings)
    }
}

struct FullscreenGeometryTests {
    let display = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let second = CGRect(x: 1512, y: -200, width: 2560, height: 1440)

    @Test func exactFillCounts() {
        #expect(FullscreenGeometry.window(display, covers: display))
        #expect(FullscreenGeometry.window(second, covers: second))
    }

    @Test func belowNotchCountsOnlyWithInset() {
        let belowNotch = CGRect(x: 0, y: 32, width: 1512, height: 950)
        #expect(!FullscreenGeometry.window(belowNotch, covers: display))
        #expect(FullscreenGeometry.window(belowNotch, covers: display, topInset: 32))
    }

    @Test func zoomedWindowUnderMenuBarDoesNotCount() {
        let zoomed = CGRect(x: 0, y: 25, width: 1512, height: 957)
        #expect(!FullscreenGeometry.window(zoomed, covers: display))
    }

    @Test func windowOnOtherDisplayDoesNotCount() {
        #expect(!FullscreenGeometry.window(second, covers: display))
    }
}
