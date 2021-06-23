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
        .filter { h in lastTableCard?.number.afters.contains { $0 == h.number } ?? true }
        .map { Turn.play([$0]) }
      print(actions)
      let e = Array([actions, [.pass]].joined()).includeDoubles()
      return e

    case .tableOpen:
      let actions = openTableCards.unobscure()
        .filter { h in lastTableCard?.number.afters.contains { $0 == h.number } ?? true }
        .map { Turn.play([$0]) }
      if actions.isEmpty {
        return [Turn.pass]
      }
      return actions.includeDoubles()

    case .tableClosed:
      return closedCards.enumerated().map { Turn.closedCardIndex($0.offset + 1) }.unique()
    }
  }
}
