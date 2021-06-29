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

  public func render(snapshot _: GameSnapshot) async throws {}

  public func beginMove(
    request: TurnRequest,
    snapshot _: GameSnapshot
  ) async -> (Card, Card, Card) {
    let putOnTable = request.handCards.unobscure().map {
      ($0, $0.number.importanceScore)
    }.sorted {
      $0.1 > $1.1
    }.map(\.0)

    return (
      putOnTable.first!,
      putOnTable.dropFirst().first!,
      putOnTable.dropFirst().dropFirst().first!
    )
  }

  public func move(
    request: TurnRequest, snapshot _: GameSnapshot
  ) async -> Turn {
    passes += 1

    switch request.phase {
    case .hand, .tableOpen:
      let possibleTurns = request.possibleTurns()

      guard !possibleTurns.isEmpty else {
        return .pass
      }

      guard let leastImportantTurn = possibleTurns.min(by: { left, right in
        guard let leftCard = left.playedCards.first,
              let rightScore = right.playedCards.first?.number.importanceScore
        else {
          return 10000 < 10000
        }

        let leftScore = leftCard.number.importanceScore

        if leftScore == rightScore, request.deckCards.count < 3 || leftCard.number < .nine {
          return left.playedCards.count > right.playedCards.count
        }

        return leftScore < rightScore
      }) else {
        return .pass
      }

      return leastImportantTurn

    case .tableClosed:
      return Turn.closedCardIndex(Int.random(in: 1 ... request.closedCards.count))
    }
  }
}

extension Turn {
  var playedCards: [Card] {
    switch self {
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
