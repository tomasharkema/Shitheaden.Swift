//
//  AppInputUserInputAI.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared

actor AppInputUserInputAI: GameAi {
  let beginMoveHandler: (@escaping ((Card, Card, Card)) async -> Void) async -> Void
  let moveHandler: (Bool, @escaping (Turn) async -> Void) async -> Void
  let errorHandler: (String) async -> Void
  let renderHandler: (GameSnapshot) async throws -> Void

  init() {
    beginMoveHandler = { _ in }
    moveHandler = { _, _ in }
    errorHandler = { _ in }
    renderHandler = { _ in }
  }

  static func make() -> GameAi {
    AppInputUserInputAI()
  }

  init(
    beginMoveHandler: @escaping (@escaping ((Card, Card, Card)) async -> Void) async -> Void,
    moveHandler: @escaping (Bool, @escaping (Turn) async -> Void) async -> Void,
    errorHandler: @escaping (String) async -> Void,
    renderHandler: @escaping (GameSnapshot) async -> Void
  ) {
    self.beginMoveHandler = beginMoveHandler
    self.moveHandler = moveHandler
    self.errorHandler = errorHandler
    self.renderHandler = renderHandler
  }

  func render(snapshot: GameSnapshot) async throws {
//    if let e = snap {
//      await errorHandler(e.errorDescription ?? e.localizedDescription)
//    }

    try await renderHandler(snapshot)
  }

  func beginMove(request: TurnRequest, snapshot _: GameSnapshot) async -> (Card, Card, Card) {
    if let error = request.playerError {
      await errorHandler(error.errorDescription ?? error.localizedDescription)
    }

    return await withCheckedContinuation { cont in
      Task {
        await beginMoveHandler {
          cont.resume(returning: $0)
        }
      }
    }
  }

  func move(request: TurnRequest, snapshot _: GameSnapshot) async -> Turn {
    if let error = request.playerError {
      await errorHandler(error.errorDescription ?? error.localizedDescription)
    }

    return await withCheckedContinuation { cont in
      Task {
        await moveHandler(request.canPass) {
          cont.resume(returning: $0)
        }
      }
    }
  }
}
