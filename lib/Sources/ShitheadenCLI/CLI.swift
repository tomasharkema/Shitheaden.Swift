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
    ClearChar
  }

  static func setBackground() -> String { "\u{1B}[\(CLI.TextColor);\(CLI.Background);m"
  }
}

func >>> (lhs: RenderPosition, rhs: String) -> String {
  "\u{001B}[\(CLI.TextColor);\(CLI.Background);m\(lhs.cliRep)\(rhs)"
}

func >>> (color: Color, string: String) -> String {
  "\u{001B}[47;\(color.rawValue)m\(string)\u{001B}[\(CLI.TextColor);\(CLI.Background)m"
}

infix operator >>>

public extension RenderPosition {
  var cliRep: String {
    "\u{1B}[\(yAxis);\(xAxis)H"
  }
}
