//
//  PlayerError.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import Foundation

public enum PlayerError: LocalizedError, Codable, Equatable {
  case notEmpty
  case cardsCount(Int)
  case sameNumber
  case closedNumberNotInRange(choice: Int?, range: Int)
  case cardNotPlayable(played: Card, on: Card)
  case notSameNumber
  case turnNotPossible(turn: Turn)
  case closedCardFailed(Card)
  case closedOneCard
  case openCardsThreeCards
  case cardNotInHand

  case inputNotRecognized(input: String, hint: String?)

  case integrityDoubleCardEncountered
  case integrityCardCount

  case unknown
  case debug(String)

  public var errorDescription: String? {
    switch self {
    case .notEmpty:
      return "Je moet een aantal kaarten spelen..."
    case let .cardsCount(int):
      return "Je moet \(int) kaarten kiezen..."
    case .sameNumber:
      return "Je moet kaarten met dezelfde nummers spelen"
    case let .closedNumberNotInRange(choice, range):
      if range > 1 {
        return "Je hebt maar \(range) kaarten." + (choice.map { " Kaart \($0) kan niet." } ?? "")
      } else {
        return "Je kan alleen maar 1 kaart spelen"
      }
    case let .cardNotPlayable(played, on):
      return "Je kan \(played) niet spelen op \(on)"
    case .notSameNumber:
      return "Je kunt alleen kaarten met hetzelfde nummer opgeven."
    case let .turnNotPossible(turn):
      return turn.explain + " niet mogelijk."
    case let .closedCardFailed(card):
      return "Je dichte kaart was \(card)... Je mag opnieuw!"
    case .openCardsThreeCards:
      return "Je moet 3 kaarten spelen"
    case .closedOneCard:
      return "Je kan maar 1 kaart spelen"

    case .integrityDoubleCardEncountered:
      return "DUBBELE KAART!"

    case .integrityCardCount:
      return "NOT 52 CARDS!"

    case let .inputNotRecognized(input, hint):
      return "'\(input)' is niet herkend." + (hint.map { " \($0)" } ?? "")

    case .cardNotInHand:
      return "Kaart is niet beschikbaar"

    case .unknown:
      return "shrug"

    case let .debug(text):
      return text
    }
  }
}
