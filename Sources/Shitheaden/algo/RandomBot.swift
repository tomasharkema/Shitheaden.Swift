//
//  File.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

public actor RandomBot: GameAi {
  public required init() {}

  public func move(request: TurnRequest) async -> Turn {
    let p = Array(request.possibleTurns())
    if p.isEmpty {
      return .pass
    } else {
      return p[Int.random(in: 0 ..< p.count)]
    }
  }
}
