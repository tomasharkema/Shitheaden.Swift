//
//  Position.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

// TODO: x,y coords belong to CLI module

public struct Position: Equatable {
  public static let header = Position(x: 0, y: 0)
  public static let tafel = Position(x: 50, y: 10)
  public static let status = Position(x: 100, y: 10)
  public static let verliezer = Position(x: 50, y: 10)
  public static let input = Position(x: 0, y: 25)
  public static let debug = Position(x: 0, y: 40)

  public static let noord = Position(x: 50, y: 5)
  public static let oost = Position(x: 75, y: 10)
  public static let zuid = Position(x: 50, y: 15)
  public static let west = Position(x: 25, y: 10)

  public static let allCases: [Position] = [.noord, .oost, .zuid, .west]

  public static let hand = zuid.down(n: 5).right(n: -5)

  public let x: Int
  public let y: Int

  public func down(n: Int) -> Position {
    return Position(x: x, y: y + n)
  }

  public func right(n: Int) -> Position {
    return Position(x: x + n, y: y)
  }
}
