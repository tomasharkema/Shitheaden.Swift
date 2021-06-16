//
//  MiscAi.swift
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

class RandomBot: PlayerMove {
  static let algoName = "RandomBot"

  required init() {}

  func move(player: Player, table: Table) -> Turn {
    let p = Array(player.possibleTurns(table: table))

    if p.isEmpty {
      return .pass
    } else {
      return p[Int.random(in: 0 ..< p.count)]
    }
  }
}
