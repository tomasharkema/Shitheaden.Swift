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
    case .hand:

      let actions = handCards.unobscure()
        .filter { h in lastTableCard?.number.afters.contains { $0 == h.number } ?? true }
        .map { Turn.play([$0]) }

      return Array([actions, [.pass]].joined()).includeDoubles()

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
