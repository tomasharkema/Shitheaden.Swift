//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import CustomAlgo
import Foundation
@testable import ShitheadenRuntime
import TestsHelpers
import XCTest

class GameTests: XCTestCase {
  func testNormalRunFourPlayers() {
    let game = Game(players: [
      Player(
        name: "West (Unfair)",
        position: .west,
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgoWithUnfairPassing()
      ),
      Player(
        name: "Oost",
        position: .oost,
        ai: CardRankingAlgo()
      ),
      Player(
        name: "Zuid",
        position: .zuid,
        ai: CardRankingAlgo()
      ),
    ], slowMode: false)

    asyncTest(timeout: 20) {
      let snapshot = try await game.startGame()
      XCTAssertNotNil(snapshot.snapshot.winner)
    }
  }

  func testNormalRunTwoPlayers() {
    let game = Game(players: [
      Player(
        name: "West (Unfair)",
        position: .west,
        ai: CardRankingAlgoWithUnfairPassing()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgo()
      ),
    ], slowMode: false)

    asyncTest(timeout: 20) {
      let snapshot = try await game.startGame()
      XCTAssertNotNil(snapshot.snapshot.winner)
    }
  }

  func testDeadlockPrevention() {
    var deck = Deck.new

    var firstPlayer = Player(
      name: "first",
      position: .noord,
      ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
    )
    var secondPlayer = Player(
      name: "second",
      position: .zuid,
      ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
    )

    firstPlayer.handCards = [
      .init(id: UUID(), symbol: .harten, number: .seven),
      .init(id: UUID(), symbol: .ruiten, number: .aas),
      .init(id: UUID(), symbol: .harten, number: .aas),
    ]
    secondPlayer.handCards = [
      .init(id: UUID(), symbol: .schoppen, number: .six),
      .init(id: UUID(), symbol: .klaver, number: .aas),
      .init(id: UUID(), symbol: .schoppen, number: .aas),
    ]

    deck = Deck(cards: deck.cards.filter { card in
      if firstPlayer.handCards
        .contains(where: { $0.number == card.number && $0.symbol == card.symbol })
      {
        return false
      }
      if secondPlayer.handCards
        .contains(where: { $0.number == card.number && $0.symbol == card.symbol })
      {
        return false
      }
      return true
    })

    firstPlayer.closedTableCards = [
      deck.draw()!,
      deck.draw()!,
      deck.draw()!,
    ]

    secondPlayer.closedTableCards = [
      deck.draw()!,
      deck.draw()!,
      deck.draw()!,
    ]

    firstPlayer.openTableCards = [
      deck.draw()!,
      deck.draw()!,
      deck.draw()!,
    ]

    secondPlayer.openTableCards = [
      deck.draw()!,
      deck.draw()!,
      deck.draw()!,
    ]

    let game = Game(players: [firstPlayer, secondPlayer], slowMode: false)

    asyncTest(timeout: 20) {
      await game.privateSetBurnt(deck.cards)
      _ = try await game.turn()
      let snapshot = await game.getSnapshot(for: nil, includeEndState: true)
      XCTAssertNotNil(snapshot.winner?.name)
    }
  }

  func gameCallsEndStateHandlerTests() {

    let firstPlayer = Player(
      name: "first",
      position: .noord,
      ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
    )
    let secondPlayer = Player(
      name: "second",
      position: .zuid,
      ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
    )

    let game = Game(players: [firstPlayer, secondPlayer], slowMode: false)

    asyncTest(timeout: 20) {
      try await game.startGame()
    }
  }
}
