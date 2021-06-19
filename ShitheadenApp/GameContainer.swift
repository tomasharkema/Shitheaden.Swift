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
  let beginMoveHandler: (@escaping ((Card, Card, Card)) async -> Void) async -> Void
  let moveHandler: (@escaping (Turn) async -> Void) async -> Void
  let errorHandler: (String) async -> Void

  required init() {
    beginMoveHandler = { _ in }
    moveHandler = { _ in }
    errorHandler = { _ in }
  }

  init(
    beginMoveHandler: @escaping (@escaping ((Card, Card, Card)) async -> Void) async -> Void,
    moveHandler: @escaping (@escaping (Turn) async -> Void) async -> Void,
    errorHandler: @escaping (String) async -> Void
  ) {
    self.beginMoveHandler = beginMoveHandler
    self.moveHandler = moveHandler
    self.errorHandler = errorHandler
  }

  func beginMove(request _: TurnRequest, previousError: PlayerError?) async -> (Card, Card, Card) {
    if let e = previousError {
      await errorHandler(e.text)
    }

    return await withUnsafeContinuation { g in
      async {
        await beginMoveHandler {
          g.resume(returning: $0)
        }
      }
    }
  }

  func move(request _: TurnRequest, previousError: PlayerError?) async -> Turn {
    if let e = previousError {
      await errorHandler(e.text)
    }

    return await withUnsafeContinuation { g in
      async {
        await moveHandler {
          g.resume(returning: $0)
        }
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
  @Published var localPhase: Phase?
  @Published var localCountOfClosedCards: Int?
  @Published var isOnSet = false
  @Published var canPass = false

  private(set) var beginMoveHandler: (((Card, Card, Card)) async -> Void)?
  private(set) var moveHandler: ((Turn) async -> Void)?

  func reset() async {
    appInput = nil
    game = nil
    await start()
  }

  func start() async {
    guard appInput == nil, game == nil else {
      return
    }
    let id = UUID()
    let appInput = AppInputUserInputAI(
      beginMoveHandler: { h in
        await MainActor.run {
          self.isOnSet = true
          self.canPass = false
          self.beginMoveHandler = h
        }
      }, moveHandler: { h in
        await MainActor.run {
          self.isOnSet = true
          self.canPass = true
          self.moveHandler = h
        }
      }, errorHandler: { e in
        await MainActor.run {
          self.error = e
        }
      }
    )
    self.appInput = appInput
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
      Player(
        name: "Oost",
        position: .oost,
        ai: CardRankingAlgo()
      ),
      Player(id: id,
             name: "Zuid (JIJ)",
             position: .zuid,
             ai: appInput),
    ], slowMode: true,
    localUserUUID: id, render: { game, _ in
      guard let localPlayer = game.players.compactMap({ $0.player }).first else {
        return
      }
      self.localPhase = localPlayer.phase
      if !localPlayer.handCards.isEmpty {
        self.localCards = localPlayer.handCards.sortNumbers()
      } else if !localPlayer.openTableCards.isEmpty {
        self.localCards = localPlayer.openTableCards.sortNumbers()
      } else {
        // closed cards!
        self.localCountOfClosedCards = localPlayer.numberOfClosedTableCards
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
      if deleteNotSameNumber, selectedCards.contains(where: { $0.number != card.number }) {
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

  func play() async {
    if let beginMoveHandler = beginMoveHandler {
      guard selectedCards.count == 3 else {
        error = "Select drie kaarten!"
        return
      }
      error = nil
      await beginMoveHandler((
        selectedCards.first!,
        selectedCards.dropFirst().first!,
        selectedCards.dropFirst().dropFirst().first!
      ))
      isOnSet = false
      self.beginMoveHandler = nil
    } else if let moveHandler = moveHandler {
      error = nil
      if selectedCards.count > 0 {
        await moveHandler(.play(Set(selectedCards)))
      } else {
        await moveHandler(.pass)
      }
      isOnSet = false
      self.moveHandler = nil
    } else {
      return
    }
    selectedCards = []
  }

  func playClosedCard(_ i: Int) async {
    await moveHandler?(.closedCardIndex(i + 1))
  }
}
