//
//  GameContainer.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 18/06/2021.
//

import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

actor AppInputUserInputAI: GameAi {
  let beginMoveHandler: (@escaping ((Card, Card, Card)) -> Void) -> Void
  let moveHandler: (@escaping (Turn) -> Void) -> Void
  let errorHandler: (String) -> Void

  required init() {
    beginMoveHandler = { _ in }
    moveHandler = { _ in }
    errorHandler = { _ in }
  }

  init(
    beginMoveHandler: @escaping (@escaping ((Card, Card, Card)) -> Void) -> Void,
    moveHandler: @escaping (@escaping (Turn) -> Void) -> Void,
    errorHandler: @escaping (String) -> Void
  ) {
    self.beginMoveHandler = beginMoveHandler
    self.moveHandler = moveHandler
    self.errorHandler = errorHandler
  }

  func beginMove(request _: TurnRequest, previousError: PlayerError?) async -> (Card, Card, Card) {
    if let e = previousError {
      errorHandler(e.text)
    }

    return await withUnsafeContinuation { g in
      beginMoveHandler {
        g.resume(returning: $0)
      }
    }
  }

  func move(request _: TurnRequest, previousError: PlayerError?) async -> Turn {
    if let e = previousError {
      errorHandler(e.text)
    }

    return await withUnsafeContinuation { g in
      moveHandler {
        g.resume(returning: $0)
      }
    }
  }
}

@MainActor
class GameContainer: ObservableObject {
  var appInput: AppInputUserInputAI?
  var game: Game?
  @Published var gameSnaphot: GameSnaphot?
  @Published var error: String?
  @Published var selectedCards = Set<Card>()
  @Published var localCards = [Card]()
  @Published var isOnSet = false
  @Published var canPass = false

  private(set) var beginMoveHandler: (((Card, Card, Card)) -> Void)?
  private(set) var moveHandler: ((Turn) -> Void)?

  func start() async {
    guard appInput == nil, game == nil else {
      return
    }

    let appInput = AppInputUserInputAI(beginMoveHandler: { h in
      async {await MainActor.run {
        self.isOnSet = true
        self.canPass = false
        self.beginMoveHandler = h
      }}
    }, moveHandler: { h in
      async {await MainActor.run {
        self.isOnSet = true
        self.canPass = true
        self.moveHandler = h
      }}
    }, errorHandler: {
      self.error = $0
    })
    self.appInput = appInput
    let game = Game(players: [
      Player(
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: appInput
      ),
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
      Player(
        name: "Oost",
        position: .oost,
        ai: CardRankingAlgo()
      ),
    ], slowMode: true, render: { game, _ in
      let localPlayer = game.players.first { $0.position == .zuid }!
      if !localPlayer.handCards.isEmpty {
        self.localCards = localPlayer.handCards.sortNumbers()
      } else if !localPlayer.openTableCards.isEmpty {
        self.localCards = localPlayer.openTableCards.sortNumbers()
      } else {
        // closed cards!
        self.localCards = []
      }

      self.gameSnaphot = game
    })
    self.game = game
    await game.startGame()
    print("DONE!")
  }

  func select(_ card: Card, selected: Bool, deleteNotSameNumber: Bool) {
    if selected {

      if deleteNotSameNumber, selectedCards.contains(where: {$0.number != card.number}) {
        selectedCards = [card]
      } else {
        selectedCards.insert(card)
      }

    } else {
      if let c = selectedCards.firstIndex(of: card) {
        selectedCards.remove(at: c)
      }
    }
  }

  func play() {
    if let beginMoveHandler = beginMoveHandler {
      guard selectedCards.count == 3 else {
        error = "Select drie kaarten!"
        return
      }

      beginMoveHandler((
        selectedCards.first!,
        selectedCards.dropFirst().first!,
        selectedCards.dropFirst().dropFirst().first!
      ))
      self.isOnSet = false
      self.beginMoveHandler = nil
    } else if let moveHandler = moveHandler {
      if selectedCards.count > 0 {
        moveHandler(Turn.play(Set(selectedCards)))
      } else {
        moveHandler(Turn.pass)
      }
      self.isOnSet = false
      self.moveHandler = nil
    } else {
      return
    }
    selectedCards = []
  }
}
