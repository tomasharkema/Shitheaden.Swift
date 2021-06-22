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
      return Array([actions, [.pass]].joined())

    case .tableOpen:
      let actions = handCards.unobscure()
        .filter { h in lastTableCard?.number.afters.contains { $0 == h.number } ?? true }
        .map { Turn.play([$0]) }
      if actions.isEmpty {
        return [Turn.pass]
      }
      return actions

    case .tableClosed:
      return closedCards.enumerated().map { Turn.closedCardIndex($0.offset + 1) }
    }
  }
}
