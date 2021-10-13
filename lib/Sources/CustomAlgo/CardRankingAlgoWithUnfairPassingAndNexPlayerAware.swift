//
//  CardRankingAlgoWithUnfairPassingAndNexPlayerAware.swift
//
//
//  Created by Tomas Harkema on 26/06/2021.
//

import Logging
import ShitheadenShared

public actor CardRankingAlgoWithUnfairPassingAndNexPlayerAware: GameAi {
  private let logger = Logger(label: "CardRankingAlgoWithUnfairPassingAndNexPlayerAware")
  private let old = CardRankingAlgoWithUnfairPassing()

  public static func make() -> GameAi {
    CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
  }

  public func render(snapshot: GameSnapshot) async throws {
    try await old.render(snapshot: snapshot)
  }

  public func beginMove(request: TurnRequest, snapshot: GameSnapshot) async -> (Card, Card, Card) {
    return await old.beginMove(request: request, snapshot: snapshot)
  }

  public func move(request: TurnRequest, snapshot: GameSnapshot) async -> Turn {
    let turn = await old.move(request: request, snapshot: snapshot)

    let notDonePlayers = snapshot.players.filter { !$0.done }

    if let ownIndex = notDonePlayers.firstIndex(where: { $0.id == request.id }) {
      let nextIndex = (ownIndex + 1) % notDonePlayers.count
      let nextPlayer = notDonePlayers[nextIndex]
      logger.info("ownIndex: \(ownIndex) \(nextIndex) \(nextPlayer.openTableCards)")

      if request.phase == .hand, nextPlayer.handCards.isEmpty {
        switch nextPlayer.phase {
        case .tableOpen:
          let nextPlayerOpenCards = nextPlayer.openTableCards.unobscure()

          logger.debug("nextPlayerOpenCards: \(nextPlayerOpenCards)")
          let possibleTurn = request.possibleTurns().max { turn1, turn2 in

            guard let turn1number = turn1.playedCards.first?.number,
                  let turn2number = turn2.playedCards.first?.number
            else {
              return false
            }

            let turn1count = nextPlayerOpenCards.filter { !turn1number.afters.contains($0.number) }
              .count
            let turn2count = nextPlayerOpenCards.filter { !turn2number.afters.contains($0.number) }
              .count

            return turn1count < turn2count
          }
          logger.debug("p: \(possibleTurn)")

          if let possibleTurn = possibleTurn {
            return possibleTurn
          }

        case .tableClosed:
          let highestTurn = request.possibleTurns().max { left, right in
            if let leftNumber = left.playedCards.first?.number,
               let rightNumber = right.playedCards.first?.number
            {
              return leftNumber < rightNumber
            }
            return false
          }

          if let highestTurn = highestTurn {
            return highestTurn
          }
        case .hand:
          break
        }
      }
    }

    return turn
  }
}
