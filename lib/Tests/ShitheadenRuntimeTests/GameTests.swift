//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import CustomAlgo
import Foundation
@testable import ShitheadenRuntime
import XCTest

class GameTests: XCTestCase {
  func testNormalRunFourPlayers() {
    let game = Game(players: [
      Player(
        name: "West (Unfair)",
        position: .west,
        ai: CardRankingAlgo()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgo()
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
    ], slowMode: false, endGameHandler: { _ in })

    let expectation = XCTestExpectation(description: "wait for game play")

    if #available(macOS 12.0, iOS 15, *) {
      async {
        do {
          let snapshot = try await game.startGame()
          XCTAssertNotNil(snapshot.winner)

        } catch {
          XCTFail("ERROR: \(error)")
        }
        expectation.fulfill()
      }
    }
    wait(for: [expectation], timeout: 120.0)
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
    ], slowMode: false, endGameHandler: { _ in })

    let expectation = XCTestExpectation(description: "wait for game play")

    if #available(macOS 12.0, iOS 15, *) {
      async {
        do {
          let snapshot = try await game.startGame()
          XCTAssertNotNil(snapshot.winner)
        } catch {
          XCTFail("ERROR: \(error)")
        }
        expectation.fulfill()
      }
    }
    wait(for: [expectation], timeout: 120.0)
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
        .contains { $0.number == card.number && $0.symbol == card.symbol } {
        return false
      }
      if secondPlayer.handCards
        .contains { $0.number == card.number && $0.symbol == card.symbol } {
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

    let game = Game(players: [firstPlayer, secondPlayer], slowMode: false, endGameHandler: { _ in })

    let expectation = XCTestExpectation(description: "wait for game play")

    if #available(macOS 12.0, iOS 15, *) {
      async { [deck] in
        do {
          await game.privateSetBurnt(deck.cards)

          _ = try await game.turn()
          let snapshot = await game.getSnapshot(for: nil, includeEndState: true)

          XCTAssertNotNil(snapshot.winner?.name)
        } catch {
          XCTFail("ERROR: \(error)")
        }
        expectation.fulfill()
      }
    }
    wait(for: [expectation], timeout: 120.0)
  }

  func gameCallsEndStateHandlerTests() {
    let exp = XCTestExpectation()

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

    let game = Game(players: [firstPlayer], slowMode: false, endGameHandler: { _ in
      exp.fulfill()
    })

    async {
      try await game.startGame()
    }

    wait(for: [exp], timeout: 120.0)
  }
}
