//
//  RenderCard.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Foundation

public enum RenderCard: Equatable, Hashable, Codable, Comparable {
  case hidden(id: UUID)
  case card(card: Card)

  init(_ card: Card) {
    self = .card(card: card)
  }

  public var card: Card? {
    switch self {
    case let .card(card):
      return card
    case .hidden:
      return nil
    }
  }

  public static func < (lhs: RenderCard, rhs: RenderCard) -> Bool {
    switch (lhs, rhs) {
    case let (.card(l), .card(r)):
      return l < r
    case (.hidden, .card):
      return true
    case (.card, .hidden(_)):
      return false
    case let (.hidden(l), .hidden(r)):
      return l.uuidString < r.uuidString
    }
  }
}

public extension Array where Element == RenderCard {
  init(open cards: [Card]) {
    self.init(cards.map { RenderCard.card(card: $0) })
  }

  init(open cards: [Card], limit: Int) {
    self
      .init(cards.dropLast(limit).map { RenderCard.hidden(id: $0.id) } + cards.suffix(limit)
              .map { RenderCard.card(card: $0) })
  }

  init(obscured cards: [Card]) {
    self.init(cards.map { RenderCard.hidden(id: $0.id) })
  }

//  init(_ count: Int) { // TODO: remove!
//    self.init((0 ..< count).map { _ in .hidden(id: UUID()) })
//  }

  func unobscure() -> [Card] {
    return flatMap { $0.card }
  }
}

public extension Array where Element == RenderCard {
  func sortNumbers() -> [RenderCard] {
    return sorted {
      $0 < $1
    }
  }
}
