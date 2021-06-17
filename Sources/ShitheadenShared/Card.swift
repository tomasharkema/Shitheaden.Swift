//
//  Card.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public struct Card: Equatable, Hashable {
  public let symbol: Symbol
  public let number: Number

  public init(symbol: Symbol, number: Number) {
    self.symbol = symbol
    self.number = number
  }

  public static let allCases = Symbol.allCases.flatMap { symbol in
    Number.allCases.map { number in
      Card(symbol: symbol, number: number)
    }
  }

  public var afters: [Self] {
    Symbol.allCases.flatMap { symbol in
      self.number.afters.map {
        Card(symbol: symbol, number: $0)
      }
    }
  }

  public func apply(_ other: Self) -> Bool {
    number.afters.contains(other.number)
  }
}

public extension Array where Element == Card {
  func sortNumbers() -> [Card] {
    return sorted {
      $0 < $1
    }
  }

//  func sortSymbol() -> [Card] {
//    let enumerated = Symbol.allCases.enumerated()
//    return sorted { l, r in
//      (enumerated.first { $0.element == l.symbol }?.offset ?? 100) <
//        (enumerated.first { $0.element == r.symbol }?.offset ?? 100)
//    }
//  }

  func sameNumber() -> Bool {
    return !contains {
      $0.number != first?.number
    }
  }
}

extension Card {
  public var order: Int {
    number.order
  }
}

extension Card: Comparable {
  public static func < (lhs: Card, rhs: Card) -> Bool {
    return lhs.number < rhs.number
  }
}
