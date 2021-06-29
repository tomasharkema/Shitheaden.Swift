//
//  MultiplayerHandler.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import Foundation
import Logging
import ShitheadenCLIRenderer
import ShitheadenRuntime
import ShitheadenShared

protocol Client: AnyObject {
  var quit: EventHandler<Void>.ReadOnly { get }
  var data: EventHandler<ServerRequest>.ReadOnly { get }

  func send(_ event: ServerEvent) async throws
}

actor MultiplayerHandler {
  private let logger = Logger(label: "cli.MultiplayerHandler")
  var challenger: (UUID, Client)
  let code: String
  var competitors: [(UUID, Client)]
  private var gameTask: Task<GameSnapshot, Error>?
  private let finishEvent = EventHandler<Result<Void, Error>>()
  public var finish: EventHandler<Result<Void, Error>>.ReadOnly { finishEvent.readOnly }

  init(challenger: (UUID, Client)) {
    self.challenger = challenger
    code = UUID().uuidString.prefix(5).lowercased()
    competitors = []
  }

  nonisolated func start() async {
    await challenger.1.quit.on { [weak self] in
      guard let self = self else {
        return
      }
      self.logger.info("onQuitRead")

      asyncDetached {
        await self.competitors.forEach { competitor in
          asyncDetached {
            try await competitor.1.send(.quit)
          }
        }
      }

      self.finishEvent.emit(.success(()))
      await self.gameTask?.cancel()
    }
    await competitors.forEach { competitor in
      competitor.1.quit.on { [weak self] in
        guard let self = self else {
          return
        }
        asyncDetached {
          let challenger = await self.challenger
          try await challenger.1.send(.quit)
          await self.competitors.filter { $0.0 != competitor.0 }.forEach { competitor in
            asyncDetached {
              try await competitor.1.send(.quit)
            }
          }
        }

        self.finishEvent.emit(.success(()))
        await self.gameTask?.cancel()
      }
    }
  }

  nonisolated func send(_ event: ServerEvent) async throws {
    try await challenger.1.send(event)
    for competitor in await competitors {
      try await competitor.1.send(event)
    }
  }

  func appendCompetitor(id: UUID, client: Client) {
    competitors.append((id, client))
  }

  nonisolated func join(id: UUID, client: Client) async throws {
    await appendCompetitor(id: id, client: client)

    try await client.send(.waiting)
    try await send(.joined(numberOfPlayers: 1 + competitors.count))
  }

  nonisolated func waitForStart() async throws {
    await start()

    try await challenger.1.send(.codeCreate(code: code))

    let readEvent = try await challenger.1.data.once()
    guard case let .multiplayerRequest(read) = readEvent, let string = read.string,
          string.contains("start")
    else {
      return try await waitForStart()
    }

      try await startGame()
  }

    nonisolated func startGame() async throws {
    try await send(.start)

    let game = try await startMultiplayerGame()

    logger.info("RESTART?")

    try await challenger.1.send(.requestRestart)

      await competitors.forEach { competitor in
        async {
         try await competitor.1.send(.waitForRestart)
        }
      }

      let readEvent = try await challenger.1.data.once()
      guard case let .multiplayerRequest(read) = readEvent, let string = read.string,
            string.contains("start")
      else {
        return try await waitForStart()
      }

      try await startGame()
  }

  nonisolated func finished() async throws -> Result<Void, Error> {
    try await finishEvent.once()
  }

  nonisolated private func startMultiplayerGame() async throws -> GameSnapshot {
    _ = await challenger.1.quit.on {
      do {
        try await self.send(.quit)
      } catch {}
    }

    for player in await competitors {
      _ = player.1.quit.on {
        do {
          try await self.send(.quit)
        } catch {}
      }
    }

    let initiatorAi = await UserInputAIJson(id: challenger.0) { request, error in
      if let error = error {
        try await self.challenger.1
          .send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
      }
      try await self.challenger.1
        .send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
      return try await self.challenger.1.data.once().getMultiplayerRequest()
    } renderHandler: { game in
      _ = try await self.challenger.1
        .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
    }

    let initiator = await Player(
      id: challenger.0,
      name: String(challenger.0.uuidString.prefix(5).prefix(5)),
      position: .noord,
      ai: initiatorAi
    )

    let joiners = await competitors.prefix(3).enumerated().map { index, player in
      Player(
        id: player.0,
        name: String(player.0.uuidString.prefix(5)),
        position: Position.allCases[index + 1],
        ai: UserInputAIJson(id: player.0) { request, error in
          if let error = error {
            try await player.1
              .send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
          }
          try await player.1
            .send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
          return try await player.1.data.once().getMultiplayerRequest()
        } renderHandler: { game in
          _ = try await player.1
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
        }
      )
    }

    let game = Game(
      players: [initiator] + joiners, slowMode: true, endGameHandler: { snapshot in
        async {
          try await WriteSnapshotToDisk.write(snapshot: snapshot)
        }
      }
    )
    let gameTask: Task<GameSnapshot, Error> = async {try await withTaskCancellationHandler(operation: {
      do {
        let result = try await game.startGame()
        return result
      } catch {
        self.logger.error("ERROR: \(error)")
        if error is CancellationError {
          finishEvent.emit(.success(()))
          throw error
        }
        finishEvent.emit(.failure(error))
        throw error
      }
    }, onCancel: {
      finishEvent.emit(.success(()))
    })}

   await setGameTask(gameTask)
    return try await gameTask.get()
  }

  private func setGameTask(_ gameTask: Task<GameSnapshot, Error>) {
    self.gameTask = gameTask
  }
}
