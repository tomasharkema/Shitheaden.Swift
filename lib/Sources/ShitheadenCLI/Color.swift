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
  case Red = "31"
  case Black = "30"
}

extension Symbol {
  var color: Color {
    switch self {
    case .klaver, .schoppen:
      return .Black
    case .ruiten, .harten:
      return .Red
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
    return (0 ..< closedCards.count).map { _ in "0" }.joined(separator: " ")
  }

  var closedTableShowed: String {
    return (0 ..< closedCards.count).map { $0.description }.joined(separator: " ")
  }
}

extension TurnRequest {
  var showedTable: String {
    return openTableCards.unobscure().map { $0.description }.joined(separator: " ")
  }
}

public extension Number {
  var ansi: String {
    switch self {
    case .gold:
      return ANSIEscapeCode.Decoration.textColor(.lightYellow) + "G"
    case .silver:
      return ANSIEscapeCode.Decoration.textColor(.lightWhite) + "S"
    case .bronze:
      return ANSIEscapeCode.Decoration.textColor(.lightRed) + "B"
    default:
      return string
    }
  }
}
