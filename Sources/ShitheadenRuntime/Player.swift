//
//  Player.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import ShitheadenShared

public struct Player: CustomStringConvertible, Equatable, Hashable {
  public internal(set) var handCards: [Card]
  public internal(set) var openTableCards: [Card]
  public internal(set) var closedTableCards: [Card]

  public let id: UUID = UUID()
  public let name: String
  public internal(set) var turns: [Turn]
  public let position: Position
  public let ai: GameAi

  public init(name: String, position: Position, ai: GameAi) {
    handCards = []
    openTableCards = []
    closedTableCards = []
    self.name = name
    turns = []
    self.position = position
    self.ai = ai
  }

  var phase: Phase {
    if !handCards.isEmpty {
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
//    case let .putOnTable(cards):
//
//      return "put on table"

    case let .closedCardIndex(i):
      return "put on table card \(i)"

    case .none:
      return ""
    }
  }

  public var done: Bool {
    return handCards.isEmpty && openTableCards.isEmpty && closedTableCards
      .isEmpty
  }

  mutating func sortCards() {
    handCards = handCards.sortNumbers()
  }

  public static func == (lhs: Player, rhs: Player) -> Bool {
    return lhs.handCards == rhs.handCards &&
      lhs.closedTableCards == rhs.closedTableCards &&
      lhs.openTableCards == rhs.openTableCards &&
      lhs.name == rhs.name
  }
}
