//
//  CLI.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 19-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ShitheadenRuntime

enum CLI {
  static let Background = "44"
  static let TextColor = "39"

  static let ClearChar = "\u{1B}[2J"

  static let ShowCursor = "\\e[?25h"
  static let HideCursor = "\\e[?25h"

  static func clear() -> String {
    return ClearChar
  }

  static func setBackground() -> String { return "\u{1B}[\(CLI.TextColor);\(CLI.Background);m"
  }

//  static func print(pos: Position, string: String) {
//    if shouldPrintGlbl {
//      Swift.print("\u{001B}[\(CLI.TextColor);\(CLI.Background);m\(pos.cliRep)\(string)")
//    }
//  }
}

func >>> (lhs: Position, rhs: String) -> String {
//  CLI.print(pos: lhs, string: rhs)
  return "\u{001B}[\(CLI.TextColor);\(CLI.Background);m\(lhs.cliRep)\(rhs)"
}

func >>> (color: Color, string: String) -> String {
  return "\u{001B}[47;\(color.rawValue)m\(string)\u{001B}[\(CLI.TextColor);\(CLI.Background)m"
}

infix operator >>>

public extension Position {
  var cliRep: String {
    return "\u{1B}[\(y);\(x)H"
  }
}

extension String {
  func print() {
    Swift.print(self)
  }
}
