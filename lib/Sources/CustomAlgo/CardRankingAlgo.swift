//
//  CustomAlgo.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

public actor CardRankingAlgo: GameAi {
  private var passes = 0
  public required init() {}

  public func beginMove(request: TurnRequest,
                        previousError _: PlayerError?) async -> (Card, Card, Card)
  {
    let putOnTable = request.handCards.map {
      ($0, $0.number.importanceScore)
    }.sorted {
      $0.1 > $1.1
    }.map {
      $0.0
    }

    return (
      putOnTable.first!,
      putOnTable.dropFirst().first!,
      putOnTable.dropFirst().dropFirst().first!
    )
  }

  public func move(request: TurnRequest, previousError _: PlayerError?) async -> Turn {
    passes += 1
//    print("PASSES: ", passes)

    switch request.phase {
    case .hand, .tableOpen:
      let pt = request.possibleTurns()

      guard !pt.isEmpty else {
        return .pass
      }

      return pt.min { l, r in
        let leftScore = l.playedCards.first?.number.importanceScore ?? 10000
        let rightScore = r.playedCards.first?.number.importanceScore ?? 10000
        return leftScore < rightScore
      } ?? .pass

    case .tableClosed:
      return Turn.closedCardIndex(Int.random(in: 1 ... request.numberOfClosedTableCards))
    }
  }
}

extension Turn {
  var playedCards: [Card] {
    switch self {
//    case let .putOnTable(f, s, t):
//      return [f, s, t]
    case let .play(cards):
      return Array(cards)
    case .closedCardIndex, .pass:
      return []
    }
  }
}

extension Number {
  var importanceScore: Int {
    switch self {
    case .ten:
      return 1000
    case .three, .two:
      return 100
    case .seven:
      return 0

    default:
      return order
    }
  }
}
