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

  public func move(request: TurnRequest) async -> Turn {
    passes += 1
//    print("PASSES: ", passes)

    switch request.phase {
    case .putOnTable:

      let putOnTable = request.handCards.map {
        ($0, $0.number.importanceScore)
      }.sorted {
        $0.1 > $1.1
      }.map {
        $0.0
      }
      
      return .putOnTable(
        putOnTable.first!,
        putOnTable.dropFirst().first!,
        putOnTable.dropFirst().dropFirst().first!
      )

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
    case let .putOnTable(f, s, t):
      return [f, s, t]
    case let .play(cards):
      return Array(cards)
    case .closedCardIndex, .pass:
      return []
    }
  }
}

extension Number {
  var rank: Int {
    switch self {
    case .aas:
      return 14
    case .heer:
      return 13
    case .vrouw:
      return 12
    case .boer:
      return 11
    case .ten:
      return 10
    case .negen:
      return 9
    case .acht:
      return 8
    case .seven:
      return 7
    case .zes:
      return 6
    case .vijf:
      return 5
    case .vier:
      return 4
    case .three:
      return 3
    case .two:
      return 2
    }
  }

  var importanceScore: Int {
    switch self {
    case .ten:
      return 1000
    case .three, .two:
      return 100
    case .seven:
      return 0

    default:
      return rank
    }
  }
}
