//
//  Renderer.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//

import Foundation
import ShitheadenRuntime
import ShitheadenShared

extension ObscuredPlayerResult {
  var renderPosition: RenderPosition {
    switch position {
    case .noord:
      return RenderPosition.noord
    case .oost:
      return RenderPosition.oost
    case .zuid:
      return RenderPosition.zuid
    case .west:
      return RenderPosition.west
    }
  }
}

enum Renderer {
  static func render(game: GameSnaphot, clear: Bool) async -> String {
    let playersString: [String] = await game.players.flatMap { player -> [String] in
      if !player.done {
        return [
          player.renderPosition >>> "\(player.name) \(player.numberOfHandCards) kaarten",
//          player.renderPosition.down(n: 1) >>> player.latestState,
          player.renderPosition.down(n: 2) >>> player.showedTable,
          player.renderPosition.down(n: 3) >>> "\(player.numberOfClosedTableCards)",
        ]
      } else {
        return [player.renderPosition >>> "\(player.name) KLAAR"]
      }
    }

    let userPlayer = await game.players.flatMap { $0.player }.first
    let handString = userPlayer?.handCards.sortNumbers().enumerated()
      .map { "\($0.offset + 1)\($0.element.description)" }.joined(separator: " ")

    let hand = handString != nil ? RenderPosition.hand >>> "Hand: \(handString!)" : ""

    let strings: [[String]] = [
      [
        CLI.setBackground(),
        clear ? CLI.clear() : "",
        RenderPosition.header.down(n: 1) >>> " Shitheaden",
        await RenderPosition.header.down(n: 3) >>> " Deck: \(game.deck.cards.count) kaarten",
        await RenderPosition.header.down(n: 4) >>> " Burnt: \(game.burnt.suffix(5)) kaarten",
        await RenderPosition.tafel >>> game.table.suffix(5).map { $0.description }
          .joined(separator: " "),
        await RenderPosition.tafel.down(n: 1) >>> "\(game.table.count)",
        hand,
      ],
      playersString,
    ]

    return strings.joined().joined(separator: "\n")
  }
}
