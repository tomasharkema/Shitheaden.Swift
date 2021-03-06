//
//  File.swift
//
//
//  Created by Tomas Harkema on 26/06/2021.
//

@testable import CustomAlgo
import ShitheadenRuntime
import ShitheadenShared
import TestsHelpers
import XCTest

class CardRankingAlgoWithUnfairPassingAndNexPlayerAwareTests: XCTestCase {
  func testCardRankingAlgoWithUnfairPassingAndNexPlayerAwareTestsOpenCards() {
    let currentPlayerId = UUID()

    let currentPlayer = TurnRequest(
      rules: Rules.all,
      id: currentPlayerId, name: "currentPlayer", handCards: [
        .card(card: .init(id: UUID(), symbol: .ruiten, number: .six)),
        .card(card: .init(id: UUID(), symbol: .ruiten, number: .seven)),
        .card(card: .init(id: UUID(), symbol: .ruiten, number: .nine)),

      ], openTableCards: [], lastTableCard: nil, closedCards: [], phase: .hand, tableCards: [],
      deckCards: [], algoName: "", done: false, position: .noord, isObscured: false,
      playerError: nil, endState: nil
    )

    let nextPlayerId = UUID()
    let nextPlayer = TurnRequest(
      rules: Rules.all,
      id: nextPlayerId, name: "nextPlayer", handCards: [], openTableCards: [
        .card(card: .init(id: UUID(), symbol: .harten, number: .six)),
        .card(card: .init(id: UUID(), symbol: .harten, number: .seven)),
        .card(card: .init(id: UUID(), symbol: .harten, number: .eight)),
      ], lastTableCard: nil, closedCards: [], phase: .tableOpen, tableCards: [], deckCards: [],
      algoName: "", done: false, position: .oost, isObscured: true, playerError: nil, endState: nil
    )

    let gameSnapShot = GameSnapshot(
      deckCards: [],
      players: [currentPlayer, nextPlayer],
      tableCards: [],
      burntCards: [],
      playersOnTurn: Set(arrayLiteral: currentPlayerId),
      requestFor: currentPlayerId,
      beginDate: Date().timeIntervalSince1970,
      endDate: nil, turns: nil
    )

    let algo = CardRankingAlgoWithUnfairPassingAndNexPlayerAware()

    let expectation = XCTestExpectation(description: "wait for game play")

    asyncTest(timeout: 20) {
      let turn = await algo.move(request: currentPlayer, snapshot: gameSnapShot)

      XCTAssertEqual(turn.playedCards.first?.number, .nine)
    }
  }

  func testCardRankingAlgoWithUnfairPassingAndNexPlayerAwareTestsClosedCards() {
    let currentPlayerId = UUID()

    let currentPlayer = TurnRequest(
      rules: Rules.all,
      id: currentPlayerId, name: "currentPlayer", handCards: [
        .card(card: .init(id: UUID(), symbol: .ruiten, number: .six)),
        .card(card: .init(id: UUID(), symbol: .ruiten, number: .seven)),
        .card(card: .init(id: UUID(), symbol: .ruiten, number: .nine)),

      ], openTableCards: [], lastTableCard: nil, closedCards: [], phase: .hand, tableCards: [],
      deckCards: [], algoName: "", done: false, position: .noord, isObscured: false,
      playerError: nil, endState: nil
    )

    let nextPlayerId = UUID()
    let nextPlayer = TurnRequest(
      rules: Rules.all,
      id: nextPlayerId, name: "nextPlayer", handCards: [], openTableCards: [
      ], lastTableCard: nil, closedCards: [
        .hidden(id: UUID()),
        .hidden(id: UUID()),
        .hidden(id: UUID()),
      ], phase: .tableClosed, tableCards: [], deckCards: [],
      algoName: "", done: false, position: .oost, isObscured: true, playerError: nil, endState: nil
    )

    let gameSnapShot = GameSnapshot(
      deckCards: [],
      players: [currentPlayer, nextPlayer],
      tableCards: [],
      burntCards: [],
      playersOnTurn: Set(arrayLiteral: currentPlayerId),
      requestFor: currentPlayerId,
      beginDate: Date().timeIntervalSince1970,
      endDate: nil, turns: nil
    )

    let algo = CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
    asyncTest(timeout: 20) {
      let turn = await algo.move(request: currentPlayer, snapshot: gameSnapShot)

      XCTAssertEqual(turn.playedCards.first?.number, .nine)
    }
  }
}
