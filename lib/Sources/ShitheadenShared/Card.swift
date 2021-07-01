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

  @inlinable public func apply(_ other: Self) -> Bool {
    number.afters.contains(other.number)
  }
}

public extension Array where Element == Card {
//  @inlinable mutating func sortNumbers() {
//    sort {
//      $0 < $1
//    }
//  }

  @inlinable mutating func sortCardsHandImportance() {
    sort {
      $0.number.handImportanceScore < $1.number.handImportanceScore
    }
  }

  @inlinable func sortedCardsHandImportance() -> Self {
    sorted {
      $0.number.handImportanceScore < $1.number.handImportanceScore
    }
  }

  @inlinable func sameNumber() -> Bool {
    !contains {
      $0.number != first?.number
    }
  }
}

public extension Card {
  @inlinable var order: Int {
    number.order
  }
}

extension Card: Comparable {
  @inlinable public static func < (lhs: Card, rhs: Card) -> Bool {
    lhs.number < rhs.number
  }
}

extension Number {
  @inlinable var handImportanceScore: Int {
    switch self {
    case .ten:
      return 1000
    case .three, .two:
      return 100
    default:
      return order
    }
  }
}
