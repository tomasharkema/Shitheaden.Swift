//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import CustomAlgo
import Foundation
@testable import ShitheadenRuntime
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
      ),
    ], slowMode: false)

    let expectation = XCTestExpectation(description: "wait for game play")

    if #available(macOS 12.0, *) {
      async {
        do {
          let snapshot = try await game.startGame()
          XCTAssertNotNil(snapshot.winner)
        } catch {
          print(error)
          XCTFail("ERROR! \(error)")
        }
        expectation.fulfill()
      }
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
      ),
    ], slowMode: false)

    let expectation = XCTestExpectation(description: "wait for game play")

    if #available(macOS 12.0, *) {
      async {
        do {
          let snapshot = try await game.startGame()
          XCTAssertNotNil(snapshot.winner)
        } catch {
          print(error)
          XCTFail("ERROR! \(error)")
        }
        expectation.fulfill()
      }
    }
    wait(for: [expectation], timeout: 120.0)
  }
}
