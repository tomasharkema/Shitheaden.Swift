//
//  RenderPosition.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

// TODO: x,y coords belong to CLI module

public struct RenderPosition: Equatable {
  public static let header = RenderPosition(xAxis: 0, yAxis: 0)
  public static let tafel = RenderPosition(xAxis: 50, yAxis: 10)
  public static let status = RenderPosition(xAxis: 100, yAxis: 10)
  public static let verliezer = RenderPosition(xAxis: 50, yAxis: 10)
  public static let input = RenderPosition(xAxis: 0, yAxis: 25)
  public static let debug = RenderPosition(xAxis: 0, yAxis: 40)

  public static let noord = RenderPosition(xAxis: 50, yAxis: 5)
  public static let oost = RenderPosition(xAxis: 75, yAxis: 10)
  public static let zuid = RenderPosition(xAxis: 50, yAxis: 15)
  public static let west = RenderPosition(xAxis: 25, yAxis: 10)

  public static let allCases: [RenderPosition] = [.noord, .oost, .zuid, .west]

  public static let hand = input.down(yAxisDown: -3)

  public let xAxis: Int
  public let yAxis: Int

  public func down(yAxisDown: Int) -> RenderPosition {
    RenderPosition(xAxis: xAxis, yAxis: yAxis + yAxisDown)
  }

  public func right(xAxisAside: Int) -> RenderPosition {
    RenderPosition(xAxis: xAxis + xAxisAside, yAxis: yAxis)
  }
}
