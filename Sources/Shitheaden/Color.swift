//
//  Color.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 19-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

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

    return color >>> "\(symbol.string)\(number.string)"
  }
}

extension Player {
  var showedTable: String {
    return openTableCards.map { $0.description }.joined(separator: " ")
  }

  var closedTable: String {
    return closedTableCards.map { _ in "0" }.joined(separator: " ")
  }

  var closedTableShowed: String {
    return closedTableCards.map { $0.description }.joined(separator: " ")
  }
}
