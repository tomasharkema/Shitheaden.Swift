//
//  File.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

public actor CardRankingAlgoWithUnfairPassing: GameAi {
  private let old = CardRankingAlgo()
  public required init() {}

  public func render(snapshot: GameSnapshot, error: PlayerError?) async {
    await old.render(snapshot: snapshot, error: error)
  }

  public func beginMove(request: TurnRequest,
                        previousError: PlayerError?) async -> (Card, Card, Card)
  {
    return await old.beginMove(request: request, previousError: previousError)
  }

  public func move(request: TurnRequest, previousError: PlayerError?) async -> Turn {
    let turn = await old.move(request: request, previousError: previousError)

    if request.phase == .hand, request.amountOfDeckCards > 3, request.amountOfTableCards < 6 {
      let playThreeOrThen = turn.playedCards.map { $0.number }.contains {
        [.ten, .three].contains($0)
      }
      if playThreeOrThen {
        return .pass
      } else {
        return turn
      }
    }

    return turn
  }
}
