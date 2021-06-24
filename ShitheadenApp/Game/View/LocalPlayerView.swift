//
//  LocalPlayerView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared
import SwiftUI

struct LocalPlayerView: View {
  let closedCards: [RenderCard]
  let phase: Phase?
  let error: String?
  let cards: [RenderCard]
  let selectedCards: Set<RenderCard>
  let isOnTurn: Bool
  let canPass: Bool

  let playClosedCard: (Int) -> Void
  let select: (Set<RenderCard>, Bool) -> Void
  let play: () -> Void

  var body: some View {
    VStack {

        Text(isOnTurn ? "Explain turn!" : " ")

      if let error = error {
        Text(error)
          .bold()
          .foregroundColor(Color.red)
          .onAppear {
            print("HEAVY HAPTIC!!")
            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
            impactHeavy.impactOccurred()
          }
      }

      HStack {
        if !closedCards.isEmpty,
           phase == .tableClosed
        {
          HStack {
            ForEach(Array(closedCards.enumerated()), id: \.element) { i in
              Button(action: {
                playClosedCard(i.offset)
              }, label: {
                CardView(card: i.element)
              }).buttonStyle(PlainButtonStyle())
            }
          }
          Spacer()
        } else {
          ScrollView(.horizontal) {
            CardWaverView(
              cards: cards,
              orientation: .horizontal,
              selectedCards: selectedCards,
              select: select
            )
            .padding(5)
          }

          Spacer()

          Button(action: {
            play()
          }, label: {
            if selectedCards.count > 0 {
              Text("SPEEL!")
            } else if canPass {
              Text("PAS!")
            } else {
              Text("SPEEL!").disabled(true)
            }
          })
            .disabled(!isOnTurn)
            .onChange(of: isOnTurn, perform: {
              if $0 {
                print("HAPTIC!!")
                let impactHeavy = UIImpactFeedbackGenerator(style: .light)
                impactHeavy.impactOccurred()
              }
            })
        }
      }
    }.padding().background(Color.white)
  }
}
