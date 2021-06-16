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
  static let algoName = "UserInputAI"

  let reader: () async -> String
  let render: (String) async -> Void
  required init() {
    reader = {
      await Keyboard.getKeyboardInput()
    }
    render = { print($0) }
  }

  init(reader: @escaping (() async -> String), render: @escaping ((String) async -> Void)) {
    self.reader = reader
    self.render = render
  }

  private func parseInput(input: String) async -> [Int]? {
    let inputs = input.split(separator: ",").map {
      Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    if inputs.contains(nil) {
      await render(Position.input.down(n: 1).cliRep + ANSIEscapeCode.Erase
        .eraseInLine(.entireLine) + "Je moet p of een aantal cijfers invullen...")
      return nil
    }

    return inputs.map { $0! }
  }

  private func printHand(request: TurnRequest) async {
    let handString = request.handCards.enumerated()
      .map { "\($0.offset + 1)\($0.element.description)" }.joined(separator: " ")

    await render(Position.hand >>> "Hand: \(handString)")
  }

  private func getBeurtFromUser(request: TurnRequest) async throws -> Turn {
    await printHand(request: request)
//    #if DEBUG
//    await render(Position.input.down(n: 5).cliRep + ANSIEscapeCode.Erase.eraseInLine(.entireLine) + "\(request.possibleTurns())")
//    #endif
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

  func execute(request: TurnRequest) async -> Turn? {
    switch request.phase {
    case .hand:
      await render(Position.input.cliRep + ANSIEscapeCode.Erase.eraseInLine(.entireLine) +
        "Speel een kaart uit je hand")
    case .tableOpen:
      await render(Position.input.cliRep + ANSIEscapeCode.Erase.eraseInLine(.entireLine) +
        "Speel een kaart van tafel")
    case .tableClosed:
      await render(Position.input.cliRep + ANSIEscapeCode.Erase.eraseInLine(.entireLine) +
        "Speel een kaart van je dichte stapel")
    }

    do {
      return try await getBeurtFromUser(request: request)
    } catch {
      await render(Position.input
        .down(n: -2) >>> ((error as? PlayerError)?.text ?? error.localizedDescription))
      return nil
    }
  }

  func move(request: TurnRequest, previousError: PlayerError?) async -> Turn {
    if let previousError = previousError {
      await render(Position.input
        .down(n: -2) >>> previousError.text)
    }

    if let res = await execute(request: request) {
      return res
    } else {
      return await move(request: request, previousError: previousError)
    }
  }

  func getInput() async -> String {
    await render(ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
      row: Position.input.y + 1,
      column: 0
    ) + ANSIEscapeCode.Erase.eraseInLine(.entireLine))
    let request = await reader().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    await render(ANSIEscapeCode.Cursor.hideCursor)
    return request
  }

  func beginMove(request: TurnRequest, previousError: PlayerError?) async -> (Card, Card, Card) {
    if let previousError = previousError {
      await render(Position.input
        .down(n: -2).cliRep + ANSIEscapeCode.Erase.eraseInLine(.entireLine) + previousError.text)
    }

    do {
      await printHand(request: request)

      await render(Position.input.cliRep + ANSIEscapeCode.Erase
        .eraseInLine(.entireLine) + "Selecteer drie kaarten voor je tafelkaarten...")

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