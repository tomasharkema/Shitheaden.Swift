//
//  Turn.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Turn: Equatable, Hashable, Codable {
  case play(Set<Card>)
  case pass
  case closedCardIndex(Int)

  public func hash(into hasher: inout Hasher) {
    switch self {
    case let .play(cards):
      hasher.combine("play")
      hasher.combine(cards)
    case .pass:
      hasher.combine("pass")
    case let .closedCardIndex(index):
      hasher.combine("closedCardIndex")
      hasher.combine(index)
    }
  }

  public func verify() throws {
    switch self {
    case let .play(cards):
      if cards.isEmpty {
        throw PlayerError.notEmpty
      }
      if cards.contains(where: { $0.number != cards.first?.number }) {
        throw PlayerError.notSameNumber
      }

    case .closedCardIndex, .pass:
      return
    }
  }
}

public enum TurnNext {
  case turn(Turn)
  indirect case turnNext(Turn, TurnNext?)
}

public extension Array where Element: Equatable {
  func unique() -> [Element] {
    var found = [Element]()

    for element in self {
      if !found.contains(element) {
        found.append(element)
      }
    }

    return found
  }
}

public extension Array where Element == Turn {
  func includeDoubles() -> [Turn] {
    var turns = [Turn]()

    for element in self {
      turns.append(element)
      if case let .play(cards) = element {
        for card in cards {
          for case let .play(otherCards) in turns {
            var cardSet = Set([card])
            for element in otherCards.filter({ $0.number == card.number }) {
              cardSet.insert(element)
            }
            if cardSet.count > 1 {
              turns.append(Turn.play(cardSet))
            }
          }
        }
      }
    }
    return turns // .unique()
  }
}
