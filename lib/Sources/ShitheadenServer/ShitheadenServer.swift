import ShitheadenRuntime
import Signals
import Vapor

var httpServer: Task.Handle<Void, Error>!
var telnetServer: Task.Handle<Void, Error>!
var sshServer: Task.Handle<Void, Error>!

@main
enum ShitheadenServer {
  static let logger = Logger(label: "ShitheadenServer")

  static func main() async throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: max(4, System.coreCount / 2))
    let games = AtomicDictionary<String, MultiplayerHandler>()

    httpServer = async {
      let httpServer = HttpServer(games: games)
      try await httpServer.start(group: group)
    }
    telnetServer = async {
      let server = TelnetServer(games: games)
      let channel = try await server.start(group: group)
      try channel.closeFuture.wait()
    }
    sshServer = async {
      let server = SSHServer(games: games)
      let channel = try await server.start(group: group)
      try channel.closeFuture.wait()
    }

    Signals.trap(signal: .int) { signal in
      print("SIGNAL! \(signal)") // swiftlint:disable:this disable_print
      httpServer.cancel()
      telnetServer.cancel()
      sshServer.cancel()
    }

    try await httpServer.get()
    try await telnetServer.get()
    try await sshServer.get()
  }
}
