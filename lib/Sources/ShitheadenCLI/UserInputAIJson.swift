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
  let reader: (() async throws -> MultiplayerRequest)
  let renderHandler: ((GameSnapshot, PlayerError?) async -> Void)

  required init() {
    fatalError()
  }

  init(
    id: UUID,
    reader: @escaping (() async throws -> MultiplayerRequest),
    renderHandler: @escaping ((GameSnapshot, PlayerError?) async -> Void)
  ) {
    self.id = id
    self.reader = reader
    self.renderHandler = renderHandler
  }

  func render(snapshot: GameSnapshot, error: PlayerError?) async -> Void {
    await self.renderHandler(snapshot, error)
  }

  func beginMove(request: TurnRequest, previousError: PlayerError?) async throws -> (Card, Card, Card) {
//    do {
      let string = try await reader()
      guard case .cards(let cards) = string else {
        throw PlayerError(text: "no cards")
      }

      guard cards.count == 3 else {
        throw PlayerError(text: "no 3 choices")
      }

      let card1 = request.handCards[cards[0] - 1]
      let card2 = request.handCards[cards[1] - 1]
      let card3 = request.handCards[cards[2] - 1]

      return (card1, card2, card3)



      //    guard let data = string.data(using: .utf8) else {
      //      throw PlayerError(text: "data not parsable")
      //    }
      //
      //    return try JSONDecoder().decode(T.self, from: data)



//      guard data.count == 3 else {
//        throw PlayerError(text: "no 3 choices")
//      }
//
//      return (data[0], data[1], data[2])
//    } catch {
//      print(error)
//      return try await beginMove(request: request, previousError: previousError)
//    }
  }

  func move(request: TurnRequest, previousError: PlayerError?) async throws -> Turn {
//    do {
      let string = try await reader()

      let turn: Turn
      switch string {
      case .string(let string):
        if string.contains("p") {
          turn = .pass
        } else {
          throw PlayerError(text: "String not recognized")
        }

      case .cards(let keuze):


        switch request.phase {
        case .hand:
          let elements = request.handCards.lazy.enumerated().filter {
            keuze.contains($0.offset + 1)
          }.map { $0.element }

          if elements.count > 1, !elements.sameNumber() {
            throw PlayerError(text: "Je moet kaarten met dezelfde nummers opgeven")
          }
          turn = .play(Set(elements)) // .sortSymbol()))

        case .tableClosed:
          if keuze.count != 1 {
            throw PlayerError(text: "Je kan maar 1 kaart spelen")
          }

          guard let i = (1 ... request.numberOfClosedTableCards).first(where: {
            $0 == keuze.first
          }) else {
            throw PlayerError(text: "Deze kaart kan je niet spelen")
          }

          turn = .closedCardIndex(i)

        case .tableOpen:
          turn = .play(Set(request.openTableCards.lazy.enumerated().filter {
            keuze.contains($0.offset + 1)
          }.map { $0.element }))
        }


      default:
        throw PlayerError(text: "wut??")
      }

      return turn
//    } catch {
//      return try await move(request: request, previousError: (error as? PlayerError) ?? previousError)
//    }
  }
}
