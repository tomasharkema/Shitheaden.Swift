//
//  GameContainer.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Combine
import CustomAlgo
import Foundation
import Logging
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

@MainActor
final class GameContainer: ObservableObject {
  private let id = UUID()

  private let logger = Logger(label: "app.GameContainer")

  private var appInput: AppInputUserInputAI?
  private var game: Game?
  @Published var gameState = GameState()
  @Published var selectedCards = [RenderCard]()

  private var contestants: Int?

  @Published var requestTurn: Bool = false
  @Published var beginMoveHandler: (Card, Card, Card)?
  @Published var moveHandler: Turn?

  func reset() async {
    appInput = nil
    game = nil
    await start(contestants: contestants ?? 3)
  }

  var onDataId: UUID?
  var client: WebSocketClient?
  func startOnline(_ client: WebSocketClient, restart: Bool) async {
    if restart {
      gameState = GameState()
    }
    self.client = client
  }

  private var beginMoveHandlerCancel: AnyCancellable?
  private var moveHandlerCancel: AnyCancellable?

  func handleOnlineObject(_ ob: ServerEvent, client: WebSocketClient) async {
    var newGameState = gameState
    switch ob {
    case .requestMultiplayerChoice:
      logger.info("START ONLINE")

    case let .multiplayerEvent(multiplayerEvent):
      switch multiplayerEvent {
      case let .error(error):
        newGameState.error = error.localizedDescription

      case .action(.requestBeginTurn):
        logger.info("requestBeginTurn isBeginMove true")
        newGameState.canPass = false
        newGameState.isBeginMove = true

        beginMoveHandlerCancel = $beginMoveHandler.filter { $0 != nil }.first().sink { cards in
          Task {
            do {
              self.logger.debug("\(String(describing: cards))")
              _ = try await client
                .write(.multiplayerRequest(.concreteCards([cards!.0, cards!.1, cards!.2])))
            } catch {
              self.logger.error("Error: \(error)")
            }
          }
        }

      case let .action(action: .requestNormalTurn(canPass)):
        logger.info("requestNormalTurn isBeginMove false")

        newGameState.canPass = canPass // refactor
        newGameState.isBeginMove = false

        moveHandlerCancel = $moveHandler.filter { $0 != nil }.first()
          .sink { turn in
            Task {
              do {
                self.logger.debug("\(String(describing: turn!))")
                _ = try await client.write(.multiplayerRequest(.concreteTurn(turn!)))
              } catch {
                self.logger.error("Error: \(error)")
              }
            }
          }

      case let .string(string):
        logger.debug("\(string)")

      case let .gameSnapshot(snapshot):
        newGameState = handle(snapshot: snapshot, gameState: newGameState)
      }
    case let .error(error):
      newGameState.error = error.localizedDescription
    default:
      logger.error("DERP \(String(describing: ob))")
    }

    if gameState != newGameState {
      gameState = newGameState
    }
  }

  private func handle(snapshot: GameSnapshot, gameState: GameState? = nil) -> GameState {
    guard let localPlayer = snapshot.players.first(where: { !$0.isObscured }) else {
      return gameState ?? self.gameState
    }
    var newGameState = gameState ?? self.gameState

    newGameState.gameSnapshot = snapshot
    newGameState.localPhase = localPlayer.phase
    if !localPlayer.handCards.isEmpty {
      newGameState.localCards = localPlayer.handCards // .sortNumbers()
    } else if !localPlayer.openTableCards.isEmpty {
      newGameState.localCards = localPlayer.openTableCards // .sortNumbers()
    } else {
      // closed cards!
      newGameState.localClosedCards = localPlayer.closedCards
      newGameState.localCards = []
    }

    newGameState.isOnTurn = snapshot.playersOnTurn.contains(localPlayer.id)

    newGameState.endState = snapshot.currentRequest?.endState

    switch localPlayer.phase {
    case .hand:
      newGameState.explain = "Speel een kaart uit je hand"
    case .tableOpen:
      newGameState.explain = "Speel een kaart van tafel"
    case .tableClosed:
      newGameState.explain = "Speel een kaart van je dichte stapel"
    }
    return newGameState
  }

  var gameTask: Task<EndGameSnapshot?, Never>?

  private func createAppInput() -> AppInputUserInputAI {
    AppInputUserInputAI(
      beginMoveHandler: { handler in

        self.beginMoveHandlerCancel = self.$beginMoveHandler.filter { $0 != nil }.first()
          .sink { cards in Task {
            await handler(cards!)

          }}

        await MainActor.run {
          var newState = self.gameState
          newState.canPass = false
          newState.isBeginMove = true
          self.gameState = newState
        }
      }, moveHandler: { canPass, handler in

        self.moveHandlerCancel = self.$moveHandler.filter { $0 != nil }.first().sink { turn in
          Task {
            await handler(turn!)
          }
        }

        await MainActor.run {
          var newState = self.gameState
          newState.canPass = canPass
          newState.isBeginMove = false
          self.gameState = newState
        }
      }, errorHandler: { error in
        await MainActor.run {
          self.gameState.error = error
        }
      }, renderHandler: { game in
        self.gameState = self.handle(snapshot: game)
      }
    )
  }

  func resume(snapshot: GameSnapshot) async {
    self.contestants = snapshot.players.count - 1
    gameState = GameState()
    let appInput = createAppInput()
    self.appInput = appInput

    let game = Game(
      snapshot: snapshot,
      localPlayerAi: createAppInput(),
      otherAi: CardRankingAlgoWithUnfairPassingAndNexPlayerAware.make()
    )

    self.game = game
    let gameTask: Task<EndGameSnapshot?, Never> = Task {
      var snap: EndGameSnapshot?
      do {
        let snapshot = try await game.resume()

        Task.detached(priority: .background) {
          do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
              .appendingPathComponent(
                "shitheaden"
              )
              .appendingPathComponent(
                "game-\(snapshot.gameId)-\(Int(snapshot.snapshot.beginDate))-\(snapshot.signature).json"
              )
            let data = try JSONEncoder().encode(snapshot)
            try data
              .write(to: url)

            var request = URLRequest(url: Host.host.appendingPathComponent("playedGame"))
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "content-type")

            let result = try await URLSession.shitheaden.upload(
              for: request,
                 from: data,
                 delegate: nil
            )

            let resultString = String(data: result.0, encoding: .utf8)

            self.logger.info("UPLOAD: \(result) \(String(describing: resultString))")
          } catch {
            self.logger.error("Error: \(error)")
          }
        }

        snap = snapshot
      } catch {
        self.logger.error("\(String(describing: error))")
      }
      self.logger.info("DONE! \(String(describing: snap))")
      return snap
    }
    self.gameTask = gameTask
    _ = await gameTask.value
  }

  func start(restart: Bool = false, contestants: Int) async {
    self.contestants = contestants
    if restart {
      appInput = nil
      game = nil
      gameTask?.cancel()
      gameTask = nil
    }

    guard appInput == nil, game == nil else {
      return
    }
    gameState = GameState()
    let appInput = createAppInput()
    self.appInput = appInput

    let game = Game(
      contestants: contestants,
      ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware.self,
      localPlayer: Player(
        id: id,
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: appInput
      ),
      rules: Storage.shared.rules,
      slowMode: true
    )

    self.game = game
    let gameTask: Task<EndGameSnapshot?, Never> = Task {
      var snap: EndGameSnapshot?
      do {
        let snapshot = try await game.startGame()

        Task.detached(priority: .background) {
          do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
              .appendingPathComponent(
                "shitheaden"
              )
              .appendingPathComponent(
                "game-\(snapshot.gameId)-\(Int(snapshot.snapshot.beginDate))-\(snapshot.signature).json"
              )
            let data = try JSONEncoder().encode(snapshot)
            try data
              .write(to: url)

            var request = URLRequest(url: Host.host.appendingPathComponent("playedGame"))
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "content-type")

            let result = try await URLSession.shitheaden.upload(
              for: request,
              from: data,
              delegate: nil
            )

            let resultString = String(data: result.0, encoding: .utf8)

            self.logger.info("UPLOAD: \(result) \(String(describing: resultString))")
          } catch {
            self.logger.error("Error: \(error)")
          }
        }

        snap = snapshot
      } catch {
        self.logger.error("\(String(describing: error))")
      }
      self.logger.info("DONE! \(String(describing: snap))")
      return snap
    }
    self.gameTask = gameTask
    _ = await gameTask.value
  }

  func select(_ cards: [RenderCard], selected: Bool) {
    let deleteNotSameNumber = !gameState.isBeginMove
    logger.info("deleteNotSameNumber: \(deleteNotSameNumber) \(gameState)")

    if selected {
      if deleteNotSameNumber,
         selectedCards.contains(where: { $0.card?.number != cards.first?.card?.number })
      {
        selectedCards = cards
      } else {
        var newSelectedCards = selectedCards
        let cardIndex = max((newSelectedCards.count + cards.count) - 3, 0)
        logger.debug("items: \(newSelectedCards.count), \(cards.count), \(cardIndex)")

        newSelectedCards = Array(newSelectedCards.dropFirst(cardIndex))

        for card in cards {
          newSelectedCards.append(card)
        }

        selectedCards = newSelectedCards
      }

    } else {
      var newSelectedCards = selectedCards
      for card in cards {
        if let cardIndex = selectedCards.firstIndex(of: card) {
          newSelectedCards.remove(at: cardIndex)
        }
      }

      selectedCards = newSelectedCards
    }
  }

  func play() {
    Task {
      if gameState.isBeginMove {
        guard selectedCards.count == 3 else {
          self.gameState.error = "Select drie kaarten!"
          return
        }
        self.gameState.error = nil
        beginMoveHandler = (
          selectedCards.first!.card!,
          selectedCards.dropFirst().first!.card!,
          selectedCards.dropFirst().dropFirst().first!.card!
        )
        beginMoveHandler = nil
      } else {
        self.gameState.error = nil
        if selectedCards.count > 0 {
          moveHandler = .play(Set(selectedCards.map { $0.card! }))
        } else {
          moveHandler = .pass
        }
        moveHandler = nil
      }
      selectedCards = []
    }
  }

  func playClosedCard(_ index: Int) {
    guard gameState.isOnTurn else {
      return
    }

    moveHandler = .closedCardIndex(index + 1)
    moveHandler = nil
  }

  func stop() async {
    logger.info("STOP game controller for client \(String(describing: client))")
    _ = try? await client?.write(.quit(from: id))
  }

  func restart() async {
    if let client = client {
      await startOnline(client, restart: true)
    } else if let contestants = contestants {
      await start(restart: true, contestants: contestants)
    }
  }
}
