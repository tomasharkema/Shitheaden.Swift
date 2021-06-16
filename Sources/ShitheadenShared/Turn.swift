//
//  Turn.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Turn: Equatable, Hashable {
  case play(Set<Card>)
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
    case .closedCardIndex(let i):
      hasher.combine("closedCardIndex")
      hasher.combine(i)
    }
  }
}
