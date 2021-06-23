//
//  File.swift
//  
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
@testable import ShitheadenRuntime
import CustomAlgo
import XCTest

class GameTests: XCTestCase {
  func testNormalRunFourPlayers() async {
    let game = Game(players: [
                      Player(
                        name: "West (Unfair)",
                        position: .west,
                        ai: CardRankingAlgo()
                      ),
                    Player(
                      name: "Noord",
                      position: .noord,
                      ai: CardRankingAlgo()
                    ),
                    Player(
                      name: "Oost",
                      position: .oost,
                      ai: CardRankingAlgo()
                    ),
                      Player(
                        name: "Zuid",
                        position: .zuid,
                        ai: CardRankingAlgo()
                      )
                    ], slowMode: false)
    let snapshot = await game.startGame()
    XCTAssertNotNil(snapshot)
  }

  func testNormalRunTwoPlayers() async {
    let game = Game(players: [
      Player(
        name: "West (Unfair)",
        position: .west,
        ai: CardRankingAlgoWithUnfairPassing()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgo()
      )
    ], slowMode: false)
    let snapshot = await game.startGame()
    XCTAssertNotNil(snapshot)
  }
}
