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
  func testNormalRunFourPlayers() {
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

    let expectation = XCTestExpectation(description: "Download apple.com home page")

    async {
      let snapshot = await game.startGame()
      XCTAssertNotNil(snapshot.winner)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 120.0)
  }

  func testNormalRunTwoPlayers() {
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

    let expectation = XCTestExpectation(description: "Download apple.com home page")

    async {
      let snapshot = await game.startGame()
      XCTAssertNotNil(snapshot.winner)
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 120.0)
  }
}
