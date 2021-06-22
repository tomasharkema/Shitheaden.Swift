//
//  Renderer.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//

import Foundation
import ShitheadenRuntime
import ShitheadenShared

extension TurnRequest {
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
  static func error(error: PlayerError) -> String {
    return RenderPosition.input.down(n: 1)
      .cliRep + error.text
  }

  static func render(game: GameSnapshot, error: PlayerError?) async -> String {
    let playersString: [String] = game.players.flatMap { player -> [String] in
      if !player.done {
        return [
          player.renderPosition >>> "\(player.name) \(player.handCards.count) kaarten",
//          player.renderPosition.down(n: 1) >>> player.latestState,
          player.renderPosition.down(n: 2) >>> player.showedTable,
          player.renderPosition.down(n: 3) >>> "\(player.closedCards.count)",
        ]
      } else {
        return [player.renderPosition >>> "\(player.name) KLAAR"]
      }
    }

    let userPlayer = game.players.first { !$0.isObscured }
    let handString = userPlayer?.handCards.unobscure().sortNumbers().enumerated()
      .map { "\($0.offset + 1)\($0.element.description)" }.joined(separator: " ")

    let hand = handString != nil ? RenderPosition.hand >>> "Hand: \(handString!)" : ""

    let status: String
    if let userPlayer = userPlayer, game.playerOnTurn == userPlayer.id {
      switch userPlayer.phase {
      case .hand:
        status = (RenderPosition.input.cliRep +
          "Speel een kaart uit je hand")
      case .tableOpen:
        status = (RenderPosition.input.cliRep +
          "Speel een kaart van tafel")
      case .tableClosed:
        status = (RenderPosition.input.cliRep +
          "Speel een kaart van je dichte stapel")
      }
    } else {
      status = ""
    }

    let error = error.map {
      RenderPosition.input.down(n: 1)
        .cliRep + $0.text
    } ?? "" // ?? RenderPosition.input.down(n: 1)
//      .cliRep + "                                          "

    let strings: [[String]] = [
      [
        CLI.setBackground(),
        CLI.clear(),
        RenderPosition.header.down(n: 1) >>> " Shitheaden",
        RenderPosition.header.down(n: 3) >>> " Deck: \(game.deckCards.count) kaarten",
        RenderPosition.header.down(n: 4) >>> " Burnt: \(game.burntCards.count) kaarten",
        RenderPosition.tafel >>> game.tableCards.unobscure().map { $0.description }
          .joined(separator: " "),
        RenderPosition.tafel.down(n: 1) >>> "\(game.tableCards.count)",
        hand,
        status,
        error,
      ],
      playersString,
    ]

    return strings.joined().joined(separator: "\n")
  }
}
