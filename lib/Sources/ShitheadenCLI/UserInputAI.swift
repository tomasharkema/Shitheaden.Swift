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

actor UserInputAI: GameAi {
  let id: UUID
  let reader: () async -> String
  let render: (String) async -> Void

  required init() {
    id = UUID()
    reader = {
      await Keyboard.getKeyboardInput()
    }
    render = { print($0) }
  }

  init(
    id: UUID
  ) {
    self.id = id
    reader = {
      await Keyboard.getKeyboardInput()
    }
    render = { print($0) }
  }

  init(
    id: UUID,
    reader: @escaping (() async -> String),
    render: @escaping ((String) async -> Void)
  ) {
    self.id = id
    self.reader = reader
    self.render = render
  }

  private func parseInput(input: String) async -> [Int]? {
    let inputs = input.split(separator: ",").map {
      Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if inputs.contains(nil) {
      await render(RenderPosition.input.down(n: 1)
        .cliRep + "Je moet p of een aantal cijfers invullen...")
      return nil
    }

    return inputs.map { $0! }
  }

  private func getBeurtFromUser(request: TurnRequest) async throws -> Turn {
    #if DEBUG
      await render(RenderPosition.input.down(n: 5).cliRep + "\(request.possibleTurns())")
    #endif

    let input = await getInput()

    let executeTurn: Turn
    if input == "p" {
      executeTurn = .pass
    } else if let keuze = await parseInput(input: input) {
      guard keuze.count > 0 else {
        throw PlayerError(text: "Je moet meer dan 1 keuze opgeven.")
      }

      switch request.phase {
      case .hand:
        let elements = request.handCards.lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }

        if elements.count > 1, !elements.sameNumber() {
          throw PlayerError(text: "Je moet kaarten met dezelfde nummers opgeven")
        }
        executeTurn = .play(Set(elements)) // .sortSymbol()))

      case .tableClosed:
        if keuze.count != 1 {
          throw PlayerError(text: "Je kan maar 1 kaart spelen")
        }

        guard let i = (1 ... request.numberOfClosedTableCards).first(where: {
          $0 == keuze.first
        }) else {
          throw PlayerError(text: "Deze kaart kan je niet spelen")
        }

        executeTurn = .closedCardIndex(i)

      case .tableOpen:
        executeTurn = .play(Set(request.openTableCards.lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }))
      }

    } else {
      throw PlayerError(text: "not implemented")
    }

    return executeTurn
  }

  func execute(request: TurnRequest) async throws -> Turn {
    switch request.phase {
    case .hand:
      await render(RenderPosition.input.cliRep +
        "Speel een kaart uit je hand")
    case .tableOpen:
      await render(RenderPosition.input.cliRep +
        "Speel een kaart van tafel")
    case .tableClosed:
      await render(RenderPosition.input.cliRep +
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

  func move(request: TurnRequest, previousError: PlayerError?) async -> Turn {
    if let previousError = previousError {
      await render(RenderPosition.input
        .down(n: -2) >>> previousError.text)
    }
    do {
      return try await execute(request: request)
    } catch {
      return await move(request: request, previousError: previousError)
    }
//    if let res = await execute(request: request) {
//      return try await execute(request: request)
//    } else {
//      return await move(request: request, previousError: previousError)
//    }
  }

  func getInput() async -> String {
    await render(ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
      row: RenderPosition.input.y + 1,
      column: 0
    ))
    let request = await reader().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    await render(ANSIEscapeCode.Cursor.hideCursor)
    return request
  }

  func beginMove(request: TurnRequest, previousError: PlayerError?) async -> (Card, Card, Card) {
    if let previousError = previousError {
      await render(RenderPosition.input
        .down(n: -2).cliRep + previousError.text)
    }

    do {
      await render(RenderPosition.input.cliRep + "Selecteer drie kaarten voor je tafelkaarten...")
      await render(RenderPosition.input.down(n: 1).cliRep)

      let input = await getInput()
      guard let keuze = await parseInput(input: input) else {
        throw PlayerError(text: "Snap ik niet")
      }

      guard keuze.count == 3 else {
        throw PlayerError(text: "Je moet 3 kaarten selecteren!")
      }
      let cards = request.handCards.lazy.enumerated().filter {
        keuze.contains($0.offset + 1)
      }.map { $0.element } // .sortSymbol()

      return (cards[0], cards[1], cards[2])

    } catch {
      return await beginMove(
        request: request,
        previousError: error as? PlayerError ?? previousError
      )
    }
  }
}
