//
//  File.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

public actor RandomBot: GameAi {
  public required init() {}

  public func render(snapshot: GameSnapshot, error: PlayerError?) async -> Void {}

  public func beginMove(request: TurnRequest,
                        previousError _: PlayerError?) async -> (Card, Card, Card)
  {
    let first = request.handCards.randomElement()!
    let second = request.handCards.filter { $0 != first }.randomElement()!
    let third = request.handCards.filter { $0 != first && $0 != second }.randomElement()!

    return (first, second, third)
  }

  public func move(request: TurnRequest, previousError _: PlayerError?) async -> Turn {
    let p = Array(request._possibleTurns())
    if p.isEmpty {
      return .pass
    } else {
      return p[Int.random(in: 0 ..< p.count)]
    }
  }
}
