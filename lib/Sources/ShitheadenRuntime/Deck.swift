//
//  Deck.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import ShitheadenShared

public struct Deck: Equatable, Codable {
  public private(set) var cards: [Card]

  init() {
    var cards = [Card]()
    for symbol in Symbol.allCases {
      for number in Number.allCases {
        cards.append(Card(id: UUID(), symbol: symbol, number: number))
      }
    }
    self.cards = cards
  }

  init(cards: [Card]) {
    self.cards = cards
  }

  mutating func shuffle(seed: [UInt8]?) {
    if let seed = seed {
      var generatorInstance = ARC4RandomNumberGenerator(seed: seed)
      cards.shuffle(using: &generatorInstance)
    } else {
      var generatorInstance = SystemRandomNumberGenerator()
      cards.shuffle(using: &generatorInstance)
    }
  }

  mutating func draw() -> Card? {
    if cards.isEmpty {
      return nil
    }
    let drawnCard = cards[0]
    cards.remove(at: 0)
    return drawnCard
  }

  static var new: Deck {
    var deck = Deck()
    deck.shuffle(seed: nil)
    return deck
  }
}
