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
          ai: UserInputAI(id: userId) {
            print("READ!")
            return await client.read()
          } renderHandler: { string in
            //            async {
            _ = client.send(string: string)
            //            }
          }
        ),
      ], slowMode: true
//      , localUserUUID: userId, render: { game, clear in
//        _ = await client.send(string: Renderer.render(game: game, clear: clear))
//      }
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
    let choice = await client.read()
    print(choice)

    if choice.contains("join") {
      // join
      return await joinGame(client: client)
    } else if choice.contains("single") {
      // single
      return await singlePlayer(client: client)
    } else if choice.contains("multiplayer") {
      // muliplayer
      return await startMultiplayer(client: client)
    }

    return await echoService(client: client)
  }

  private var games = AtomicDictonary<String, MultiplayerPair>()

  private func startMultiplayer(client: TCPClient) async {
    let code = String(UUID().uuidString.prefix(5)).lowercased()
    let id = UUID()

    let pair = MultiplayerPair(master: (id, client), code: code, slaves: [])
    await games.insert(code, value: pair)

    client.send(string: """


    Hier is je code: \(code). Geef deze code aan je vrienden en wacht tot ze joinen!
    Als je klaar bent, typ start!

    """)

    while await !client.read().contains("start") {
      client.send(string: """


      Hier is je code: \(code). Geef deze code aan je vrienden en wacht tot ze joinen!
      Als je klaar bent, typ start!

      """)
    }

    client.send(string: """


    Start game!

    """)

    if let game = await games.get(code) {
      return await startMultiplayerGame(pair: game)
    }
  }

  private func joinGame(client: TCPClient) async {
    client.send(string: """


    Typ je code in:

    """)
    let code = await client.read().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if let game = await games.get(code) {
      let id = UUID()
      client.send(string: """
      Joined! Wachten tot de game begint...

      """)
      await game.join(id: id, client: client)
    } else {
      client.send(string: """
      Game niet gevonden...

      """)
    }
  }

  private func startMultiplayerGame(pair: MultiplayerPair) async {
    let master = await pair.master
    let slaves = await pair.slaves
    let initiatorAi = UserInputAI(id: pair.master.0) {
      print("READ!")
      return await master.1.read()
    } renderHandler: { string in
      //            async {
      _ = pair.master.1.send(string: string)
      //            }
    }
    let initiator = Player(
      id: pair.master.0,
      name: String(pair.master.0.uuidString.prefix(5).prefix(5)),
      position: .noord,
      ai: initiatorAi
    )
    let joiners = slaves.prefix(3).enumerated().map { (index, player) in
      Player(
        id: player.0,
        name: String(player.0.uuidString.prefix(5)),
        position: Position.allCases[index + 1],
        ai: UserInputAI(id: player.0) {
          print("READ!")
          return await player.1.read()
        } renderHandler: { string in
          //            async {
          _ = player.1.send(string: string)
          //            }
        }
      )
    }

    let game = Game(
      players: [initiator] + joiners, slowMode: true
//      ,localUserUUID: pair.master.0, render: { game, clear in
////      _ = await client.send(string: Renderer.render(game: game, clear: clear))
//
//        let players = [master.1] + slaves.map { $0.1 }
//        for player in players {
//          _ = await player.send(string: Renderer.render(game: game, clear: clear))
//        }
//      }
    )

    await game.startGame()
  }
}

actor AtomicDictonary<Key: Hashable, Value> {
  var dict = [Key: Value]()

  public func insert(_ key: Key, value: Value) {
    dict[key] = value
  }

  public func get(_ key: Key) -> Value? {
    return dict[key]
  }
}

actor MultiplayerPair {
  let master: (UUID, TCPClient)
  let code: String
  var slaves: [(UUID, TCPClient)]

  init(master: (UUID, TCPClient), code: String, slaves: [(UUID, TCPClient)]) {
    self.master = master
    self.code = code
    self.slaves = slaves
  }

  func join(id: UUID, client: TCPClient) async {
    slaves.append((id, client))

    let send = """
    Aantal spelers: \(1 + slaves.count)

    """
    master.1.send(string: send)
    for s in slaves {
      s.1.send(string: send)
    }
  }
}

extension TCPClient {
  func _read(cancel: AtomicBool) async -> String {
    while bytesAvailable() == 0 {}
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
