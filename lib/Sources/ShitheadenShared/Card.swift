//
//  Card.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation

public struct Card: Equatable, Hashable, Codable {
  public let id: UUID
  public let symbol: Symbol
  public let number: Number

  public init(id: UUID, symbol: Symbol, number: Number) {
    self.id = id
    self.symbol = symbol
    self.number = number
  }

  public static let allCases = Symbol.allCases.flatMap { symbol in
    Number.allCases.map { number in
      Card(id: UUID(), symbol: symbol, number: number)
    }
  }

//  public var afters: [Self] {
//    Symbol.allCases.flatMap { symbol in
//      self.number.afters.map {
//        Card(id: UUID(), symbol: symbol, number: $0)
//      }
//    }
//  }

  public func apply(_ other: Self) -> Bool {
    number.afters.contains(other.number)
  }

//  public static func ==(lhs: Card, rhs :Card) -> Bool {
//    return lhs.symbol == rhs.symbol && lhs.number == rhs.number
//  }
}

public extension Array where Element == Card {
  func sortNumbers() -> [Card] {
    return sorted {
      $0 < $1
    }
  }

  func sameNumber() -> Bool {
    return !contains {
      $0.number != first?.number
    }
  }
}

public extension Card {
  var order: Int {
    number.order
  }
}

extension Card: Comparable {
  public static func < (lhs: Card, rhs: Card) -> Bool {
    return lhs.number < rhs.number
  }
}
