//
//  PlayersTests.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

@testable import ShitheadenRuntime
import XCTest

class PlayersTests: XCTestCase {
  func testSortPlayerLowestCard() {
    var player1 = Player(id: UUID(), name: "1", position: .noord, ai: RandomBot())
    var player2 = Player(id: UUID(), name: "2", position: .zuid, ai: RandomBot())
    var player3 = Player(id: UUID(), name: "3", position: .oost, ai: RandomBot())

    player1.handCards = [
      .init(id: .init(), symbol: .harten, number: .five),
      .init(id: .init(), symbol: .harten, number: .six),
      .init(id: .init(), symbol: .harten, number: .five),
    ]

    player2.handCards = [
      .init(id: .init(), symbol: .harten, number: .four),
      .init(id: .init(), symbol: .harten, number: .four),
      .init(id: .init(), symbol: .harten, number: .five),
    ]

    player3.handCards = [
      .init(id: .init(), symbol: .harten, number: .four),
      .init(id: .init(), symbol: .harten, number: .six),
      .init(id: .init(), symbol: .harten, number: .five),
    ]

    var players = [
      player1,
      player2,
      player3,
    ]

    players.sortPlayerLowestCard()

    XCTAssertEqual(players.first?.id, player2.id)
    XCTAssertEqual(players.dropFirst().first?.id, player3.id)
    XCTAssertEqual(players.dropFirst().dropFirst().first?.id, player1.id)
  }
}
