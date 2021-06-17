//
//  Shitheaden.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ArgumentParser
import CustomAlgo
import Foundation
import ShitheadenRuntime
import SwiftSocket

@main
struct Shitheaden: ParsableCommand {
  #if os(macOS)
  @Flag(help: "Test all the AI's")
  var testAi = false
#endif

  @Flag(help: "Start a server")
  var server = false

  @Option(name: .shortAndLong, help: "The number of parallelization")
  var parallelization: Int = 8

  mutating func run() async throws {

#if os(Linux)
    await startServer()
    return
#endif

    print("START!")
    if server {
      await startServer()
      return
    }
      #if os(macOS)
      if testAi {
      await playTournament()
      return
    } 
    #endif
      await interactive()
    
  }

    #if os(macOS)
  private func playTournament() async {
    return await withUnsafeContinuation { d in
      DispatchQueue.global().async {
        async {
          await Tournament(roundsPerGame: 10, parallelization: parallelization).playTournament()
          d.resume()
        }
      }
    }
  }
  #endif

  private func interactive() async {
    let game = Game(players: [
      Player(
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: UserInputAI()
      ),
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
    ], slowMode: true, render: { (game, clear) in
      await print(Renderer.render(game: game, clear: clear))
    })

    await game.startGame()
  }

//  private func startServer() async {
//    SshServer().startServer()
//  }

  private func startServer() async {
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

  private func echoService(client: TCPClient) async {
    print("Newclient from:\(client.address)[\(client.port)] \(Thread.isMainThread)")

    let game = Game(players: [
      Player(
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: UserInputAI {
          print("READ!")
          return await client.read()
        } render: { string in
          _ = await withUnsafeContinuation { c in
            c.resume(returning: client.send(string: string + "\n"))
          }
        }
      ),
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
    ], slowMode: true, render: { (game, clear) in
      await client.send(string: Renderer.render(game: game, clear: clear))
    })

    await game.startGame()
  }
}


actor AtomicBool {
  var value: Bool

  init(value: Bool) {
    self.value = value
  }

  func set(value: Bool) {
    self.value = value
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

      while !(string.hasSuffix("\n") || string.hasSuffix("\r")), await !cancel.value  {
        string += await _read(cancel: cancel)
        print("APPEND: \(string)")
      }
        print("COMMIT: \(string)")
      return string
    })
  }
}
