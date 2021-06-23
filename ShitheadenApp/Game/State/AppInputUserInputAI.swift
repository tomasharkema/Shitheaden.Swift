//
//  AppInputUserInputAI.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared

actor AppInputUserInputAI: GameAi {
  let beginMoveHandler: (@escaping ((Card, Card, Card)) async -> Void) async -> Void
  let moveHandler: (@escaping (Turn) async -> Void) async -> Void
  let errorHandler: (String) async -> Void
  let renderHandler: (GameSnapshot) async -> Void

  required init() {
    beginMoveHandler = { _ in }
    moveHandler = { _ in }
    errorHandler = { _ in }
    renderHandler = { _ in }
  }

  init(
    beginMoveHandler: @escaping (@escaping ((Card, Card, Card)) async -> Void) async -> Void,
    moveHandler: @escaping (@escaping (Turn) async -> Void) async -> Void,
    errorHandler: @escaping (String) async -> Void,
    renderHandler: @escaping (GameSnapshot) async -> Void
  ) {
    self.beginMoveHandler = beginMoveHandler
    self.moveHandler = moveHandler
    self.errorHandler = errorHandler
    self.renderHandler = renderHandler
  }

  func render(snapshot: GameSnapshot) async {
//    if let e = snap {
//      await errorHandler(e.errorDescription ?? e.localizedDescription)
//    }

    await renderHandler(snapshot)
  }

  func beginMove(request: TurnRequest) async -> (Card, Card, Card) {
    if let e = request.playerError {
      await errorHandler(e.errorDescription ?? e.localizedDescription)
    }

    return await withUnsafeContinuation { g in
      async {
        await beginMoveHandler {
          g.resume(returning: $0)
        }
      }
    }
  }

  func move(request: TurnRequest) async -> Turn {
    if let e = request.playerError {
      await errorHandler(e.errorDescription ?? e.localizedDescription)
    }

    return await withUnsafeContinuation { g in
      async {
        await moveHandler {
          g.resume(returning: $0)
        }
      }
    }
  }
}
