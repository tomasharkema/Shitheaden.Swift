//
//  PlayerView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared
import SwiftUI

struct PlayerView: View {
  let player: TurnRequest
  let orientation: Orientation
  let playerOnTurn: Bool

  var body: some View {
    if !player.done {
      VStack {
        OrientationStack(orientation: orientation) {
          CardWaverView(
            cards: player.closedCards,
            orientation: orientation,
            selectedCards: [],
            select: nil
          )
          .foregroundColor(.white)
          .overlay(
            CardWaverView(
              cards: player.openTableCards,
              orientation: orientation,
              selectedCards: [],
              select: nil
            )
            .offset(x: orientation == .vertical ? 5 : 0, y: orientation == .vertical ? 0 : -5)
          )

          CardStackView(cards: player.handCards, offset: 2)
        }
      }
      .padding()
      .background(playerOnTurn ? Color.green.opacity(1) : Color
        .green
        .opacity(0.3)).cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(Color.green, lineWidth: 5)
      )
    }
  }
}
