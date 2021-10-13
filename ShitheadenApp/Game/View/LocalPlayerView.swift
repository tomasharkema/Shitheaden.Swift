//
//  LocalPlayerView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Logging
import ShitheadenShared
import SwiftUI

struct LocalPlayerView: View {
  let logger = Logger(label: "app.LocalPlayerView")

  let closedCards: [RenderCard]
  let phase: Phase?
  let error: String?
  let cards: [RenderCard]
  let selectedCards: [RenderCard]
  let isOnTurn: Bool
  let canPass: Bool
  let explain: String?

  let playClosedCard: (Int) -> Void
  let select: ([RenderCard], Bool) -> Void
  let play: () -> Void

  @State var hasLongPressed = false

  var body: some View {
    VStack {
      Text(isOnTurn ? explain ?? " " : " ")
        .font(.system(.body, design: .rounded))
        .foregroundColor(.black)

      if let error = error {
        Text(error)
          .font(.system(.body, design: .rounded))
          .bold()
          .foregroundColor(Color.red)
          .onAppear {
            logger.debug("HEAVY HAPTIC!!")
            let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
            impactHeavy.impactOccurred()
          }
      }

      HStack {
        if !closedCards.isEmpty,
           phase == .tableClosed
        {
          HStack {
            ForEach(Array(closedCards.enumerated()), id: \.element) { closedCard in
              Button(action: {
                playClosedCard(closedCard.offset)
              }, label: {
                CardView(card: closedCard.element)
              }).buttonStyle(PlainButtonStyle())
            }
          }
          .padding(5)
          Spacer()
        } else {
          LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 40, maximum: 60), spacing: -10),
          ],
          spacing: -50) {
            ForEach(Array(cards.enumerated()), id: \.element) { index, card in
              HStack {
                if let select = select {
                  StatedButton(
                    action: { selected in
                      if !hasLongPressed {
                        select([card], selected)
                      }
                      hasLongPressed = false
                    }, label: {
                      CardView(card: card)
                    }, isSelected: selectedCards.contains(card)
                  )
                  .simultaneousGesture(LongPressGesture().onEnded {
                    if $0 {
                      hasLongPressed = true
                      select(cards.filter { $0.card?.number == card.card?.number }, true)
                    }
                  })
                  .buttonStyle(PlainButtonStyle())
                } else {
                  CardView(card: card)
                }
              }.zIndex(Double(-index))
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.trailing, 110)
          .overlay(Button(action: {
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
          .buttonStyle(.bordered)
          .controlSize(.large)
          .disabled(!isOnTurn)
          .onChange(of: isOnTurn, perform: {
            if $0 {
              logger.debug("HAPTIC!!")
              let impactHeavy = UIImpactFeedbackGenerator(style: .light)
              impactHeavy.impactOccurred()
            }
          }), alignment: .trailing)
        }
      }
    }.padding()
      .background(isOnTurn ? Color.green.opacity(0.3) : Color.green.opacity(0))
      .background(Color.white)
  }
}
