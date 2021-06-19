//
//  TelnetServer.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import SwiftSocket
import ANSIEscapeCode

class TelnetServer {
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
    let userId = UUID()
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
          id: userId,
          name: "Zuid (JIJ)",
          position: .zuid,
          ai: UserInputAIJson(id: userId) {
            print("READ!")
      return .string(await client.read())
          } renderHandler: {
            _ = await client.send(string: Renderer.render(game: $0, error: $1))
          }
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

  private var games = AtomicDictonary<String, MultiplayerHandler>()

  private func startMultiplayer(client: TCPClient) async {
    let id = UUID()
    let promise = Promise()
    let pair = MultiplayerHandler(challenger: (id, client), finshedTask: promise.task)
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
      await game.join(id: id, client: client)
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

extension TCPClient: Client {
  func send(_ event: MultiplayerEvent) async {
    switch event {
    case .waiting:
      send(string: """

      Joined! Wachten tot de game begint...

      """)
    case .joined(let numberOfPlayers):
      send(string: """

      Aantal spelers: \(numberOfPlayers)

      """)
    case .codeCreate(let code):
      send(string: """


      Hier is je code: \(code). Geef deze code aan je vrienden en wacht tot ze joinen!
      Als je klaar bent, typ start!

      """)

    case .string(let string):
      send(string: string)
    case .start:
      send(string: """


      Start game!

      """)
    case .gameSnapshot(let snapshot, let error):
      send(string: await Renderer.render(game: snapshot, error: error))
    case .error(let error):
      print(error)
    }
  }

  func read() async throws -> MultiplayerRequest {

    send(string: ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
            row: RenderPosition.input.y + 2,
            column: 0
          ))

    let input: String = await read()
    send(string: ANSIEscapeCode.Cursor.hideCursor)
    let inputs = input.split(separator: ",").map {
      Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if inputs.contains(nil) {
//      await renderHandler(RenderPosition.input.down(n: 1)
//                            .cliRep + "Je moet p of een aantal cijfers invullen...")
//      throw PlayerError(text: "Je moet p of een aantal cijfers invullen...")
      return .string(input)
    }

    return .cards(inputs.map { $0! })
  }
}
