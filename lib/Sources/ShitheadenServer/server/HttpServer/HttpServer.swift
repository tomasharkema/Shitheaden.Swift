//
//  File.swift
//
//
//  Created by Tomas Harkema on 28/06/2021.
//

import Foundation
import ShitheadenRuntime
import ShitheadenShared
import Vapor

private let websocketResponse = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Shitheaden</title>
  </head>
  <body>

    <h1>WebSocket Stream</h1>
    <form name="myForm" id="former">
        <input name="fname" "type="text" id="command"/>
    </form>

    <div id="websocket-stream"></div>
    <script>
console.log(location);
        var wsconnection = new WebSocket(location.href.replace("http", "ws") + "/websocket");
const reader = new FileReader();
        wsconnection.onmessage = async function (msg) {
            var element = document.createElement("p");
            const string = await msg.data.text();
            console.log(string);
            element.innerHTML = "<code>" + string + "</code>";
            var textDiv = document.getElementById("websocket-stream");
            textDiv.insertBefore(element, null);
        };

        function validateForm(e) {
          e.preventDefault();
          wsconnection.send(document.forms["myForm"]["fname"].value + "\\n");
          return false;
        };
document.getElementById("former").addEventListener('submit', validateForm);
    </script>
  </body>
</html>
"""

class HttpServer {
  private let logger = Logger(label: "cli.HttpServer")
  let games: AtomicDictionary<String, MultiplayerHandler>
  private var channel: Channel?

  init(games: AtomicDictionary<String, MultiplayerHandler>) {
    self.games = games
  }

  func start(group: MultiThreadedEventLoopGroup) async throws {
    let app = Application(.development, .shared(group))
    app.http.server.configuration.port = 3338
    app.http.server.configuration.hostname = "0.0.0.0"

    defer { app.shutdown() }

    app.on(.POST, "playedGame", body: .collect(maxSize: "10mb")) { req -> String in
      self.logger.info("\(req)")
      let snapshot = try req.content.decode(EndGameSnapshot.self)
      if try await Signature.getSignature() == snapshot.signature {
        try await WriteSnapshotToDisk.write(snapshot: snapshot)
      } else {
        throw NSError(domain: "Signature is not recognized", code: 0, userInfo: nil)
      }
      return "ojoo!"
    }

    app.get("debug") { _ in
      Response(
        status: .ok,
        headers: ["Content-Type": "text/html"],
        body: .init(string: websocketResponse)
      )
    }

    app.webSocket("debug/websocket") { _, ws in
      self.logger.info("\(ws)")
      let client = WebsocketClient(
        websocket: ws,
        games: self.games
      )
      async {
        try await client.start()
      }
    }

    app.webSocket("websocket") { _, ws in
      self.logger.info("\(ws)")
      let client = WebsocketClient(
        websocket: ws,
        games: self.games
      )
      async {
        try await client.start()
      }
    }

    try app.run()
    app.shutdown()
    logger.info("QUIT!")
    logger.info("\(app)")
  }
}
