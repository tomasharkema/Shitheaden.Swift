//
//  possibleTurns.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

extension TurnRequest {
  func possibleTurns() -> [Turn] {
    switch phase {
    case .hand:
      let actions = handCards.unobscure()
        .filter { handCard in
          lastTableCard?.number.afters.contains { $0 == handCard.number } ?? true
        }
        .map { Turn.play([$0]) }

      if actions.isEmpty {
        return [.pass]
      }

      return Array([actions, rules.contains(.unfairPassingAllowed) ? [.pass] : []].joined())
        .includeDoubles()

    case .tableOpen:
      let actions = openTableCards.unobscure()
        .filter { handCard in
          lastTableCard?.number.afters.contains { $0 == handCard.number } ?? true
        }
        .map { Turn.play([$0]) }
        .includeDoubles()

      if actions.isEmpty {
        if rules.contains(.getCardWhenPassOpenCardTables) {
          return openTableCards.unobscure()
            .map { Turn.play([$0]) }
            .includeDoubles()

        } else {
          return [Turn.pass]
        }
      }

      return actions.includeDoubles()

    case .tableClosed:
      return closedCards.enumerated().map { Turn.closedCardIndex($0.offset + 1) }.unique()
    }
  }
}
