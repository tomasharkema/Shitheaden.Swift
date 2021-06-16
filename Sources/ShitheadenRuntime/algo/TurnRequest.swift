//
//  TurnRequest.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 31-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//
//
// class WisselBot: PlayerMove {
//
//  static let algoName = "WisselBot"
//
//  required init() {}
//
//  func move(speler: Speler, tafel: Tafel) -> Beurt {
//    return .Wissel
//  }
// }
//
// class PassBot: PlayerMove {
//
//  static let algoName = "PassBot"
//
//  required init() {}
//
//  func move(speler: Speler, tafel: Tafel) -> Beurt {
//    return .Pass
//  }
// }
//

import ShitheadenShared

extension TurnRequest {
  #if DEBUG
    public func possibleTurns() -> [Turn] {
      return _possibleTurns()
    }
  #endif

  func _possibleTurns() -> [Turn] {
    switch phase {
//    case .putOnTable:
//
//      var turns = [Turn]()
//      for firstIteration in handCards {
//        for secondIteration in handCards.filter({ $0 != firstIteration }) {
//          for thirdIteration in handCards
//            .filter({ $0 != firstIteration && $0 != secondIteration })
//          {
//            turns.append(Turn.putOnTable(firstIteration, secondIteration, thirdIteration))
//          }
//        }
//      }
//
//      return turns.unique()

    case .hand:
      let actions = handCards.filter { lastTableCard?.afters.contains($0) ?? true }
        .map { Turn.play([$0]) }
      let e = Array([actions, [.pass]].joined()).includeDoubles() // .unique()
//      if e.doubles() {
//        fatalError()
//      }
      return e

    case .tableOpen:
      let actions = openTableCards.filter { lastTableCard?.afters.contains($0) ?? true }
        .map { Turn.play([$0]) }
      if actions.isEmpty {
        return [Turn.pass]
      }
      return actions.includeDoubles()

    case .tableClosed:
      return (1 ... numberOfClosedTableCards).map { Turn.closedCardIndex($0) }.unique()
    }
  }
}
