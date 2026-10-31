import Foundation
import Testing
@testable import KitchenCatalog

/// The same cases as js/test.mjs, from Tests/season-cases.json, so Swift and JS agree on seasons.
struct SeasonTests {
    private struct Cases: Decodable {
        let fixture: [Season]
        let on: [[Value]]
        let ends: [[String]]
        let mentions: [[Value]]
        let star: [[Value]]
        let covers: [[Value]]
        let matches: [[Value]]
    }

    /// The JSON mixes strings, lists of strings and booleans in one row.
    private enum Value: Decodable {
        case text(String), list([String]), flag(Bool), missing
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() { self = .missing }
            else if let b = try? c.decode(Bool.self) { self = .flag(b) }
            else if let s = try? c.decode(String.self) { self = .text(s) }
            else { self = .list(try c.decode([String].self)) }
        }
        var text: String { if case .text(let s) = self { s } else { "" } }
        var optionalText: String? { if case .text(let s) = self { s } else { nil } }
        var list: [String] { if case .list(let l) = self { l } else { [] } }
        var flag: Bool { if case .flag(let b) = self { b } else { false } }
    }

    private let cases: Cases = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "season-cases.json")
        return try! JSONDecoder().decode(Cases.self, from: Data(contentsOf: url))
    }()

    private func fixture(_ id: String) -> Season { cases.fixture.first { $0.id == id }! }

    @Test func daysInSeason() {
        for row in cases.on {
            let got = cases.fixture.filter { $0.contains(day: row[0].text) }.map(\.id)
            #expect(got == row[1].list, "\(row[0].text)")
        }
    }

    @Test func seasonEnds() {
        for row in cases.ends {
            #expect(fixture(row[0]).endDay(after: row[1]) == row[2], "\(row[0]) \(row[1])")
        }
    }

    @Test func namesMentionTheItem() {
        for row in cases.mentions {
            #expect(fixture(row[0].text).mentions(row[1].text) == row[2].flag, "\(row[0].text): \(row[1].text)")
        }
    }

    @Test func starKind() {
        for row in cases.star {
            #expect(fixture(row[0].text).isStar(row[1].text) == row[2].flag, "\(row[0].text): \(row[1].text)")
        }
    }

    @Test func coversCatalogItems() {
        for row in cases.covers {
            #expect(fixture(row[0].text).covers(itemID: row[1].text) == row[2].flag, "\(row[0].text): \(row[1].text)")
        }
    }

    @Test func linesMatchBySeasonAndCatalog() {
        for row in cases.matches {
            #expect(fixture(row[0].text).matches(itemID: row[1].optionalText, name: row[2].text) == row[3].flag, "\(row[0].text): \(row[2].text)")
        }
    }

    @Test func dateInSeason() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let halloween = cal.date(from: DateComponents(year: 2026, month: 10, day: 31))!
        let wraps = fixture("wraps")
        #expect(wraps.contains(halloween, calendar: cal))
        #expect(wraps.endDate(after: halloween, calendar: cal) == cal.date(from: DateComponents(year: 2027, month: 1, day: 15)))
    }

    /// The shipped calendar: unique ids, catalog items that exist, real dates.
    @Test func shippedCalendar() {
        #expect(!Seasons.all.isEmpty)
        #expect(Set(Seasons.all.map(\.id)).count == Seasons.all.count)
        for s in Seasons.all {
            for item in s.items { #expect(Catalog.shared.items[item] != nil, "\(s.id) lists \(item)") }
            #expect(s.contains(day: s.from) && s.contains(day: s.to), "\(s.id)")
        }
        #expect(Seasons.season("persimmons")?.star?.label == "Fuyu")
    }
}
