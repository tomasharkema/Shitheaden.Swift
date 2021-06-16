//
//  CLI.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 19-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Shitheaden

enum CLI {
  static let Background = "44"
  static let TextColor = "39"

  static let ClearChar = "\u{1B}[2J"
  static var shouldPrintGlbl = true

  static func clear() {
    if shouldPrintGlbl { Swift.print(ClearChar) }
  }

  static func setBackground() {
    if shouldPrintGlbl { Swift.print("\u{1B}[\(CLI.TextColor);\(CLI.Background);m") }
  }

  static func print(pos: Position, string: String) {
    if shouldPrintGlbl {
      Swift.print("\u{001B}[\(CLI.TextColor);\(CLI.Background);m\(pos.cliRep)\(string)")
    }
  }
}

func >>> (lhs: Position, rhs: String) {
  CLI.print(pos: lhs, string: rhs)
}

func >>> (color: Color, string: String) -> String {
  return "\u{001B}[47;\(color.rawValue)m\(string)\u{001B}[\(CLI.TextColor);\(CLI.Background)m"
}

infix operator >>>

extension Position {
  public var cliRep: String {
    return "\u{1B}[\(y);\(x)H"
  }
}


extension String {
  func print() {
    Swift.print(self)
  }
}
