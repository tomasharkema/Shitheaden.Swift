import Vapor
import ShitheadenRuntime

@main
struct ShitheadenServer {
  static func main() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount / 2)
    let games = AtomicDictionary<String, MultiplayerHandler>()

    let httpServer = async {
      let httpServer = HttpServer(games: games)
      try await httpServer.start(group: group)
    }

//    let websocketServer = async {
////        logger.notice("START! websocket")
//        let server = WebsocketServer(games: games)
//        let channel = try await server.server(group: group)
//        try channel.closeFuture.wait()
//    }
    let telnetServer = async {
      let server = TelnetServer(games: games)
      let channel = try await server.start(group: group)
      try channel.closeFuture.wait()
    }
    let sshServer = async {
      let server = SSHServer(games: games)
      let channel = try await server.start(group: group)
      try channel.closeFuture.wait()
    }
    try await httpServer.get()
//    try await websocketServer.get()
    try await telnetServer.get()
    try await sshServer.get()
  }
}
