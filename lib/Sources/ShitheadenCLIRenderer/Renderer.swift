//
//  Renderer.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//

import ANSIEscapeCode
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

public enum Renderer {
  public static func error(error: PlayerError) -> String {
    RenderPosition.input.down(yAxisDown: 1)
      .cliRep + (error.errorDescription ?? error.localizedDescription)
  }

  public static func render(game: GameSnapshot) async -> String {
    let playersString: [String] = game.players.flatMap { player -> [String] in
      if !player.done {
        return [
          player.renderPosition >>> "\(player.name) \(player.handCards.count) kaarten",
//          player.renderPosition.down(yAxisDown: 1) >>> player.latestState,
          player.renderPosition.down(yAxisDown: 2) >>> player.showedTable,
          player.renderPosition.down(yAxisDown: 3) >>> "\(player.closedCards.count)",
        ]
      } else {
        return [player.renderPosition >>> "\(player.name) KLAAR"]
      }
    }

    let userPlayer = game.players.first { !$0.isObscured }
    let handString = userPlayer?.handCards.unobscure().sortedCardsHandImportance().enumerated()
      .map { "\($0.offset + 1)\($0.element.description)" }.joined(separator: " ")

    let hand = handString != nil ? RenderPosition.hand >>> "Hand: \(handString!)" : ""

    let status: String
    if let userPlayer = userPlayer, game.playersOnTurn.contains(userPlayer.id) {
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

    let cursor: String = game.playersOnTurn.contains(userPlayer?.id ?? UUID()) ? ANSIEscapeCode
      .Cursor.showCursor + ANSIEscapeCode.Cursor.position(
        row: RenderPosition.input.yAxis + 2,
        column: 0
      ) : ANSIEscapeCode.Cursor.hideCursor

    let errorString = userPlayer?.playerError.map { error(error: $0) } ?? ""

    let strings: [[String]] = [
      [
        CLI.setBackground(),
        CLI.clear(),
        RenderPosition.header.down(yAxisDown: 1) >>> " Shitheaden",
        RenderPosition.header.down(yAxisDown: 3) >>> " Deck: \(game.deckCards.count) kaarten",
        RenderPosition.header.down(yAxisDown: 4) >>> " Burnt: \(game.burntCards.count) kaarten",
        RenderPosition.tafel >>> game.tableCards.unobscure().map(\.description)
          .joined(separator: " "),
        RenderPosition.tafel.down(yAxisDown: 1) >>> "\(game.tableCards.count)",
        hand,
        status,
      ],
      playersString,
      [errorString, cursor],
    ]

    return strings.joined().joined(separator: "\n")
  }
}
