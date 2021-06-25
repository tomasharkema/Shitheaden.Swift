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

  public func render(snapshot: GameSnapshot) async throws {
    try await old.render(snapshot: snapshot)
  }

  public func beginMove(request: TurnRequest) async -> (Card, Card, Card) {
    return await old.beginMove(request: request)
  }

  public func move(request: TurnRequest) async -> Turn {
    let turn = await old.move(request: request)

    if request.phase == .hand, request.deckCards.count > 3, request.tableCards.count < 6 {
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
