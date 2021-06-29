import ShitheadenRuntime
import Vapor

@main
enum ShitheadenServer {
  static func main() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount / 2)
    let games = AtomicDictionary<String, MultiplayerHandler>()

    let httpServer = async {
      let httpServer = HttpServer(games: games)
      try await httpServer.start(group: group)
    }
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
    try await telnetServer.get()
    try await sshServer.get()
  }
}
