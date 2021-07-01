//
//  MultiplayerHandler.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import CustomAlgo
import Foundation
import Logging
import ShitheadenCLIRenderer
import ShitheadenRuntime
import ShitheadenShared

protocol Client: AnyObject {
  var quit: EventHandler<UUID>.ReadOnly { get }
  var data: EventHandler<ServerRequest>.ReadOnly { get }

  func send(_ event: ServerEvent) async throws
}

struct Contestant {
  let uuid: UUID
  let name: String
  let client: Client
}

actor MultiplayerHandler {
  private let logger = Logger(label: "cli.MultiplayerHandler")
  var challenger: Contestant
  let code: String
  var competitors: [Contestant]
  private var gameTask: Task<EndGameSnapshot, Error>?
  private let finishEvent = EventHandler<Result<Void, Error>>()
  public var finish: EventHandler<Result<Void, Error>>.ReadOnly { finishEvent.readOnly }
  public private(set) var cpus = 0

  init(challenger: Contestant) {
    self.challenger = challenger
    code = UUID().uuidString.prefix(5).lowercased()
    competitors = []
  }

  nonisolated func start() async {
    await challenger.client.quit.on { [weak self] uuid in
      guard let self = self else {
        return
      }
      self.logger.info("onQuitRead")

      asyncDetached {
        await self.competitors.forEach { competitor in
          asyncDetached {
            try await competitor.client.send(.quit(from: uuid))
          }
        }
      }

      self.finishEvent.emit(.success(()))
      await self.gameTask?.cancel()
    }
    await competitors.forEach { competitor in
      competitor.client.quit.on { [weak self] uuid in
        guard let self = self else {
          return
        }
        asyncDetached {
          let challenger = await self.challenger
          try await challenger.client.send(.quit(from: uuid))
          await self.competitors.filter { $0.uuid != competitor.uuid }.forEach { competitor in
            asyncDetached {
              try await competitor.client.send(.quit(from: uuid))
            }
          }
        }

        self.finishEvent.emit(.success(()))
        await self.gameTask?.cancel()
      }
    }
  }

  nonisolated func send(_ event: ServerEvent) async throws {
    try await challenger.client.send(event)
    for competitor in await competitors {
      try await competitor.client.send(event)
    }
  }

  func append(competitor: Contestant) {
    competitors.append(competitor)
  }

  nonisolated func join(competitor: Contestant) async throws {
    await append(competitor: competitor)

    try await competitor.client.send(.waiting)
    try await send(.joined(initiator: challenger.name, contestants: competitors.map(\.name),
                           cpus: cpus))
  }

  private func setCpus(_ newValue: Int) {
    cpus = max(0, min(4, newValue))
  }

  nonisolated func createGame() async throws {
    await start()

    try await challenger.client.send(.codeCreate(code: code))
    try await waitForStart()
  }

  nonisolated func waitForStart() async throws {
    let readEvent = try await challenger.client.data.once()
    if case let .multiplayerRequest(read) = readEvent, let string = read.string,
       string.contains("start")
    {
      let currentCpus = await cpus
      let currentCompetitors = await competitors
      if currentCompetitors.count + currentCpus >= 1, currentCompetitors.count + currentCpus <= 3 {
        return try await startGame()
      }
    }

    if case let .multiplayerRequest(read) = readEvent, let string = read.string,
       string.contains("cpu")
    {
      if let int = Int(string.replacingOccurrences(of: "cpu=", with: "")) {
        await setCpus(int)
      } else {
        if string == "cpu-" {
          await setCpus(cpus - 1)
        } else {
          await setCpus(cpus + 1)
        }
      }

      try await send(.joined(initiator: challenger.name, contestants: competitors.map(\.name),
                             cpus: cpus))

      return try await waitForStart()
    }

    return try await waitForStart()
  }

  nonisolated func startGame() async throws {
    try await send(.start)

    let game = try await startMultiplayerGame()

    logger.info("RESTART?")

    try await challenger.client.send(.requestRestart)

    await competitors.forEach { competitor in
      async {
        try await competitor.client.send(.waitForRestart)
      }
    }

    let readEvent = try await challenger.client.data.once()
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
    _ = await challenger.client.quit.on { uuid in
      do {
        try await self.send(.quit(from: uuid))
      } catch {}
    }

    for player in await competitors {
      _ = player.client.quit.on { uuid in
        do {
          try await self.send(.quit(from: uuid))
        } catch {}
      }
    }

    let initiatorAi = await UserInputAIJson(id: challenger.uuid) { request, error in
      if let error = error {
        try await self.challenger.client
          .send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
      }
      try await self.challenger.client
        .send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
      return try await self.challenger.client.data.once().getMultiplayerRequest()
    } renderHandler: { game in
      _ = try await self.challenger.client
        .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
    }

    let initiator = await Player(
      id: challenger.uuid,
      name: challenger.name,
      position: .noord,
      ai: initiatorAi
    )

    let joiners = await competitors.prefix(3).enumerated().map { index, player in
      Player(
        id: player.uuid,
        name: player.name,
        position: Position.allCases[index + 1],
        ai: UserInputAIJson(id: player.uuid) { request, error in
          if let error = error {
            try await player.client
              .send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
          }
          try await player.client
            .send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
          return try await player.client.data.once().getMultiplayerRequest()
        } renderHandler: { game in
          _ = try await player.client
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
        }
      )
    }

    let competitors = await competitors
    let cpus = await (0 ..< cpus).map {
      Player(
        name: "CPU\($0 + 1)",
        position: Position.allCases[$0 + competitors.count],
        ai: CardRankingAlgoWithUnfairPassingAndNexPlayerAware()
      )
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
