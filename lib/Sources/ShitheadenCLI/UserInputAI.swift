//
//  UserInputAI.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 31-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ANSIEscapeCode
import Foundation
import ShitheadenRuntime
import ShitheadenShared

actor _UserInputAI: GameAi {
  let id: UUID
  let reader: () async -> String
  let renderHandler: (String) async -> Void

  required init() {
    id = UUID()
    reader = {
      await Keyboard.getKeyboardInput()
    }
    renderHandler = { print($0) }
  }

  init(
    id: UUID
  ) {
    self.id = id
    reader = {
      await Keyboard.getKeyboardInput()
    }
    renderHandler = { print($0) }
  }

  init(
    id: UUID,
    reader: @escaping (() async -> String),
    renderHandler: @escaping ((String) async -> Void)
  ) {
    self.id = id
    self.reader = reader
    self.renderHandler = renderHandler
  }

  func render(snapshot: GameSnapshot) async {
    await renderHandler(Renderer.render(game: snapshot))
  }

  private func parseInput(input: String) async -> [Int]? {
    let inputs = input.split(separator: ",").map {
      Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if inputs.contains(nil) {
      await renderHandler(RenderPosition.input.down(n: 1)
        .cliRep + "Je moet p of een aantal cijfers invullen...")
      return nil
    }

    return inputs.map { $0! }
  }

  private func getBeurtFromUser(request: TurnRequest) async throws -> Turn {
    #if DEBUG
      await renderHandler(RenderPosition.input.down(n: 5).cliRep + "\(request.possibleTurns())")
    #endif

    let input = await getInput()

    let executeTurn: Turn
    if input == "p" {
      executeTurn = .pass
    } else if let keuze = await parseInput(input: input) {
      guard keuze.count > 0 else {
        throw PlayerError.openCardsThreeCards
      }

      switch request.phase {
      case .hand:
        let elements = request.handCards.unobscure().lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }

        if elements.count > 1, !elements.sameNumber() {
          throw PlayerError.sameNumber
        }
        executeTurn = .play(Set(elements)) // .sortSymbol()))

      case .tableClosed:
        if keuze.count != 1 {
          throw PlayerError.closedOneCard
        }

        guard let i = (1 ... request.closedCards.count).first(where: {
          $0 == keuze.first
        }) else {
          throw PlayerError.closedNumberNotInRange(
            choice: keuze.first,
            range: request.closedCards.count
          )
        }

        executeTurn = .closedCardIndex(i)

      case .tableOpen:
        executeTurn = .play(Set(request.openTableCards.unobscure().lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }))
      }

    } else {
      assertionFailure("Unknown Error")
      throw PlayerError.unknown
    }

    return executeTurn
  }

  func execute(request: TurnRequest) async throws -> Turn {
    switch request.phase {
    case .hand:
      await renderHandler(RenderPosition.input.cliRep +
        "Speel een kaart uit je hand")
    case .tableOpen:
      await renderHandler(RenderPosition.input.cliRep +
        "Speel een kaart van tafel")
    case .tableClosed:
      await renderHandler(RenderPosition.input.cliRep +
        "Speel een kaart van je dichte stapel")
    }

//    do {
    return try await getBeurtFromUser(request: request)
//    } catch {
//      await render(RenderPosition.input
//        .down(n: -2) >>> ((error as? PlayerError)?.text ?? error.localizedDescription))
//      return nil
//    }
  }

  func move(request: TurnRequest) async throws -> Turn {
    if let error = request.playerError {
      await renderHandler(RenderPosition.input
        .down(n: -2) >>> (error.errorDescription ?? error.localizedDescription))
    }

    return try await execute(request: request)

//    if let res = await execute(request: request) {
//      return try await execute(request: request)
//    } else {
//      return await move(request: request)
//    }
  }

  func getInput() async -> String {
    await renderHandler(ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
      row: RenderPosition.input.y + 1,
      column: 0
    ))
    let request = await reader().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    await renderHandler(ANSIEscapeCode.Cursor.hideCursor)
    return request
  }

  func beginMove(request: TurnRequest) async throws -> (Card, Card, Card) {
    if let error = request.playerError {
      await renderHandler(RenderPosition.input
        .down(n: -2).cliRep + (error.errorDescription ?? error.localizedDescription))
    }

    await renderHandler(RenderPosition.input
      .cliRep + "Selecteer drie kaarten voor je tafelkaarten...")
    await renderHandler(RenderPosition.input.down(n: 1).cliRep)

    let input = await getInput()
    guard let keuze = await parseInput(input: input) else {
      throw PlayerError.inputNotRecognized(input: input, hint: nil)
    }

    guard keuze.count == 3 else {
      throw PlayerError.openCardsThreeCards
    }
    let cards = request.handCards.unobscure().lazy.enumerated().filter {
      keuze.contains($0.offset + 1)
    }.map { $0.element } // .sortSymbol()

    return (cards[0], cards[1], cards[2])
  }
}
