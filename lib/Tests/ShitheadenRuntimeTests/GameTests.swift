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
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
      ),
      Player(
        name: "Oost",
        position: .oost,
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
      ),
      Player(
        name: "Zuid",
        position: .zuid,
          ai: CardRankingAlgo()
      ),
    ], slowMode: false)

    asyncTest(timeout: 120) {
      var deck = Deck()
      deck.shuffle(seed: seed)
      await game.set(deck: deck)
      try await game.deel()
      try await game.beginRound()
      try await game.turn()
    }
  }

  func testNormalRunTwoPlayers() {
    let game = Game(players: [
      Player(
        name: "West (Unfair)",
        position: .west,
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgo()
      ),
    ], slowMode: false)

    asyncTest(timeout: 120) {
      var deck = Deck()
      deck.shuffle(seed: seed)
      await game.set(deck: deck)
      try await game.deel()
      try await game.beginRound()
      try await game.turn()
    }
  }

  func testDeadlockPrevention() {
    var deck = Deck.new

    var firstPlayer = Player(
      name: "first",
      position: .noord,
      ai: CardRankingAlgo()
    )
    var secondPlayer = Player(
      name: "second",
      position: .zuid,
      ai: CardRankingAlgo()
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

    let cards = deck.cards.filter { card in
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
    }

    deck = Deck(cards: cards)

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

    asyncTest(timeout: 120) {
      await game.set(deck: Deck(cards: []))
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

    asyncTest(timeout: 120) {
      try await game.startGame()
    }
  }
}

let seed: [UInt8] = [
  57,
  196,
  243,
  86,
  164,
  111,
  173,
  13,
  71,
  148,
  171,
  244,
  122,
  159,
  29,
  219,
  14,
  62,
  105,
  7,
  85,
  208,
  73,
  132,
  201,
  255,
  144,
  2,
  117,
  143,
  84,
  63,
  169,
  228,
  138,
  216,
  60,
  130,
  163,
  158,
  120,
  206,
  205,
  79,
  218,
  189,
  133,
  10,
  249,
  181,
  82,
  178,
  102,
  87,
  53,
  123,
  151,
  226,
  75,
  44,
  97,
  156,
  229,
  149,
  231,
  11,
  110,
  233,
  221,
  41,
  6,
  58,
  166,
  142,
  88,
  25,
  197,
  202,
  83,
  242,
  192,
  215,
  125,
  24,
  182,
  59,
  67,
  20,
  50,
  174,
  246,
  191,
  254,
  157,
  69,
  204,
  184,
  64,
  37,
  81,
  23,
  188,
  101,
  70,
  96,
  12,
  153,
  176,
  90,
  42,
  118,
  220,
  55,
  108,
  124,
  129,
  224,
  38,
  66,
  194,
  239,
  9,
  212,
  225,
  28,
  177,
  162,
  210,
  76,
  168,
  252,
  43,
  131,
  238,
  179,
  198,
  113,
  72,
  106,
  214,
  240,
  170,
  127,
  32,
  16,
  235,
  211,
  180,
  248,
  145,
  150,
  245,
  1,
  187,
  61,
  172,
  98,
  183,
  115,
  253,
  227,
  116,
  65,
  33,
  126,
  36,
  15,
  217,
  250,
  31,
  47,
  78,
  3,
  200,
  27,
  135,
  80,
  222,
  114,
  107,
  146,
  247,
  8,
  207,
  209,
  236,
  99,
  139,
  5,
  35,
  52,
  4,
  103,
  77,
  40,
  241,
  93,
  185,
  213,
  167,
  39,
  141,
  17,
  121,
  45,
  30,
  193,
  186,
  74,
  119,
  232,
  190,
  155,
  92,
  154,
  68,
  109,
  54,
  237,
  21,
  56,
  128,
  34,
  19,
  199,
  175,
  18,
  161,
  140,
  104,
  165,
  234,
  230,
  195,
  49,
  51,
  26,
  94,
  136,
  89,
  112,
  48,
  22,
  91,
  147,
  203,
  134,
  95,
  152,
  100,
  46,
  251,
  223,
  160,
  137,
]
