import Backtrace
import NIOExtras
import ShitheadenRuntime
import Signals
import Vapor
import AsyncAwaitHelpers

var httpServer: Task<Void, Error>!
var telnetServer: Task<Void, Error>!
var sshServer: Task<Void, Error>!

func cancel() {
  httpServer.cancel()
  telnetServer.cancel()
  sshServer.cancel()
}

@main
enum ShitheadenServer {
  static let logger = Logger(label: "ShitheadenServer")

  static func main() async throws {
    Backtrace.install()

    do {
      let signature = try await Signature.getSignature()
      let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(
          "shitheaden"
        )
        .appendingPathComponent(
          signature
        )
      try Data().write(to: url)
    } catch {
      logger.error("Signature handling: \(error)")
    }

    let group = MultiThreadedEventLoopGroup(numberOfThreads: max(4, System.coreCount / 2))
    let games = DictionaryActor<String, MultiplayerHandler>()

    httpServer = Task.detached {
      if #available(macCatalyst 15, *) {
        let httpServer = HttpServer(games: games)
        try await httpServer.start(group: group)
        cancel()
      } else {
        cancel()
      }
    }

    telnetServer = Task.detached {
      let helper = ServerQuiescingHelper(group: group)
      let server = TelnetServer(games: games)
      let channel = try await server.start(quiesce: helper, group: group)
      let promise = channel.eventLoop.makePromise(of: Void.self)

      await withTaskCancellationHandler(operation: {
        try! promise.futureResult.wait() // swiftlint:disable:this force_try
      }, onCancel: {
        helper.initiateShutdown(promise: promise)
      })

      cancel()
    }
    sshServer = Task.detached {
      let helper = ServerQuiescingHelper(group: group)
      let server = SSHServer(games: games)
      let channel = try await server.start(quiesce: helper, group: group)
      let promise = channel.eventLoop.makePromise(of: Void.self)

      await withTaskCancellationHandler(operation: {
        try! promise.futureResult.wait() // swiftlint:disable:this force_try
      }, onCancel: {
        helper.initiateShutdown(promise: promise)
      })

      cancel()
    }

    Signals.trap(signal: .int) { signal in
      print("SIGNAL! \(signal)") // swiftlint:disable:this disable_print
      cancel()
    }

    Signals.trap(signal: .term) { signal in
      print("SIGNAL! \(signal)") // swiftlint:disable:this disable_print
      cancel()
    }

    try await httpServer.value
    try await telnetServer.value
    try await sshServer.value
  }
}
