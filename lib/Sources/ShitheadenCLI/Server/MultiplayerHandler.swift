//
//  MultiplayerHandler.swift
//  
//
//  Created by Tomas Harkema on 19/06/2021.
//

import Foundation
import ShitheadenShared
import ShitheadenRuntime

enum MultiplayerRequest {
  case cards([Int])
  case string(String)
  case pass

  var string: String? {
    switch self {
    case .string(let string):
      return string
    default:
      return nil
    }
  }
}

enum MultiplayerEvent: Equatable, Codable {
  case joined(numberOfPlayers: Int)
  case codeCreate(code: String)
  case start
  case waiting
  case error(PlayerError)

  case string(String)
  case gameSnapshot(GameSnapshot, PlayerError?)
}

protocol Client {
  func send(_ event: MultiplayerEvent) async
  func read() async throws -> MultiplayerRequest
}

actor MultiplayerHandler {
  let challenger: (UUID, Client)
  let code: String
  var competitors: [(UUID, Client)]
  let finshedTask: Task<Void, Never>

  init(challenger: (UUID, Client), finshedTask: Task<Void, Never>) {
    self.challenger = challenger
    self.code = UUID().uuidString.prefix(5).lowercased()
    self.competitors = []
    self.finshedTask = finshedTask
  }

  nonisolated func send(_ event: MultiplayerEvent) async {
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

//    let send = """
//    Aantal spelers: \(1 + competitors.count)
//
//    """
//    master.1.send(string: send)
//    for s in slaves {
//      s.1.send(string: send)
//    }
  }

  nonisolated func waitForStart() async {
    await challenger.1.send(.codeCreate(code: code))

    do {
      let read = await try challenger.1.read()
      print(read)
      guard let string = read.string, string.contains("start") else {
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
    let _ = await finshedTask.getResult()
  }

  nonisolated private func startMultiplayerGame() async {
    
    let initiatorAi = UserInputAIJson(id: challenger.0) {
      print("READ!")
      return try await self.challenger.1.read()
    } renderHandler: { (game, error) in
//      if let error = error {
//        _ = await self.challenger.1.send(.error(error))
//      }
      _ = await self.challenger.1.send(.gameSnapshot(game, error))
    }

    let initiator = Player(
      id: challenger.0,
      name: String(challenger.0.uuidString.prefix(5).prefix(5)),
      position: .noord,
      ai: initiatorAi
    )

    let joiners = await competitors.prefix(3).enumerated().map { (index, player) in
      Player(
        id: player.0,
        name: String(player.0.uuidString.prefix(5)),
        position: Position.allCases[index + 1],
        ai: UserInputAIJson(id: player.0) {
        print("READ!")
        return try await player.1.read()
      } renderHandler: { (game, error) in
//        if let error = error {
//          _ = await player.1.send(.error(error))
//        }
        _ = await player.1.send(.gameSnapshot(game, error))
      }
      )
    }

    let game = Game(
      players: [initiator] + joiners, slowMode: true
    )

    await game.startGame()
  }
}
