@testable import ShitheadenShared
import XCTest

class IncludeDoublesTests: XCTestCase {
  func testIncludeDoubles() {
    let id1 = UUID()
    let id2 = UUID()
    let turns = [Turn.play([
      Card(id: id1, symbol: .harten, number: .bronze),
      Card(id: id2, symbol: .klaver, number: .bronze),
    ])]
    let doubles = turns.includeDoubles()
    XCTAssertEqual(doubles, [
      .play(Set([
        Card(id: id1, symbol: .harten, number: .bronze),
        Card(id: id2, symbol: .klaver, number: .bronze),
      ])),
      .play(Set([
        Card(id: id1, symbol: .harten, number: .bronze),
        Card(id: id2, symbol: .klaver, number: .bronze),
      ])),
      .play(Set([
        Card(id: id2, symbol: .klaver, number: .bronze),
        Card(id: id1, symbol: .harten, number: .bronze),
      ])),
      .play(Set([
        Card(id: id2, symbol: .klaver, number: .bronze),
        Card(id: id1, symbol: .harten, number: .bronze),
      ])),
    ])
  }
}
