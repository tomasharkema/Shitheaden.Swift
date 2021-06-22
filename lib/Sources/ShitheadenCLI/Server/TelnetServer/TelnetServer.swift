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
  let games: AtomicDictonary<String, MultiplayerHandler>

  init(games: AtomicDictonary<String, MultiplayerHandler>) {
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
              await echoService(client: client)
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

  private func singlePlayer(client: TCPClient) async {
    print("Newclient from:\(client.address)[\(client.port)] \(Thread.isMainThread)")
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
          ai: UserInputAIJson.cli(id: id, print: {
            await client.send(string: $0)
          }, read: {
            await client.read()
          })
        ),
      ], slowMode: true
    )

    await game.startGame()
  }

  private func echoService(client: TCPClient) async {
    client.send(string: """
    Welkom bij shitheaden!!

    Typ het volgende om te beginnen:
    join          Join een online game
    single        Start een single game
    multiplayer   Start een multiplayer game

    """)
    let choice: String = await client.read()
    print(choice)

    if choice.hasPrefix("j") {
      // join
      await joinGame(client: client)
    } else if choice.hasPrefix("s") {
      // single
      await singlePlayer(client: client)
    } else if choice.hasPrefix("m") {
      // muliplayer
      await startMultiplayer(client: client)
    }

    return await echoService(client: client)
  }

  private func startMultiplayer(client: TCPClient) async {
    let id = UUID()
    let promise = Promise()
    let pair = MultiplayerHandler(
      challenger: (id, TelnetClient(client: client)),
      finshedTask: promise.task
    )
    await games.insert(pair.code, value: pair)

    await pair.waitForStart()
  }

  private func joinGame(client: TCPClient) async {
    client.send(string: """


    Typ je code in:

    """)
    let code = await client.read().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if let game = await games.get(code) {
      let id = UUID()
      await game.join(id: id, client: TelnetClient(client: client))
      await game.finished()
    } else {
      client.send(string: """

      Game niet gevonden...

      """)
      return await echoService(client: client)
    }
  }
}

extension TCPClient {
  func _read(cancel: AtomicBool) async -> String {
    while bytesAvailable() == 0 {
      await delay(for: .now() + 0.1)
    }
    guard let bytes = bytesAvailable(), await !cancel.value else {
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

  func read() async -> String {
    let cancel = AtomicBool(value: false)

    return await withTaskCancellationHandler(handler: {
      async {
        await cancel.set(value: true)
      }
    }, operation: {
      var string = ""

      while !(string.hasSuffix("\n") || string.hasSuffix("\r")), await !cancel.value {
        string += await _read(cancel: cancel)
        print("APPEND: \(string)")
      }
      print("COMMIT: \(string)")
      return string
    })
  }
}

class TelnetClient: Client {
  let client: TCPClient
  var onQuit = [() async -> Void]()

  init(client: TCPClient) {
    self.client = client
  }

  func send(_ event: ServerEvent) async {
    switch event {
    case let .multiplayerEvent(.error(error)):
      client.send(string: await Renderer.error(error: error))

    case let .multiplayerEvent(.string(string)):

      client.send(string: string)

    case let .multiplayerEvent(.gameSnapshot(snapshot)):
      client.send(string: await Renderer.render(game: snapshot, error: nil))

    case .waiting:
      client.send(string: """

      Joined! Wachten tot de game begint...

      """)
    case let .joined(numberOfPlayers):
      client.send(string: """

      Aantal spelers: \(numberOfPlayers)

      """)
    case let .codeCreate(code):
      client.send(string: """


      Hier is je code: \(code). Geef deze code aan je vrienden en wacht tot ze joinen!
      Als je klaar bent, typ start!

      """)

    case .start:
      client.send(string: """


      Start game!

      """)
    case let .error(.playerError(error)):
      client.send(string: await Renderer.error(error: error))

    case .requestMultiplayerChoice:
      print("START", event)
    case let .error(error: .text(text: text)):
      print("START", event)
    case let .error(error: .gameNotFound(code: code)):
      print("START", event)
    case let .multiplayerEvent(multiplayerEvent: .action(action: action)):
      print("START", event)

    case .quit:
      for onQuit in onQuit {
        await onQuit()
      }
      return client.close()
    }
  }

  func read() async throws -> ServerRequest {
    client.send(string: ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
      row: RenderPosition.input.y + 2,
      column: 0
    ))

    let input: String = await client.read()
    client.send(string: ANSIEscapeCode.Cursor.hideCursor)
    let inputs = input.split(separator: ",").map {
      Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if inputs.contains(nil) {
//      await renderHandler(RenderPosition.input.down(n: 1)
//                            .cliRep + "Je moet p of een aantal cijfers invullen...")
//      throw PlayerError(text: "Je moet p of een aantal cijfers invullen...")
      return .multiplayerRequest(.string(input))
    }

    return .multiplayerRequest(.cardIndexes(inputs.map { $0! }))
  }
}
