//
//  TelnetClient.swift
//  
//
//  Created by Tomas Harkema on 23/06/2021.
//

import SwiftSocket
import ShitheadenShared
import ShitheadenRuntime
import ANSIEscapeCode

class TelnetClient: Client {
  let client: TCPClient
  let quitHandler = EventHandler<Void>()
  let dataHandler = EventHandler<ServerRequest>()

  var quit: EventHandler<Void>.ReadOnly { quitHandler.readOnly }
  var data: EventHandler<ServerRequest>.ReadOnly { dataHandler.readOnly }

  init(client: TCPClient) {
    self.client = client

    async {
      await start()
    }
  }

  func start() async {
    do {
      try await read()
    } catch {
      dataHandler.emit(.quit)
      print("ERROR", error)
      return await start()
    }
  }

  func send(string: String) async {
    await send(.multiplayerEvent(multiplayerEvent: .string(string: string)))
  }

  func send(_ event: ServerEvent) async {
    switch event {
    case let .multiplayerEvent(.error(error)):
      await send(string: await Renderer.error(error: error))

    case let .multiplayerEvent(.string(string)):
      await client.send(string: string.trimmingCharacters(in: .whitespacesAndNewlines) + "\n")

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
    }
  }

  private func read() async {
    do {
      let input: String = try await client.read()

      if input.contains("quit") {
        dataHandler.emit(.quit)
        quitHandler.emit(())
        return await read()
      }

      //    await send(string: ANSIEscapeCode.Cursor.hideCursor)
      let inputs = input.split(separator: ",").map {
        Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      if inputs.contains(nil) {
        await dataHandler.emit(.multiplayerRequest(.string(input)))
        return await read()
      }
      await dataHandler.emit(.multiplayerRequest(.cardIndexes(inputs.map { $0! })))
      return await read()
    } catch {
      print("read() throws", error)
      return await read()
    }
  }
}
