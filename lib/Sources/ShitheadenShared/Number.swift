//
//  Number.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Number: CaseIterable, Equatable, Hashable, Codable {
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
}

extension Number {
  private static let TwoAfter: Set<Number> = Set(
    arrayLiteral: .two,
    .three,
    .four,
    .five,
    .six,
    .seven,
    .eight,
    .nine,
    .ten,
    .boer,
    .vrouw,
    .heer,
    .aas
  )
  private static let ThreeAfter: Set<Number> = Set(
    arrayLiteral: .two,
    .three,
    .four,
    .five,
    .six,
    .seven,
    .eight,
    .nine,
    .ten,
    .boer,
    .vrouw,
    .heer,
    .aas
  )
  private static let FourAfter: Set<Number> = Set(
    arrayLiteral: .two,
    .three,
    .four,
    .five,
    .six,
    .seven,
    .eight,
    .nine,
    .ten,
    .boer,
    .vrouw,
    .heer,
    .aas
  )
  private static let FiveAfter: Set<Number> = Set(
    arrayLiteral: .two,
    .three,
    .five,
    .six,
    .seven,
    .eight,
    .nine,
    .ten,
    .boer,
    .vrouw,
    .heer,
    .aas
  )
  private static let SixAfter: Set<Number> = Set(
    arrayLiteral: .two,
    .three,
    .six,
    .seven,
    .eight,
    .nine,
    .ten,
    .boer,
    .vrouw,
    .heer,
    .aas
  )
  private static let SevenAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .four, .five, .six,
    .seven, .ten
  )
  private static let EightAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .eight, .nine, .ten,
    .boer, .vrouw, .heer, .aas
  )
  private static let NineAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .nine, .ten, .boer,
    .vrouw, .heer, .aas
  )
  private static let TenAfter: Set<Number> = Set(
    arrayLiteral: .two,
    .three,
    .four,
    .five,
    .six,
    .seven,
    .eight,
    .nine,
    .ten,
    .boer,
    .vrouw,
    .heer,
    .aas
  )
  private static let BoerAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .ten, .boer, .vrouw,
    .heer, .aas
  )
  private static let VrouwAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .ten, .vrouw, .heer,
    .aas
  )
  private static let HeerAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .ten, .heer, .aas
  )
  private static let AasAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .ten, .aas
  )

  public var afters: Set<Number> {
    // staticly is way quicker
    switch self {
    case .two:
      return Number.TwoAfter
    case .three:
      return Number.ThreeAfter
    case .four:
      return Number.FourAfter
    case .five:
      return Number.FiveAfter
    case .six:
      return Number.SixAfter
    case .seven:
      return Number.SevenAfter
    case .eight:
      return Number.EightAfter
    case .nine:
      return Number.NineAfter
    case .ten:
      return Number.TenAfter
    case .boer:
      return Number.BoerAfter
    case .vrouw:
      return Number.VrouwAfter
    case .heer:
      return Number.HeerAfter
    case .aas:
      return Number.AasAfter
    }

//    if self == .two {
//      // return Set([.three, .two, .ten])
//      return Set(Number.allCases)
//
//    } else if self == .seven {
//      return Set([Number.nonSpecials.drop { $0 != .seven }, [.three, .two, .ten, .two], [self]]
//        .joined())
//    } else {
//      return Set([
//        Number.nonSpecials.prefix { $0 != self },
//        [.three, .two, .ten, .two],
//        [self],
//      ].joined())
//    }
  }
}

public extension Number {
  var order: Int {
    switch self {
    case .two:
      return 2
    case .three:
      return 3
    case .four:
      return 4
    case .five:
      return 5
    case .six:
      return 6
    case .seven:
      return 7
    case .eight:
      return 8
    case .nine:
      return 9
    case .ten:
      return 10
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
