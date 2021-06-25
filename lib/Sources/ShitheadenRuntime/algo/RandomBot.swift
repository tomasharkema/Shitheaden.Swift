//
//  File.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

public actor RandomBot: GameAi {
  public required init() {}

  public func render(snapshot _: GameSnapshot) async {}

  public func beginMove(request: TurnRequest) async -> (Card, Card, Card) {
    let hand = request.handCards.unobscure()

    let first = hand.randomElement()!
    let second = hand.filter { $0 != first }.randomElement()!
    let third = hand.filter { $0 != first && $0 != second }.randomElement()!

    return (first, second, third)
  }

  public func move(request: TurnRequest) async -> Turn {
    let possibleTurns = Array(request.privatePossibleTurns())
    if possibleTurns.isEmpty {
      return .pass
    } else {
      return possibleTurns[Int.random(in: 0 ..< possibleTurns.count)]
    }
  }
}
