//
//  Card.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

struct Card: CustomStringConvertible, Equatable, Hashable {
  let symbol: Symbol
  let number: Number

  static let allCases = Symbol.allCases.flatMap { symbol in
    Number.allCases.map { number in
      Card(symbol: symbol, number: number)
    }
  }

  var description: String {
    let color = symbol.color

    return color >>> "\(symbol.string)\(number.string)"
  }

  var afters: [Self] {
    Symbol.allCases.flatMap { symbol in
      self.number.afters.map {
        Card(symbol: symbol, number: $0)
      }
    }
  }

  func apply(_ other: Self) -> Bool {
    number.afters.contains(other.number)
  }
}
