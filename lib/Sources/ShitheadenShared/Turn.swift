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
    case let .closedCardIndex(i):
      hasher.combine("closedCardIndex")
      hasher.combine(i)
    }
  }

  public func verify() throws {
    switch self {
    case let .play(cards):
      if cards.isEmpty {
        throw PlayerError(text: "Not empty")
      }
      if cards.contains(where: { $0.number != cards.first?.number }) {
        print(cards)
        throw PlayerError(text: "Not all the same")
      }

//    case let .putOnTable(a, b, c):
//      if [a, b, c].doubles() {
//        throw PlayerError(text: "Found double")
//      }

    case .closedCardIndex, .pass:
      return
    }
  }
}

public extension Array where Element: Equatable {
  func unique() -> [Element] {
    var found = [Element]()

    for e in self {
      if !found.contains(e) {
        found.append(e)
      }
    }

    return found
  }
}

public extension Array where Element == Turn {
  func includeDoubles() -> [Turn] {
    var turns = [Turn]()

    for el in self {
      turns.append(el)
      if case let .play(cards) = el {
        for card in cards {
          for case let .play(otherCards) in turns {
            var a = Set([card])
            // a.insert(contentsOf: otherCards.filter { $0.number == card.number })
            for e in otherCards.filter({ $0.number == card.number }) {
              a.insert(e)
            }
            if a.count > 1 {
              turns.append(Turn.play(a))
            }
          }
        }
      }
    }
    return turns // .unique()
  }
}
