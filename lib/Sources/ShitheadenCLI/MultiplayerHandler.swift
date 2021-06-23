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
  var onQuit: EventHandler<()> { get }
  var onRead: EventHandler<ServerRequest> { get }

  func send(_ event: ServerEvent) async
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

      let r = await challenger.1.onRead.once()
      guard case let .multiplayerRequest(read) = r, let string = read.string,
            string.contains("start")
      else {
        return await waitForStart()
      }

      await send(.start)

      print(await startMultiplayerGame())
  }

  nonisolated func finished() async {
    _ = await finshedTask.getResult()
  }

  private func startMultiplayerGame() async -> GameSnapshot {
    _ = challenger.1.onQuit.on {
        await self.send(.quit)
    }
    
    for player in competitors {
      _ = player.1.onQuit.on {
        await self.send(.quit)
      }
    }

    let initiatorAi = UserInputAIJson(id: challenger.0) { request, error in
      print("READ! startMultiplayerGame", request)
      if let error = error {
        await self.challenger.1.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
      }
      await self.challenger.1.send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
      return try await self.challenger.1.onRead.once().getMultiplayerRequest()
    } renderHandler: { game in
      print("READ! renderHandler")
      _ = await self.challenger.1
        .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
//      if let error = game.playerError {
//        print(error)
//        _ = await self.challenger.1.send(.error(error: .playerError(error: error)))
//      }
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
          print("READ!", request)
        if let error = error {
        await player.1.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
        }
          await player.1.send(.multiplayerEvent(multiplayerEvent: .action(action: request)))
          return try await player.1.onRead.once().getMultiplayerRequest()
        } renderHandler: { game in
          print("READ! renderHandler")
          _ = await player.1
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: game)))
//          if let error = error {
//            _ = await player.1.send(.error(error: .playerError(error: error)))
//          }
        }
      )
    }

    let game = Game(
      players: [initiator] + joiners, slowMode: true
    )
    let gameTask = async {
      return await game.startGame()
    }

    self.gameTask = gameTask
    return await gameTask.get()
  }
}
