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
  @Published var gameSnapshot: GameSnapshot?
  @Published var error: String?
  @Published var selectedCards = Set<RenderCard>()
  @Published var localCards = [RenderCard]()
  @Published var localPhase: Phase?
  @Published var localClosedCards = [RenderCard]()
  @Published var isOnTurn = false
  @Published var canPass = false

  private(set) var beginMoveHandler: (((Card, Card, Card)) async -> Void)?
  private(set) var moveHandler: ((Turn) async -> Void)?

  func reset() async {
    appInput = nil
    game = nil
    await start()
  }

  var onDataId: UUID?
  func startOnline(_ handler: WebSocketHandler) async {
    await handler.data.removeOnDataHandler(id: onDataId)
    onDataId = await handler.data.on { ob in
      async {
        await MainActor.run {
          self.handleOnlineObject(ob, handler: handler)
        }
      }
    }
  }

  private func handleOnlineObject(_ ob: ServerEvent, handler: WebSocketHandler) {
    switch ob {
    case .requestMultiplayerChoice:
      print("START ONLINE")

    case let .multiplayerEvent(multiplayerEvent):
      switch multiplayerEvent {
      case let .error(error):
        self.error = error.localizedDescription

      case .action(.requestBeginTurn):
        isOnTurn = true
        canPass = false

        moveHandler = nil
        beginMoveHandler = {
          print($0)
          self.isOnTurn = false
          await handler.write(.multiplayerRequest(.concreteCards([$0.0, $0.1, $0.2])))
        }

      case .action(action: .requestNormalTurn):
        isOnTurn = true
        canPass = true

        beginMoveHandler = nil
        moveHandler = {
          print($0)
          self.isOnTurn = false
          await handler.write(.multiplayerRequest(.concreteTurn($0)))
        }

      case let .string(string):
        print(string)

      case let .gameSnapshot(snapshot):
        handle(snapshot: snapshot)
      }
    case .error(let error):
      self.error = error.localizedDescription
    default:
      print("DERP \(ob)")
    }
  }

  func handle(snapshot: GameSnapshot) {
    guard let localPlayer = snapshot.players.first(where: { !$0.isObscured }) else {
      return
    }
    localPhase = localPlayer.phase
    if !localPlayer.handCards.isEmpty {
      localCards = localPlayer.handCards.sortNumbers()
    } else if !localPlayer.openTableCards.isEmpty {
      localCards = localPlayer.openTableCards.sortNumbers()
    } else {
      // closed cards!
      localClosedCards = localPlayer.closedCards
      localCards = []
    }

    isOnTurn = snapshot.playersOnTurn.contains(localPlayer.id)

    gameSnapshot = snapshot
  }

  func start() async {
    guard appInput == nil, game == nil else {
      return
    }
    let id = UUID()
    let appInput = AppInputUserInputAI(
      beginMoveHandler: { h in
        await MainActor.run {
          self.isOnTurn = true
          self.canPass = false
          self.beginMoveHandler = h
        }
      }, moveHandler: { h in
        await MainActor.run {
          self.isOnTurn = true
          self.canPass = true
          self.moveHandler = h
        }
      }, errorHandler: { e in
        await MainActor.run {
          self.error = e
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
    await game.startGame()
    print("DONE!")
  }

  func select(_ card: RenderCard, selected: Bool, deleteNotSameNumber: Bool) {
    if selected {
      if deleteNotSameNumber,
         selectedCards.contains(where: { $0.card?.number != card.card?.number })
      {
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
    async {
      if let beginMoveHandler = beginMoveHandler {
        guard selectedCards.count == 3 else {
          error = "Select drie kaarten!"
          return
        }
        error = nil
        await beginMoveHandler((
          selectedCards.first!.card!,
          selectedCards.dropFirst().first!.card!,
          selectedCards.dropFirst().dropFirst().first!.card!
        ))
        isOnTurn = false
        self.beginMoveHandler = nil
      } else if let moveHandler = moveHandler {
        error = nil
        if selectedCards.count > 0 {
          await moveHandler(.play(Set(selectedCards.map { $0.card! })))
        } else {
          await moveHandler(.pass)
        }
        isOnTurn = false
        self.moveHandler = nil
      } else {
        return
      }
      selectedCards = []
    }
  }

  func playClosedCard(_ i: Int) {
    async {
      await moveHandler?(.closedCardIndex(i + 1))
    }
  }

  func stop() {
    print("STOP!")
  }
}
