//
//  MultiplayerHandler.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import Foundation
import ShitheadenRuntime
import ShitheadenShared
import Logging

protocol Client: AnyObject {
  var quit: EventHandler<Void>.ReadOnly { get }
  var data: EventHandler<ServerRequest>.ReadOnly { get }

  func send(_ event: ServerEvent) async
}

actor MultiplayerHandler {
  private let logger = Logger(label: "cli.MultiplayerHandler")
  var challenger: (UUID, Client)
  let code: String
  var competitors: [(UUID, Client)]
  private var gameTask: Task<GameSnapshot, Error>?
  private let finishEvent = EventHandler<Result<GameSnapshot, Error>>()
  public var finish: EventHandler<Result<GameSnapshot, Error>>.ReadOnly { finishEvent.readOnly }

  init(challenger: (UUID, Client)) {
    self.challenger = challenger
    code = UUID().uuidString.prefix(5).lowercased()
    competitors = []

    challenger.1.quit.on {
      self.logger.info("onQuitRead, challenger \(challenger) \(self.gameTask) \(self.finishEvent)")
      self.gameTask?.cancel()

      self.competitors.forEach { c in
        async {
          await c.1.send(.quit)
        }
      }
    }
    competitors.forEach { d in
      d.1.quit.on {
        self.logger.info("onQuitRead, \(d) \(self.gameTask) \(self.finishEvent)")
        self.gameTask?.cancel()
        async {
          await challenger.1.send(.quit)
        }
        self.competitors.filter { $0.0 != d.0 }.forEach { c in
          async {
            await c.1.send(.quit)
          }
        }
      }
    }
  }

  nonisolated func send(_ event: ServerEvent) async {
    await challenger.1.send(event)
    for s in await competitors {
      await s.1.send(event)
    }
  }

  func appendCompetitor(id: UUID, client: Client) {
    competitors.append((id, client))
  }

  nonisolated func join(id: UUID, client: Client) async {
    await appendCompetitor(id: id, client: client)

    await client.send(.waiting)
    await send(.joined(numberOfPlayers: 1 + competitors.count))
  }

  nonisolated func waitForStart() async throws {
    await challenger.1.send(.codeCreate(code: code))

    let r = try await challenger.1.data.once()
    guard case let .multiplayerRequest(read) = r, let string = read.string,
          string.contains("start")
    else {
      return try await waitForStart()
    }

    await send(.start)

    let game = try await startMultiplayerGame()
    self.logger.info("start multiplayer game \(game)")
  }

  nonisolated func finished() async throws -> Result<GameSnapshot, Error> {
    return try await finishEvent.once()
  }

  private func startMultiplayerGame() async throws -> GameSnapshot {
    _ = challenger.1.quit.on {
      await self.send(.quit)
    }

    for player in competitors {
      _ = player.1.quit.on {
        await self.send(.quit)
      }
    }

    let initiatorAi = UserInputAIJson(id: challenger.0) { request, error in
      if let error = error {
        await self.challenger.1.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
      }
      await self.challenger.1.send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
      return try await self.challenger.1.data.once().getMultiplayerRequest()
    } renderHandler: { game in
      _ = await self.challenger.1
        .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
    }

    let initiator = Player(
      id: challenger.0,
      name: String(challenger.0.uuidString.prefix(5).prefix(5)),
      position: .noord,
      ai: initiatorAi
    )

    let joiners = competitors.prefix(3).enumerated().map { index, player in
      Player(
        id: player.0,
        name: String(player.0.uuidString.prefix(5)),
        position: Position.allCases[index + 1],
        ai: UserInputAIJson(id: player.0) { request, error in
          if let error = error {
            await player.1.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
          }
          await player.1.send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
          return try await player.1.data.once().getMultiplayerRequest()
        } renderHandler: { game in
          _ = await player.1
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
        }
      )
    }

    let game = Game(
      players: [initiator] + joiners, slowMode: true
    )
    let gameTask: Task<GameSnapshot, Error> = async {
      do {
        let result = try await game.startGame()
        finishEvent.emit(.success(result))
        return result
      } catch {
        finishEvent.emit(.failure(error))
        throw error
      }
    }

    self.gameTask = gameTask

    return try await withTaskCancellationHandler(operation: {
      try await gameTask.get()
    }, onCancel: {
      self.logger.info("CANCEL!")
      assertionFailure("SHOULD BEHANDLED")
//      promise.resolve()
    })
  }
}
