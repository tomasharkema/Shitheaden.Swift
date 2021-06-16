//
//  UserInputAI.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 31-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import Shitheaden
import ShitheadenShared

struct PlayerError: LocalizedError {
  let text: String

  var errorDescription: String? {
    text
  }
}

actor UserInputAI: GameAi {
  static let algoName = "UserInputAI"

  required init() {}

  private func getBeurtFromUser(request: TurnRequest) async throws -> Turn {
    let kaartenString = request.handCards.map { $0.description }.joined(separator: " ")

    let handString = request.handCards.enumerated()
      .map { "\($0.offset + 1)\($0.element.description)" }.joined(separator: " ")

//    let possibleTurns = player.possibleTurns(table: table)
//    Position.debug >>> String("\(possibleTurns)")

    Position.hand >>> "Hand:  \(handString)"
    Position.input >>>
      "Maak je keuze: Type '11' om kaart 1 te pakken, en kaart 1 te gooien. Type 'p' om te passen. Type 'w' om alle kaarten met de tafel te wisselen."

    let input = await Keyboard.getKeyboardInput()

    let executeTurn: Turn
    if input == "p" {
      executeTurn = .pass
    } else if let keuze = Keyboard.getKeuzeFromInput(input: input) {
      guard keuze.count > 0 else {
        throw PlayerError(text: "Je moet meer dan 1 keuze opgeven.")
      }

      switch request.phase {
      case .hand:

        executeTurn = .play(Set(request.handCards.lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }))
      case .putOnTable:

        if keuze.count != 3 {
          throw PlayerError(text: "not implemented")
        }
        let cards = request.handCards.lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }
        executeTurn = .putOnTable(cards[0], cards[1], cards[2])

      case .tableClosed:
        if keuze.count != 1 {
          throw PlayerError(text: "Je kan maar 1 kaart spelen")
        }

        guard let i = (1...request.numberOfClosedTableCards).first(where: {
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

//    if request.possibleTurns.contains(executeTurn) {
      return executeTurn
//    } else {
//      throw PlayerError(text: "\(executeTurn) is not in \(request.possibleTurns) phase: \(request.phase)")
//    }
  }

  func execute(request: TurnRequest) async -> Turn? {
    do {
      return try await getBeurtFromUser(request: request)
    } catch {
      Position.input.down(n: -2) >>> error.localizedDescription
      return nil
    }
  }

func move(request: TurnRequest) async -> Turn {
  if let res = await execute(request: request) {
    return res
  } else {
    return await move(request: request)
  }
}

}
