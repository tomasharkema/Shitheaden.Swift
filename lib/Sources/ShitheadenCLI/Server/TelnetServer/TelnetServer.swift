//
//  TelnetServer.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import ANSIEscapeCode
import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import SwiftSocket

class TelnetServer {
  let games: AtomicDictionary<String, MultiplayerHandler>

  init(games: AtomicDictionary<String, MultiplayerHandler>) {
    self.games = games
  }

  func attach(client: TelnetClient) {
    let task = async {
      try await echoService(client: client)
    }
    client.quit.once {
      task.cancel()
      self.attach(client: client)
    }
  }

  func startServer() async {
    async {
      print("START! telnet")
      let server = TCPServer(address: "0.0.0.0", port: 3333)
      switch server.listen() {
      case .success:
        while true {
          if let client = server.accept() {
            attach(client: TelnetClient(client: client))

          } else {
            print("accept error")
          }
        }
      case let .failure(error):
        print(error)
      }
    }

    return await withUnsafeContinuation { _ in }
  }

  private func singlePlayer(client: TelnetClient) async throws -> GameSnapshot {
    let id = UUID()
    let game = Game(
      players: [
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
          ai: UserInputAIJson(id: id, reader: {
            await client.send(.multiplayerEvent(multiplayerEvent: .action(action: $0)))
            if let error = $1 {
              await client.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
            }
            return try await client.data.once().getMultiplayerRequest()
          }, renderHandler: {
            _ = await client.send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: $0)))
          })
        ),
      ], slowMode: true
    )

    return try await game.startGame()
  }

  private func echoService(client: TelnetClient) async throws {
        await client.send(string: """
        Welkom bij shitheaden!!

        Typ het volgende om te beginnen:
        join          Join een online game
        single        Start een single game
        multiplayer   Start een multiplayer game
        """)
        guard let choice: String = try await client.data.once().getMultiplayerRequest().string
        else {
          return try await echoService(client: client)
        }
        print(choice)

        if choice.hasPrefix("j") {
          // join
          try await joinGame(client: client)
        } else if choice.hasPrefix("s") {
          // single
          print(try await singlePlayer(client: client))
        } else if choice.hasPrefix("m") {
          // muliplayer
          try await startMultiplayer(client: client)
        }

        return try await echoService(client: client)
  }

  private func startMultiplayer(client: TelnetClient) async throws {
    let id = UUID()
    let promise = Promise()
    let pair = MultiplayerHandler(
      challenger: (id, client)
    )
    await games.insert(pair.code, value: pair)

    try await pair.waitForStart()
  }

  private func joinGame(client: TelnetClient) async throws {
    await client.send(string: """


    Typ je code in:
""")
    let s = try await client.data.once()
    print(s)
    guard let code = try await s.getMultiplayerRequest().string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    else {
      return try await joinGame(client: client)
    }

    if let game = await games.get(code) {
      let id = UUID()
      await game.join(id: id, client: client)
      try await game.finished()
      return try await echoService(client: client)
    } else {
      await client.send(string: """

      Game niet gevonden...
""")
      return try await echoService(client: client)
    }
  }
}

extension TCPClient {
  func _read() async throws -> String {
    while bytesAvailable() == 0 {
      try Task.checkCancellation()
      await delay(for: .now() + 0.1)
    }

    try Task.checkCancellation()

    guard let bytes = bytesAvailable() else {
      print("STRING NOT PARSED")
      return ""
    }
    guard let arr = read(Int(bytes)) else {
      print("STRING NOT PARSED")
      return ""
    }
    print(arr)
    let data = Data(arr)
    print(data)
    guard let string = String(data: data, encoding: .utf8) else {
      print("STRING NOT PARSED")
      return ""
    }
    print(string)
    return string
  }

  func read() async throws -> String {
    var string = ""

    while !(string.hasSuffix("\n") || string.hasSuffix("\r")) {
      try Task.checkCancellation()
      string += try await _read()
      print("APPEND: \(string)")
    }
    try Task.checkCancellation()
    print("COMMIT: \(string)")
    return string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}

