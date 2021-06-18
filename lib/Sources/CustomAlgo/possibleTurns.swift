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
//    case .putOnTable:
//
//      var turns = [Turn]()
//      for firstIteration in handCards {
//        for secondIteration in handCards.filter { $0 != firstIteration } {
//          for thirdIteration in handCards.filter { $0 != firstIteration && $0 != secondIteration } {
//            turns.append(Turn.putOnTable(firstIteration, secondIteration, thirdIteration))
//          }
//        }
//      }
//
//      return turns

    case .hand:
      let actions = handCards.filter { lastTableCard?.afters.contains($0) ?? true }
        .map { Turn.play([$0]) }
      return Array([actions, [.pass]].joined())

    case .tableOpen:
      let actions = openTableCards.filter { lastTableCard?.afters.contains($0) ?? true }
        .map { Turn.play([$0]) }
      if actions.isEmpty {
        return [Turn.pass]
      }
      return actions

    case .tableClosed:
      return (1 ... numberOfClosedTableCards).map { Turn.closedCardIndex($0) }
    }
  }
}
