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

  func startServer() async {
    async {
      print("START! telnet")
      let server = TCPServer(address: "0.0.0.0", port: 3333)
      switch server.listen() {
      case .success:
        while true {
          if let client = server.accept() {
            asyncDetached { [client] in
              await echoService(client: TelnetClient(client: client))
            }
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

  var onQuitRead: UUID?
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
//          ai: UserInputAIJson.cli(id: id, print: {
//      client.send(.s)
//          }, read: {
//            print("READ!")
//            return await client.read()
//          })
        ),
      ], slowMode: true
    )

    let task: Task<GameSnapshot, Error> = async {
      let s = try await game.startGame()
      print("DONE!")
      return s
    }

    onQuitRead = client.quit.on {
      print("onQuitRead")
      task.cancel()
    }

    return try await task.get()
  }

  private func echoService(client: TelnetClient) async {
    do {
      let task: Task.Handle<Void, Error> = asyncDetached {
        await client.send(string: """
        Welkom bij shitheaden!!

        Typ het volgende om te beginnen:
        join          Join een online game
        single        Start een single game
        multiplayer   Start een multiplayer game

        """)
        guard let choice: String = try await client.data.once().getMultiplayerRequest().string
        else {
          return await echoService(client: client)
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

        return await echoService(client: client)
      }

      return try await task.get()
    } catch {
      print("RESTART!")
      return await echoService(client: client)
    }
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
    guard let code = await (try await client.data.once().getMultiplayerRequest().string)?
      .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    else {
      return try await joinGame(client: client)
    }

    if let game = await games.get(code) {
      let id = UUID()
      await game.join(id: id, client: client)
      try await game.finished()
      return await echoService(client: client)
    } else {
      await client.send(string: """

      Game niet gevonden...

      """)
      return await echoService(client: client)
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
//    return await withTaskCancellationHandler(handler: {
//      print("TASKCANCEL!")
//      async {
//        await cancel.set(value: true)
//      }
//    }, operation: {
    var string = ""

    while !(string.hasSuffix("\n") || string.hasSuffix("\r")) {
      try Task.checkCancellation()
      string += try await _read()
      print("APPEND: \(string)")
    }
    try Task.checkCancellation()
    print("COMMIT: \(string)")
    return string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//    })
  }
}

class TelnetClient: Client {
  let client: TCPClient
  let quit = EventHandler<Void>()
  let data = EventHandler<ServerRequest>()

  init(client: TCPClient) {
    self.client = client

    async { do {
      try await read()
    } catch {
      data.emit(.quit)
      quit.emit(())
      print("ERROR", error)
    }}
  }

  func send(string: String) async {
    await send(.multiplayerEvent(multiplayerEvent: .string(string: string)))
  }

  func send(_ event: ServerEvent) async {
    switch event {
    case let .multiplayerEvent(.error(error)):
      await send(string: await Renderer.error(error: error))

    case let .multiplayerEvent(.string(string)):
      await client.send(string: string)

    case let .multiplayerEvent(.gameSnapshot(snapshot)):
      await send(string: await Renderer.render(game: snapshot))

    case .waiting:
      await send(string: """

      Joined! Wachten tot de game begint...

      """)
    case let .joined(numberOfPlayers):
      await send(string: """

      Aantal spelers: \(numberOfPlayers)

      """)
    case let .codeCreate(code):
      await send(string: """


      Hier is je code: \(code). Geef deze code aan je vrienden en wacht tot ze joinen!
      Als je klaar bent, typ start!

      """)

    case .start:
      await send(string: """


      Start game!

      """)
    case let .error(.playerError(error)):
      await send(string: await Renderer.error(error: error))

    case .requestMultiplayerChoice:
      print("START", event)
    case let .error(error: .text(text: text)):
      print("START", event)
    case let .error(error: .gameNotFound(code: code)):
      print("START", event)
    case let .multiplayerEvent(multiplayerEvent: .action(action: action)):

      await send(string: ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
        row: RenderPosition.input.y + 2,
        column: 0
      ))

    case .quit:
      print("QUIT!")
//      await quit.emit(())
//      return client.close()
    }
  }

  private func read() async throws -> ServerRequest {
//    await send(string: ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
//      row: RenderPosition.input.y + 2,
//      column: 0
//    ))

    let input: String = try await client.read()

    if input.contains("quit") {
      data.emit(.quit)
      quit.emit(())
      print("ON QUIT")
      return .quit
    }

//    await send(string: ANSIEscapeCode.Cursor.hideCursor)
    let inputs = input.split(separator: ",").map {
      Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if inputs.contains(nil) {
//      await renderHandler(RenderPosition.input.down(n: 1)
//                            .cliRep + "Je moet p of een aantal cijfers invullen...")
//      throw PlayerError(text: "Je moet p of een aantal cijfers invullen...")

      await data.emit(.multiplayerRequest(.string(input)))
      try Task.checkCancellation()
      return try await read()
//      return .multiplayerRequest(.string(input))
    }
    await data.emit(.multiplayerRequest(.cardIndexes(inputs.map { $0! })))
    try Task.checkCancellation()
    return try await read()
  }
}
