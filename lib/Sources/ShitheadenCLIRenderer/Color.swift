//
//  Color.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 19-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ANSIEscapeCode
import ShitheadenRuntime
import ShitheadenShared

enum Color: String {
  case red = "31"
  case black = "30"
}

extension Symbol {
  var color: Color {
    switch self {
    case .klaver, .schoppen:
      return .black
    case .ruiten, .harten:
      return .red
    }
  }
}

extension Card: CustomStringConvertible {
  public var description: String {
    let color = symbol.color

    return color >>> "\(symbol.string)\(number.ansi)"
  }
}

extension TurnRequest {
  var closedTable: String {
    (0 ..< closedCards.count).map { _ in "0" }.joined(separator: " ")
  }

  var closedTableShowed: String {
    (0 ..< closedCards.count).map(\.description).joined(separator: " ")
  }
}

extension TurnRequest {
  var showedTable: String {
    openTableCards.unobscure().map(\.description).joined(separator: " ")
  }
}

public extension Number {
  var ansi: String {
//    switch self {
//    case .gold:
//      return ANSIEscapeCode.Decoration.textColor(.lightYellow) + "G"
//    case .silver:
//      return ANSIEscapeCode.Decoration.textColor(.lightWhite) + "S"
//    case .bronze:
//      return ANSIEscapeCode.Decoration.textColor(.lightRed) + "B"
//    default:
    string
//    }
  }
}
