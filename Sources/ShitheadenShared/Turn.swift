//
//  Turn.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

enum Turn: Equatable, Hashable {
  case play(Set<Card>)
  case putOnTable(Card, Card, Card)
  case pass

  func hash(into hasher: inout Hasher) {
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
    }
  }
}
