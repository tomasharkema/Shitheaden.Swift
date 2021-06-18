//
//  Deck.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ShitheadenShared

public struct Deck: Equatable {
  public private(set) var cards: [Card]

  mutating func draw() -> Card? {
    if cards.isEmpty {
      return nil
    }
    let drawnCard = cards[0]
    cards.remove(at: 0)
    return drawnCard
  }

  static var new: Deck {
    var cards = [Card]()
    for symbol in Symbol.allCases {
      for number in Number.allCases {
        cards.append(Card(symbol: symbol, number: number))
      }
    }
    cards.shuffle()
    return Deck(cards: cards)
  }
}
