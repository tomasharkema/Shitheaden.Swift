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
      privatePossibleTurns()
    }
  #endif

  func privatePossibleTurns() -> [Turn] {
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
