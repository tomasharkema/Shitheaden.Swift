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

@MainActor
class GameContainer: ObservableObject {
  private var appInput: AppInputUserInputAI?
  private var game: Game?
  @Published var gameState: GameState = GameState()
  @Published var selectedCards = Set<RenderCard>()

  private(set) var beginMoveHandler: (((Card, Card, Card)) async throws -> Void)?
  private(set) var moveHandler: ((Turn) async throws -> Void)?

  func reset() async {
    appInput = nil
    game = nil
    await start()
  }

  var onDataId: UUID?
  var client: WebSocketClient?
  func startOnline(_ client: WebSocketClient, restart: Bool) async {
    self.gameState = GameState()
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
      print("START ONLINE")

    case let .multiplayerEvent(multiplayerEvent):
      switch multiplayerEvent {
      case let .error(error):
        self.gameState.error = error.localizedDescription

      case .action(.requestBeginTurn):
        self.gameState.isOnTurn = true
        self.gameState.canPass = false

        moveHandler = nil
        beginMoveHandler = {
          print($0)
          self.gameState.isOnTurn = false
          try await client.write(.multiplayerRequest(.concreteCards([$0.0, $0.1, $0.2])))
        }

      case .action(action: .requestNormalTurn):
        self.gameState.isOnTurn = true
        self.gameState.canPass = true

        beginMoveHandler = nil
        moveHandler = {
          print($0)
          self.gameState.isOnTurn = false
          try await client.write(.multiplayerRequest(.concreteTurn($0)))
        }

      case let .string(string):
        print(string)

      case let .gameSnapshot(snapshot):
        handle(snapshot: snapshot)
      }
    case let .error(error):
      self.gameState.error = error.localizedDescription
    default:
      print("DERP \(ob)")
    }
  }

  func handle(snapshot: GameSnapshot) {
    guard let localPlayer = snapshot.players.first(where: { !$0.isObscured }) else {
      return
    }

    var newState = self.gameState
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

    if self.gameState != newState {
      self.gameState = newState
    }
  }

  var gameTask: Task.Handle<GameSnapshot?, Never>?
  func start(restart: Bool = false) async {

    if restart {
      appInput = nil
      game = nil
      gameTask?.cancel()
      gameTask = nil
    }

    guard appInput == nil, game == nil else {
      return
    }
    self.gameState = GameState()
    let id = UUID()
    let appInput = AppInputUserInputAI(
      beginMoveHandler: { h in
        await MainActor.run {
          var newState = self.gameState
          newState.isOnTurn = true
          newState.canPass = false
          self.gameState = newState
          self.beginMoveHandler = h
        }
      }, moveHandler: { h in
        await MainActor.run {
          var newState = self.gameState
          newState.isOnTurn = true
          newState.canPass = true
          self.gameState = newState
          self.moveHandler = h
        }
      }, errorHandler: { e in
        await MainActor.run {
          self.gameState.error = e
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
        print(error)
      }
      print("DONE!", snapshot)
      return snapshot
    }
    self.gameTask = gameTask
    await gameTask.get()
  }

  func select(_ cards: Set<RenderCard>, selected: Bool, deleteNotSameNumber: Bool) {
    if selected {
      if deleteNotSameNumber,
         selectedCards.contains(where: { $0.card?.number != cards.first?.card?.number })
      {
        selectedCards = cards
      } else {
        for card in cards {
          selectedCards.insert(card)
        }
      }

    } else {
      for card in cards {
        if let c = selectedCards.firstIndex(of: card) {
          selectedCards.remove(at: c)
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

  func playClosedCard(_ i: Int) {
    async {
      try await moveHandler?(.closedCardIndex(i + 1))
    }
  }

  func stop() async {
    print("STOP!", client)
    try? await client?.write(.quit)
  }
}
