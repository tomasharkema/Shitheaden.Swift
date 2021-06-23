//
//  UserInputAIJson.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import Foundation
import ShitheadenShared

actor UserInputAIJson: GameAi {
  let id: UUID
  let reader: (Action, PlayerError?) async throws -> MultiplayerRequest
  let renderHandler: (GameSnapshot) async -> Void

  required init() {
    fatalError()
  }

  init(
    id: UUID,
    reader: @escaping ((Action, PlayerError?) async throws -> MultiplayerRequest),
    renderHandler: @escaping ((GameSnapshot) async -> Void)
  ) {
    self.id = id
    self.reader = reader
    self.renderHandler = renderHandler
  }

  func render(snapshot: GameSnapshot) async {
    await renderHandler(snapshot)
  }

  func beginMove(request: TurnRequest) async throws -> (Card, Card, Card)
  {
//    do {
    let string = try await reader(.requestBeginTurn, request.playerError)

    switch string {
    case let .cardIndexes(cards):
      guard cards.count == 3 else {
        throw PlayerError.cardsCount(3)
      }
      let hand = request.handCards.unobscure()
      let card1 = hand[cards[0] - 1]
      let card2 = hand[cards[1] - 1]
      let card3 = hand[cards[2] - 1]

      print("CONCRETE CARDS", (card1, card2, card3))
      return (card1, card2, card3)
    case let .concreteCards(cards):
      guard cards.count == 3 else {
        throw PlayerError.cardsCount(3)
      }
      print("CONCRETE CARDS", (cards[0], cards[1], cards[2]))
      return (cards[0], cards[1], cards[2])

    default:
      throw PlayerError.debug("Only cardIndexes or concreteCards permitted")
    }
  }

  func move(request: TurnRequest) async throws -> Turn {
//    do {
    let string = try await reader(.requestNormalTurn, request.playerError)

    let turn: Turn
    switch string {
    case let .string(string):
      if string.contains("p") {
        turn = .pass
      } else {
        throw PlayerError
          .inputNotRecognized(input: string,
                              hint: "voer p in om te passen.") // PlayerError(text: "String not recognized")
      }

    case let .cardIndexes(keuze):

      switch request.phase {
      case .hand:
        let elements = request.handCards.unobscure().lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }

        if elements.count > 1, !elements.sameNumber() {
          throw PlayerError.sameNumber // (text: "Je moet kaarten met dezelfde nummers opgeven")
        }
        turn = .play(Set(elements)) // .sortSymbol()))

      case .tableClosed:
        if keuze.count != 1 {
          throw PlayerError.cardsCount(1)
        }

        guard let int = keuze.first, let i = (1 ... request.closedCards.count).first(where: {
          $0 == int
        }) else {
          throw PlayerError.closedNumberNotInRange(
            choice: keuze.first,
            range: request.closedCards.count
          )
//          throw PlayerError.cardNotPlayable(played: <#T##Card#>, on: <#T##Card#>)//(text: "Deze kaart kan je niet spelen")
        }

        turn = .closedCardIndex(i)

      case .tableOpen:
        turn = .play(Set(request.openTableCards.unobscure().lazy.enumerated().filter {
          keuze.contains($0.offset + 1)
        }.map { $0.element }))
      }

    case let .concreteTurn(t):
      turn = t

    default:
      throw PlayerError.debug("Only string or cardIndexes or turn permitted")
    }
    print("TURN", turn)
    return turn
//    } catch {
//      return try await move(request: request, previousError: (error as? PlayerError) ?? previousError)
//    }
  }
}
