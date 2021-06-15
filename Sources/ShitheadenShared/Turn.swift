//
//  Turn.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Turn: Equatable, Hashable {
  case play([Card])
  case putOnTable(Card, Card, Card)
  case pass
  case closedCardIndex(Int)

  public func hash(into hasher: inout Hasher) {
    switch self {
    case let .play(cards):
      hasher.combine("play")
      hasher.combine(cards)
    case let .putOnTable(f, s, t):
      hasher.combine("putOnTable")
      hasher.combine(f)
      hasher.combine(s)
      hasher.combine(t)
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

      if cards.doubles() {
        print("cards", cards)
        throw PlayerError(text: "Found double")
      }

    case let .putOnTable(a, b, c):
      if [a, b, c].doubles() {
        throw PlayerError(text: "Found double")
      }

    case .closedCardIndex, .pass:
      return
    }
  }
}

extension Array where Element: Equatable {
public func doubles() -> Bool {
    var elements = [Element]()

    for e in self {
      if elements.contains(e) {
        print("doubles", elements, e)
        return true
      }
      elements.append(e)
    }

    return false
  }

  public func unique() -> [Element] {
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
  var includeDoubles: [Turn] {
    var turns = [Turn]()

    for el in self {
      turns.append(el)

      if case let .play(cards) = el {
        for card in cards {
          for case let .play(otherCards) in turns {
            var a = [card]
            // a.insert(contentsOf: otherCards.filter { $0.number == card.number })
            for e in otherCards.filter({ $0.number == card.number && $0.symbol != card.symbol }) {
              a.append(e)
            }

            turns.append(Turn.play(a.sortSymbol()))
          }
        }
      }
    }
    return turns.unique()
  }
}
