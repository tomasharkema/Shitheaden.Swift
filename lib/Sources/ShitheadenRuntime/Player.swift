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
  var handCards: [Card]
  var openTableCards: [Card]
  var closedTableCards: [Card]

  let id: UUID
  let name: String
  var turns: [TurnNext]
  let position: ShitheadenShared.Position
  let ai: GameAi

  public init(id: UUID = UUID(), name: String, position: ShitheadenShared.Position, ai: GameAi) {
    self.id = id
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
    "SPELER_description"
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public var done: Bool {
    handCards.isEmpty && openTableCards.isEmpty && closedTableCards
      .isEmpty
  }

  mutating func sortCards() {
    handCards = handCards.sortNumbers()
  }

  public static func == (lhs: Player, rhs: Player) -> Bool {
    lhs.handCards == rhs.handCards &&
      lhs.closedTableCards == rhs.closedTableCards &&
      lhs.openTableCards == rhs.openTableCards &&
      lhs.name == rhs.name
  }
}
