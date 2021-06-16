//
//  Number.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Number: CaseIterable, Equatable {
  case aas
  case heer
  case vrouw
  case boer
  case nine
  case eight
  case seven
  case six
  case five
  case four

  case ten
  case three
  case two

  static let specials: [Self] = [.ten, .three, .two]
  static let nonSpecials: [Self] = Number.allCases.filter { !specials.contains($0) }

  public var string: String {
    switch self {
    case .aas:
      return "A"
    case .heer:
      return "H"
    case .vrouw:
      return "V"
    case .boer:
      return "B"
    case .ten:
      return "10"
    case .nine:
      return "9"
    case .eight:
      return "8"
    case .seven:
      return "7"
    case .six:
      return "6"
    case .five:
      return "5"
    case .four:
      return "4"
    case .three:
      return "3"
    case .two:
      return "2"
    }
  }

  public var afters: Set<Number> {
    if self == .two {
      // return Set([.three, .two, .ten])
      return Set(Number.allCases)

    } else if self == .seven {
      return Set([Number.nonSpecials.drop { $0 != .seven }, [.three, .two, .ten, .two], [self]]
        .joined())
    } else {
      return Set([
        Number.nonSpecials.prefix { $0 != self },
        [.three, .two, .ten, .two],
        [self],
      ].joined())
    }
  }
}

extension Number {
  var order: Int {
    switch self {
    case .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten:
      return Int(string) ?? Int.max
    case .boer:
      return 11
    case .vrouw:
      return 12
    case .heer:
      return 13
    case .aas:
      return 14
    }
  }
}

extension Number: Comparable {
  public static func < (lhs: Number, rhs: Number) -> Bool {
    return lhs.order < rhs.order
  }
}
