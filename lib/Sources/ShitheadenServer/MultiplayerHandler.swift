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
import CustomAlgo

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
  private var gameTask: Task<EndGameSnapshot, Error>?
  private let finishEvent = EventHandler<Result<Void, Error>>()
  public var finish: EventHandler<Result<Void, Error>>.ReadOnly { finishEvent.readOnly }
  public private(set) var cpus = 0

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
    try await send(.joined(numberOfPlayers: 1 + competitors.count + self.cpus))
  }

  private func setCpus(_ newValue: Int) {
    cpus = newValue
  }

  nonisolated func createGame() async throws {

    await start()

    try await challenger.1.send(.codeCreate(code: code))
    try await waitForStart()
  }

  nonisolated func waitForStart() async throws {

    let readEvent = try await challenger.1.data.once()
    if case let .multiplayerRequest(read) = readEvent, let string = read.string,
          string.contains("start") {
      let currentCpus = await cpus
      let currentCompetitors = await competitors
      if currentCompetitors.count + currentCpus >= 1 && currentCompetitors.count + currentCpus <= 3 {
        return try await startGame()
      }
    }

    if case let .multiplayerRequest(read) = readEvent, let string = read.string,
          string.contains("cpu")
     {
      if let int = Int(string.replacingOccurrences(of: "cpu=", with: "")) {
        await setCpus(int)
      } else {
        await setCpus(cpus + 1)
      }

      try await send(.joined(numberOfPlayers: 1 + competitors.count + cpus))

      return try await waitForStart()
    }

    return try await waitForStart()
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

  private nonisolated func startMultiplayerGame() async throws -> EndGameSnapshot {
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

    let competitors = await competitors
    let cpus = await (0..<cpus).map {
      Player(name: "CPU\($0 + 1)", position: Position.allCases[$0 + competitors.count], ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware())
    }

    let game = Game(
      players: [initiator] + joiners + cpus, slowMode: true
    )
    let gameTask: Task<EndGameSnapshot, Error> = async {
      try await withTaskCancellationHandler(operation: {
        do {
          let result = try await game.startGame()

          asyncDetached(priority: .background) {
            try await WriteSnapshotToDisk.write(snapshot: result)
          }

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
      })
    }

    await setGameTask(gameTask)
    return try await gameTask.get()
  }

  private func setGameTask(_ gameTask: Task<EndGameSnapshot, Error>) {
    self.gameTask = gameTask
  }
}
