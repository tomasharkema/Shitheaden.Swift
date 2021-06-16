//
//  Number.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

enum Number: CaseIterable {
  case aas
  case heer
  case vrouw
  case boer
  case negen
  case acht
  case seven
  case zes
  case vijf
  case vier

  case ten
  case three
  case two

  static let specials: [Self] = [.ten, .three, .two]
  static let nonSpecials: [Self] = Number.allCases.filter { !specials.contains($0) }

  var string: String {
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
    case .negen:
      return "9"
    case .acht:
      return "8"
    case .seven:
      return "7"
    case .zes:
      return "6"
    case .vijf:
      return "5"
    case .vier:
      return "4"
    case .three:
      return "3"
    case .two:
      return "2"
    }
  }

  var afters: Set<Number> {
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
