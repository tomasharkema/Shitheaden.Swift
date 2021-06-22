//
//  MultiplayerHandler.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import Foundation
import ShitheadenRuntime
import ShitheadenShared

protocol Client: AnyObject {
  var onQuit: [() async -> Void] { get set }
  func send(_ event: ServerEvent) async
  func read() async throws -> ServerRequest
}

actor MultiplayerHandler {
  var challenger: (UUID, Client)
  let code: String
  var competitors: [(UUID, Client)]
  let finshedTask: Task<Void, Never>
  var gameTask: Task<GameSnapshot, Never>?

  init(challenger: (UUID, Client), finshedTask: Task<Void, Never>) {
    self.challenger = challenger
    code = UUID().uuidString.prefix(5).lowercased()
    competitors = []
    self.finshedTask = finshedTask
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

  nonisolated func waitForStart() async {
    await challenger.1.send(.codeCreate(code: code))

    do {
      let r = try await challenger.1.read()
      guard case let .multiplayerRequest(read) = r, let string = read.string,
            string.contains("start")
      else {
        return await waitForStart()
      }

      await send(.start)

      await startMultiplayerGame()
    } catch {
      print(error)
      return await waitForStart()
    }
//    promise.resolve()
  }

  nonisolated func finished() async {
    _ = await finshedTask.getResult()
  }

  private func startMultiplayerGame() async {
    await challenger.1.onQuit.append {
      await self.send(.quit)
    }
    for player in await competitors {
      player.1.onQuit.append {
        await self.send(.quit)
      }
    }

    let initiatorAi = UserInputAIJson(id: challenger.0) { request in
      print("READ! startMultiplayerGame", request)
      await self.challenger.1.send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
      return try await self.challenger.1.read().getMultiplayerRequest()
    } renderHandler: { game, error in
      _ = await self.challenger.1
        .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
      if let error = error {
        print(error)
        _ = await self.challenger.1.send(.error(error: .playerError(error: error)))
      }
    }

    let initiator = Player(
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
        ai: UserInputAIJson(id: player.0) { request in
          print("READ!", request)
          await player.1.send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
          return try await player.1.read().getMultiplayerRequest()
        } renderHandler: { game, error in
          _ = await player.1
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
          print(error)
          if let error = error {
            _ = await player.1.send(.error(error: .playerError(error: error)))
          }
        }
      )
    }

    let game = Game(
      players: [initiator] + joiners, slowMode: true
    )
    let gameTask = async {
      await game.startGame()
    }

    self.gameTask = gameTask
    await gameTask.getResult()
  }
}
