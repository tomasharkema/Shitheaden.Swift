//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import CustomAlgo
import Foundation
@testable import ShitheadenRuntime
@testable import ShitheadenShared
import TestsHelpers
import XCTest

class GameTests: XCTestCase {
  func testNormalRunFourPlayers() {
    let game = Game(players: [
      Player(
        name: "West (Unfair)",
        position: .west,
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware.make()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware.make()
      ),
      Player(
        name: "Oost",
        position: .oost,
        ai: CardRankingAlgoWithUnfairPassing.make()
      ),
      Player(
        name: "Zuid",
        position: .zuid,
        ai: CardRankingAlgo.make()
      ),
    ], rules: .all, slowMode: false)

    asyncTest(timeout: 20) {
      await game.set(deck: randomDeck)
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
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware.make()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgo.make()
      ),
    ], rules: .all, slowMode: false)

    asyncTest(timeout: 20) {
      await game.set(deck: randomDeck)
      try await game.deel()
      try await game.beginRound()
      try await game.turn()
    }
  }

  func testDeadlockPrevention() {
    var deck = randomDeck

    var firstPlayer = Player(
      name: "first",
      position: .noord,
      ai: CardRankingAlgo.make()
    )
    var secondPlayer = Player(
      name: "second",
      position: .zuid,
      ai: CardRankingAlgo.make()
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

    let cards: [Card] = deck.cards.filter { card in
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

    let game = Game(players: [firstPlayer, secondPlayer], rules: .all, slowMode: false)

    asyncTest(timeout: 20) {
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
      ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware.make()
    )
    let secondPlayer = Player(
      name: "second",
      position: .zuid,
      ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware.make()
    )

    let game = Game(players: [firstPlayer, secondPlayer], rules: .all, slowMode: false)

    asyncTest(timeout: 20) {
      try await game.startGame()
    }
  }
}

let randomDeck = Deck(cards: [
  Card(
    id: UUID(uuidString: "B133A405-CE28-4FCF-9194-D4F982316919")!,
    symbol: Symbol.klaver,
    number: Number.seven
  ),
  Card(
    id: UUID(uuidString: "26949D9C-2742-41DA-A219-51868A6D434C")!,
    symbol: Symbol.klaver,
    number: Number.six
  ),
  Card(
    id: UUID(uuidString: "A3089E28-B2A1-4CD6-9D22-34DB2538E674")!,
    symbol: Symbol.klaver,
    number: Number.five
  ),
  Card(
    id: UUID(uuidString: "6ACFEEDC-E1EA-4F47-8BDC-A2F11BF5F015")!,
    symbol: Symbol.klaver,
    number: Number.four
  ),
  Card(
    id: UUID(uuidString: "7A2553B5-5717-41D9-9EDC-341371967D5D")!,
    symbol: Symbol.klaver,
    number: Number.ten
  ),
  Card(
    id: UUID(uuidString: "DED9E56B-1033-4F3D-BA0D-0BAEEF8E9BF7")!,
    symbol: Symbol.klaver,
    number: Number.three
  ),
  Card(
    id: UUID(uuidString: "96E30FA5-06A7-4BE0-ACC2-B73B125230DD")!,
    symbol: Symbol.klaver,
    number: Number.two
  ),
  Card(
    id: UUID(uuidString: "C3367A21-F997-4616-919F-66644F9D2B29")!,
    symbol: Symbol.harten,
    number: Number.aas
  ),
  Card(
    id: UUID(uuidString: "3428ADA0-8939-471A-81AC-7D4B3F83AEA6")!,
    symbol: Symbol.harten,
    number: Number.gold
  ),
  Card(
    id: UUID(uuidString: "03A241FD-DBBE-4618-B895-BD010B45445C")!,
    symbol: Symbol.harten,
    number: Number.silver
  ),
  Card(
    id: UUID(uuidString: "0B980371-5FE3-4F49-B007-E305FC64EFBB")!,
    symbol: Symbol.harten,
    number: Number.bronze
  ),
  Card(
    id: UUID(uuidString: "9A69BF20-34E9-4D12-9C57-348715A70267")!,
    symbol: Symbol.harten,
    number: Number.nine
  ),
  Card(
    id: UUID(uuidString: "99D3A5B9-41E1-4BB8-9A91-874C1B250AFE")!,
    symbol: Symbol.harten,
    number: Number.eight
  ),
  Card(
    id: UUID(uuidString: "933C8619-2919-4D37-8206-9446A80ED498")!,
    symbol: Symbol.harten,
    number: Number.seven
  ),
  Card(
    id: UUID(uuidString: "B6FB7008-92A8-4C81-9B41-8FF2DEE6B466")!,
    symbol: Symbol.harten,
    number: Number.six
  ),
  Card(
    id: UUID(uuidString: "C9F2D043-AD62-4AD4-BF43-7CAA94162A9A")!,
    symbol: Symbol.harten,
    number: Number.five
  ),
  Card(
    id: UUID(uuidString: "599498BD-CC45-40B7-8D98-55508FBA151C")!,
    symbol: Symbol.harten,
    number: Number.four
  ),
  Card(
    id: UUID(uuidString: "1ECE30C0-6140-4A4E-88BB-46E77176539D")!,
    symbol: Symbol.harten,
    number: Number.ten
  ),
  Card(
    id: UUID(uuidString: "19770A83-5D3D-4543-92C3-5D7D9BA6FE63")!,
    symbol: Symbol.harten,
    number: Number.three
  ),
  Card(
    id: UUID(uuidString: "B18C2D88-0A46-4D27-98A9-F8DC020294FD")!,
    symbol: Symbol.harten,
    number: Number.two
  ),
  Card(id: UUID(uuidString: "CFB9273E-008C-4793-918D-4B5BD4697579")!, symbol: Symbol.ruiten,
       number: Number.aas),
  Card(
    id: UUID(uuidString: "529961F4-69C2-4E61-B825-7E5247888D84")!,
    symbol: Symbol.ruiten,
    number: Number.gold
  ),
  Card(
    id: UUID(uuidString: "D577DE7F-D9CB-4C33-8B7F-6B92AED30FE3")!,
    symbol: Symbol.ruiten,
    number: Number.silver
  ),
  Card(
    id: UUID(uuidString: "C619303B-75E7-455A-B54F-9D4CDB16371D")!,
    symbol: Symbol.ruiten,
    number: Number.bronze
  ),
  Card(
    id: UUID(uuidString: "AE14F479-7B7C-4ED0-A1A8-2C056EBFBD69")!,
    symbol: Symbol.ruiten,
    number: Number.nine
  ),
  Card(
    id: UUID(uuidString: "6D04E742-2F84-455D-926E-43637B2ACC1E")!,
    symbol: Symbol.ruiten,
    number: Number.eight
  ),
  Card(
    id: UUID(uuidString: "C3EDC49A-B972-40F8-910F-5425D0AECA4A")!,
    symbol: Symbol.ruiten,
    number: Number.seven
  ),
  Card(
    id: UUID(uuidString: "D8B1DBFE-5960-4E1A-9386-79AB216F254A")!,
    symbol: Symbol.ruiten,
    number: Number.six
  ),
  Card(
    id: UUID(uuidString: "CC2A0CB1-5042-4C30-9F9F-0149E9FBDF54")!,
    symbol: Symbol.ruiten,
    number: Number.five
  ),
  Card(
    id: UUID(uuidString: "B79C8D8E-90E1-4078-ACF1-A99211D0061B")!,
    symbol: Symbol.ruiten,
    number: Number.four
  ),
  Card(
    id: UUID(uuidString: "43AEBDF2-C4A9-4FAD-83C9-FD175A1BEA0E")!,
    symbol: Symbol.ruiten,
    number: Number.ten
  ),
  Card(
    id: UUID(uuidString: "752E0596-8719-4756-91EA-2730CE20394B")!,
    symbol: Symbol.ruiten,
    number: Number.three
  ),
  Card(
    id: UUID(uuidString: "87B9249D-BB94-4074-A833-F38207FB3ED0")!,
    symbol: Symbol.ruiten,
    number: Number.two
  ),
  Card(
    id: UUID(uuidString: "F6B7881F-72E1-4C98-B16E-D085285E9E48")!,
    symbol: Symbol.schoppen,
    number: Number.aas
  ),
  Card(
    id: UUID(uuidString: "5623A3DA-5433-42CB-BC05-4977448626A3")!,
    symbol: Symbol.schoppen,
    number: Number.gold
  ),
  Card(
    id: UUID(uuidString: "36EEDC19-D19A-4688-A015-6D1E451D0125")!,
    symbol: Symbol.schoppen,
    number: Number.silver
  ),
  Card(
    id: UUID(uuidString: "E25DFA5F-4EFA-49A7-B8DB-F4856D4FD0DD")!,
    symbol: Symbol.schoppen,
    number: Number.bronze
  ),
  Card(
    id: UUID(uuidString: "EF479073-117C-48E6-B4B9-B34D65410EEE")!,
    symbol: Symbol.schoppen,
    number: Number.nine
  ),
  Card(
    id: UUID(uuidString: "AD11AF8D-3D0D-42E4-B64F-579A8CA498E5")!,
    symbol: Symbol.schoppen,
    number: Number.eight
  ),
  Card(
    id: UUID(uuidString: "809185B0-34FD-4693-9568-31796CFD7258")!,
    symbol: Symbol.schoppen,
    number: Number.seven
  ),
  Card(
    id: UUID(uuidString: "E223C71D-5D46-4267-860C-B13143B0A348")!,
    symbol: Symbol.schoppen,
    number: Number.six
  ),
  Card(
    id: UUID(uuidString: "B7C19970-9D35-4805-863D-D626CDC4D51F")!,
    symbol: Symbol.schoppen,
    number: Number.five
  ),
  Card(
    id: UUID(uuidString: "40B3A059-6C71-4560-AA5C-4E1588399754")!,
    symbol: Symbol.schoppen,
    number: Number.four
  ),
  Card(
    id: UUID(uuidString: "C7405B1D-0224-4A3E-A563-465AB649E758")!,
    symbol: Symbol.schoppen,
    number: Number.ten
  ),
  Card(
    id: UUID(uuidString: "D79BB66D-5F75-44D7-926D-CEF7F9A5BA2E")!,
    symbol: Symbol.schoppen,
    number: Number.three
  ),
  Card(
    id: UUID(uuidString: "12E6C9D1-77B9-4B8D-B067-10BD60C16B0B")!,
    symbol: Symbol.schoppen,
    number: Number.two
  ),
  Card(
    id: UUID(uuidString: "7D1B0C4B-02E7-4168-9577-F7D6216417DB")!,
    symbol: Symbol.klaver,
    number: Number.aas
  ),
  Card(
    id: UUID(uuidString: "9F656416-DF06-478D-93E1-77246B6CFEDB")!,
    symbol: Symbol.klaver,
    number: Number.gold
  ),
  Card(
    id: UUID(uuidString: "3C7319EB-9B0B-4751-AC44-D679F0EABA4E")!,
    symbol: Symbol.klaver,
    number: Number.silver
  ),
  Card(
    id: UUID(uuidString: "E06361D8-6D42-4621-9C2D-FD7684B10149")!,
    symbol: Symbol.klaver,
    number: Number.bronze
  ),
  Card(
    id: UUID(uuidString: "F3E1B452-F024-4AF0-ACCA-4909828D9862")!,
    symbol: Symbol.klaver,
    number: Number.nine
  ),
  Card(
    id: UUID(uuidString: "ED5DBD39-2DDF-43D1-A374-9E6D2BC6E72B")!,
    symbol: Symbol.klaver,
    number: Number.eight
  ),
])
