//
//  Player.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

struct Player: CustomStringConvertible, Equatable, Hashable {
  var handCards: [Card]
  var openTableCards: [Card]
  var closedTableCards: [Card]

  let name: String
  var turns: [Turn]
  let position: Position
  let ai: PlayerMove
  var hasPutCardsOpen: Bool = false

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

  var description: String {
    return "SPELER_description"
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }

  var latestState: String {
    switch turns.last {
    case let .play(t):
      return "played \(t)"
    case .pass:
      return "took all cards"
    case let .putOnTable(cards):

      return "put on table"
    case .none:
      return ""
    }
  }

  var showedTable: String {
    return openTableCards.map { $0.description }.joined(separator: " ")
  }

  var closedTable: String {
    return closedTableCards.map { _ in "0" }.joined(separator: " ")
  }

  var closedTableShowed: String {
    return closedTableCards.map { $0.description }.joined(separator: " ")
  }

  var done: Bool {
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

  func possibleTurns(table: Table) -> Set<Turn> {
    switch phase {
    case .putOnTable:

      var turns = [Turn]()
      for firstIteration in handCards {
        for secondIteration in handCards.filter { $0 != firstIteration } {
          for thirdIteration in handCards.filter { $0 != firstIteration && $0 != secondIteration } {
            turns.append(Turn.putOnTable(firstIteration, secondIteration, thirdIteration))
          }
        }
      }

      return turns.includeDoubles

    case .hand:
      let actions = handCards.filter { table.lastCard?.afters.contains($0) ?? true }
        .map { Turn.play([$0]) }
      return Array([actions, [.pass]].joined()).includeDoubles

    case .tableOpen:
      let actions = openTableCards.filter { table.lastCard?.afters.contains($0) ?? true }
        .map { Turn.play([$0]) }
      if actions.isEmpty {
        return [Turn.pass]
      }
      return actions.includeDoubles

    case .tableClosed:
      return Set(closedTableCards.map { Turn.play([$0]) })
    }
  }

  static func == (lhs: Player, rhs: Player) -> Bool {
    return lhs.handCards == rhs.handCards &&
      lhs.closedTableCards == rhs.closedTableCards &&
      lhs.openTableCards == rhs.openTableCards &&
      lhs.name == rhs.name
  }
}
