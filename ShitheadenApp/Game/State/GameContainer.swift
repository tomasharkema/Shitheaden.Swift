//
//  GameContainer.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 18/06/2021.
//

import CustomAlgo
import Foundation
import Logging
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

@MainActor
final class GameContainer: ObservableObject {
  private let logger = Logger(label: "app.GameContainer")

  private var appInput: AppInputUserInputAI?
  private var game: Game?
  @Published var gameState = GameState()
  @Published var selectedCards = [RenderCard]()

  private(set) var beginMoveHandler: (((Card, Card, Card)) async throws -> Void)?
  private(set) var moveHandler: ((Turn) async throws -> Void)?

  func reset() async {
    appInput = nil
    game = nil
    await start()
  }

  var onDataId: UUID?
  var client: WebSocketClient?
  func startOnline(_ client: WebSocketClient, restart _: Bool) async {
    gameState = GameState()
    self.client = client
    client.data.removeOnDataHandler(id: onDataId)
    onDataId = client.data.on { ob in
      async {
        await MainActor.run {
          self.handleOnlineObject(ob, client: client)
        }
      }
    }
  }

  private func handleOnlineObject(_ ob: ServerEvent, client: WebSocketClient) {
    switch ob {
    case .requestMultiplayerChoice:
      logger.info("START ONLINE")

    case let .multiplayerEvent(multiplayerEvent):
      switch multiplayerEvent {
      case let .error(error):
        gameState.error = error.localizedDescription

      case .action(.requestBeginTurn):
        gameState.isOnTurn = true
        gameState.canPass = false

        moveHandler = nil
        beginMoveHandler = {
          self.logger.debug("\(String(describing: $0))")
          self.gameState.isOnTurn = false
          try await client.write(.multiplayerRequest(.concreteCards([$0.0, $0.1, $0.2])))
        }

      case .action(action: .requestNormalTurn):
        gameState.isOnTurn = true
        gameState.canPass = true

        beginMoveHandler = nil
        moveHandler = {
          self.logger.debug("\(String(describing: $0))")
          self.gameState.isOnTurn = false
          try await client.write(.multiplayerRequest(.concreteTurn($0)))
        }

      case let .string(string):
        logger.debug("\(string)")

      case let .gameSnapshot(snapshot):
        handle(snapshot: snapshot)
      }
    case let .error(error):
      gameState.error = error.localizedDescription
    default:
      logger.error("DERP \(String(describing: ob))")
    }
  }

  func handle(snapshot: GameSnapshot) {
    guard let localPlayer = snapshot.players.first(where: { !$0.isObscured }) else {
      return
    }

    var newState = gameState
    newState.gameSnapshot = snapshot
    newState.localPhase = localPlayer.phase
    if !localPlayer.handCards.isEmpty {
      newState.localCards = localPlayer.handCards.sortNumbers()
    } else if !localPlayer.openTableCards.isEmpty {
      newState.localCards = localPlayer.openTableCards.sortNumbers()
    } else {
      // closed cards!
      newState.localClosedCards = localPlayer.closedCards
      newState.localCards = []
    }

    newState.isOnTurn = snapshot.playersOnTurn.contains(localPlayer.id)

    newState.endState = snapshot.currentRequest?.endState

    switch localPlayer.phase {
    case .hand:
      newState.explain = "Speel een kaart uit je hand"
    case .tableOpen:
      newState.explain = "Speel een kaart van tafel"
    case .tableClosed:
      newState.explain = "Speel een kaart van je dichte stapel"
    }

    if gameState != newState {
      gameState = newState
    }
  }

  var gameTask: Task.Handle<GameSnapshot?, Never>?
  func start(restart: Bool = false) async {
    if restart {
      appInput = nil
      game = nil
      gameTask?.cancel()
      gameTask = nil
      beginMoveHandler = nil
      moveHandler = nil
    }

    guard appInput == nil, game == nil else {
      return
    }
    gameState = GameState()
    let id = UUID()
    let appInput = AppInputUserInputAI(
      beginMoveHandler: { handler in
        await MainActor.run {
          var newState = self.gameState
          newState.isOnTurn = true
          newState.canPass = false
          self.gameState = newState
          self.beginMoveHandler = handler
        }
      }, moveHandler: { handler in
        await MainActor.run {
          var newState = self.gameState
          newState.isOnTurn = true
          newState.canPass = true
          self.gameState = newState
          self.moveHandler = handler
        }
      }, errorHandler: { error in
        await MainActor.run {
          self.gameState.error = error
        }
      }, renderHandler: { game in
        self.handle(snapshot: game)
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
      Player(
        id: id,
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: appInput
      ),
    ], slowMode: true)
    self.game = game
    let gameTask: Task.Handle<GameSnapshot?, Never> = async {
      var snapshot: GameSnapshot?
      do {
        snapshot = try await game.startGame()
      } catch {
        self.logger.error("\(String(describing: error))")
      }
      self.logger.info("DONE! \(String(describing: snapshot))")
      return snapshot
    }
    self.gameTask = gameTask
    await gameTask.get()
  }

  func select(_ cards: [RenderCard], selected: Bool, deleteNotSameNumber: Bool) {
    if selected {
      if deleteNotSameNumber,
         selectedCards.contains(where: { $0.card?.number != cards.first?.card?.number })
      {
        selectedCards = cards
      } else {
        let cardIndex = max((selectedCards.count + cards.count) - 3, 0)
        logger.debug("items: \(selectedCards.count), \(cards.count), \(cardIndex)")

        selectedCards = Array(selectedCards.dropFirst(cardIndex))

        for card in cards {
          selectedCards.append(card)
        }
      }

    } else {
      for card in cards {
        if let cardIndex = selectedCards.firstIndex(of: card) {
          selectedCards.remove(at: cardIndex)
        }
      }
    }
  }

  func play() {
    async {
      if let beginMoveHandler = beginMoveHandler {
        guard selectedCards.count == 3 else {
          self.gameState.error = "Select drie kaarten!"
          return
        }
        self.gameState.error = nil
        try await beginMoveHandler((
          selectedCards.first!.card!,
          selectedCards.dropFirst().first!.card!,
          selectedCards.dropFirst().dropFirst().first!.card!
        ))
        self.gameState.isOnTurn = false
        self.beginMoveHandler = nil
      } else if let moveHandler = moveHandler {
        self.gameState.error = nil
        if selectedCards.count > 0 {
          try await moveHandler(.play(Set(selectedCards.map { $0.card! })))
        } else {
          try await moveHandler(.pass)
        }
        self.gameState.isOnTurn = false
        self.moveHandler = nil
      } else {
        return
      }
      selectedCards = []
    }
  }

  func playClosedCard(_ index: Int) {
    async {
      try await moveHandler?(.closedCardIndex(index + 1))
    }
  }

  func stop() async {
    logger.info("STOP game controller for client \(String(describing: client))")
    try? await client?.write(.quit)
  }
}
