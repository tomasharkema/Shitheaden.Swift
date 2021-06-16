//
//  Player.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ShitheadenShared

public struct Player: CustomStringConvertible, Equatable, Hashable {
  public internal(set) var handCards: [Card]
  public internal(set) var openTableCards: [Card]
  public internal(set) var closedTableCards: [Card]

  public let name: String
  public internal(set) var turns: [Turn]
  public let position: Position
  public let ai: GameAi
  public internal(set) var hasPutCardsOpen: Bool = false

  public init(name: String, position: Position, ai: GameAi) {
    self.handCards = []
    self.openTableCards = []
    self.closedTableCards = []
    self.name = name
    self.turns = []
    self.position = position
    self.ai = ai
  }

  var phase: Phase {
    if openTableCards.isEmpty, !hasPutCardsOpen {
      return .putOnTable
    } else if !handCards.isEmpty {
      return .hand
    } else if !openTableCards.isEmpty {
      return .tableOpen
    } else {
      return .tableClosed
    }
  }

  public var description: String {
    return "SPELER_description"
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }

  public var latestState: String {
    switch turns.last {
    case let .play(t):
      return "played \(t)"
    case .pass:
      return "took all cards"
    case let .putOnTable(cards):

      return "put on table"

    case .closedCardIndex(let i):
      return "put on table card \(i)"

    case .none:
      return ""
    }
  }

  public var done: Bool {
    return hasPutCardsOpen && handCards.isEmpty && openTableCards.isEmpty && closedTableCards
      .isEmpty
  }

  mutating func sortCards() {
    handCards = handCards.sorted { l, r in
      let enumerated = Number.allCases.enumerated()
      return (enumerated.first { $0.element == l.number }?.offset ?? 100) <
        (enumerated.first { $0.element == r.number }?.offset ?? 100)
    }
  }

  public static func == (lhs: Player, rhs: Player) -> Bool {
    return lhs.handCards == rhs.handCards &&
      lhs.closedTableCards == rhs.closedTableCards &&
      lhs.openTableCards == rhs.openTableCards &&
      lhs.name == rhs.name
  }
}
