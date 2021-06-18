//
//  HTTPHandler.swift
//  
//
//  Created by Tomas Harkema on 18/06/2021.
//

import CustomAlgo
import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenRuntime

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
        var wsconnection = new WebSocket(location.href.replace("http", "ws") + "/websocket");
        wsconnection.onmessage = function (msg) {
            var element = document.createElement("p");
            element.innerHTML = msg.data;
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

final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  private var responseBody: ByteBuffer!

  func handlerAdded(context: ChannelHandlerContext) {
    responseBody = context.channel.allocator.buffer(string: websocketResponse)
  }

  func handlerRemoved(context _: ChannelHandlerContext) {
    responseBody = nil
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let reqPart = unwrapInboundIn(data)

    // We're not interested in request bodies here: we're just serving up GET responses
    // to get the client to initiate a websocket request.
    guard case let .head(head) = reqPart else {
      return
    }

    // GETs only.
    guard case .GET = head.method else {
      respond405(context: context)
      return
    }

    var headers = HTTPHeaders()
    headers.add(name: "Content-Type", value: "text/html")
    headers.add(name: "Content-Length", value: String(responseBody.readableBytes))
    headers.add(name: "Connection", value: "close")
    let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1),
                                        status: .ok,
                                        headers: headers)
    context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
    context.write(wrapOutboundOut(.body(.byteBuffer(responseBody))), promise: nil)
    context.write(wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
      context.close(promise: nil)
    }
    context.flush()
  }

  private func respond405(context: ChannelHandlerContext) {
    var headers = HTTPHeaders()
    headers.add(name: "Connection", value: "close")
    headers.add(name: "Content-Length", value: "0")
    let head = HTTPResponseHead(version: .http1_1,
                                status: .methodNotAllowed,
                                headers: headers)
    context.write(wrapOutboundOut(.head(head)), promise: nil)
    context.write(wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
      context.close(promise: nil)
    }
    context.flush()
  }
}
