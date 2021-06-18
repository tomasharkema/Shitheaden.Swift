//
//  RenderPosition.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

// TODO: x,y coords belong to CLI module

public struct RenderPosition: Equatable {
  public static let header = RenderPosition(x: 0, y: 0)
  public static let tafel = RenderPosition(x: 50, y: 10)
  public static let status = RenderPosition(x: 100, y: 10)
  public static let verliezer = RenderPosition(x: 50, y: 10)
  public static let input = RenderPosition(x: 0, y: 25)
  public static let debug = RenderPosition(x: 0, y: 40)

  public static let noord = RenderPosition(x: 50, y: 5)
  public static let oost = RenderPosition(x: 75, y: 10)
  public static let zuid = RenderPosition(x: 50, y: 15)
  public static let west = RenderPosition(x: 25, y: 10)

  public static let allCases: [RenderPosition] = [.noord, .oost, .zuid, .west]

  public static let hand = zuid.down(n: 5).right(n: -5)

  public let x: Int
  public let y: Int

  public func down(n: Int) -> RenderPosition {
    return RenderPosition(x: x, y: y + n)
  }

  public func right(n: Int) -> RenderPosition {
    return RenderPosition(x: x + n, y: y)
  }
}
