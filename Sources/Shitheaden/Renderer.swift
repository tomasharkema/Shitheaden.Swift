//
//  Renderer.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//

import Foundation
import ShitheadenRuntime
import ShitheadenShared

class Renderer {
  static func render(game: Game, clear: Bool) async -> String {
    let playersString: [String] = await game.players.flatMap { player -> [String] in
      if !player.done {
        return [
          player.position >>> "\(player.name) \(player.handCards.count) kaarten",
          player.position.down(n: 1) >>> player.latestState,
          player.position.down(n: 2) >>> player.showedTable,
          player.position.down(n: 3) >>> player.closedTable,
        ]
      } else {
        return [player.position >>> "\(player.name) KLAAR"]
      }
    }

    let strings: [[String]] = [
      [
        CLI.setBackground(),
        clear ? CLI.clear() : "",
        Position.header.down(n: 1) >>> " Shitheaden",
        await Position.header.down(n: 3) >>> " Deck: \(game.deck.cards.count) kaarten",
        await Position.header.down(n: 4) >>> " Burnt: \(game.burnt.count) kaarten",
        await Position.tafel >>> game.table.suffix(5).map { $0.description }.joined(separator: " "),
      ],
      playersString,
    ]

    return strings.joined().joined(separator: "\n") + "\n"
  }
}
