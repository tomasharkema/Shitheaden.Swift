//
//  Number.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Number: CaseIterable, Equatable, Hashable, Codable {
  case aas
  case gold
  case silver
  case bronze
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
    case .gold:
      return "G"
    case .silver:
      return "S"
    case .bronze:
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
    .bronze,
    .silver,
    .gold,
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
    .bronze,
    .silver,
    .gold,
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
    .bronze,
    .silver,
    .gold,
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
    .bronze,
    .silver,
    .gold,
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
    .bronze,
    .silver,
    .gold,
    .aas
  )
  private static let SevenAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .four, .five, .six,
    .seven, .ten
  )
  private static let EightAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .eight, .nine, .ten,
    .bronze, .silver, .gold, .aas
  )
  private static let NineAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .nine, .ten, .bronze,
    .silver, .gold, .aas
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
    .bronze,
    .silver,
    .gold,
    .aas
  )
  private static let bronzeAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .ten, .bronze, .silver,
    .gold, .aas
  )
  private static let silverAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .ten, .silver, .gold,
    .aas
  )
  private static let goldAfter: Set<Number> = Set(
    arrayLiteral: .two, .three, .ten, .gold, .aas
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
    case .bronze:
      return Number.bronzeAfter
    case .silver:
      return Number.silverAfter
    case .gold:
      return Number.goldAfter
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
    case .bronze:
      return 11
    case .silver:
      return 12
    case .gold:
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
