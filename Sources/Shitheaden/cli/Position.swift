//
//  Position.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

struct Position {
  static let header = Position(x: 0, y: 0)
  static let tafel = Position(x: 50, y: 10)
  static let status = Position(x: 100, y: 10)
  static let verliezer = Position(x: 50, y: 10)
  static let input = Position(x: 0, y: 25)
  static let debug = Position(x: 0, y: 40)

  static let noord = Position(x: 50, y: 5)
  static let oost = Position(x: 75, y: 10)
  static let zuid = Position(x: 50, y: 15)
  static let west = Position(x: 25, y: 10)

  static let allCases: [Position] = [.noord, .oost, .zuid, .west]

  static let hand = zuid.down(n: 5).right(n: -5)

  let x: Int
  let y: Int

  var cliRep: String {
    return "\u{1B}[\(y);\(x)H"
  }

  func down(n: Int) -> Position {
    return Position(x: x, y: y + n)
  }

  func right(n: Int) -> Position {
    return Position(x: x + n, y: y)
  }
}
