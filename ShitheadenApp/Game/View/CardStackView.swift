//
//  CardStackView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared
import SwiftUI

struct CardStackView: View {
  let cards: [RenderCard]
  let offset: CGFloat
  let numberOfCardsExtraSpace: Int
  let alignment = Alignment.center

  private func offsetCalc(_ number: CGFloat) -> CGFloat {
    (min(number, CGFloat(numberOfCardsExtraSpace) - 1) * offset) +
      (max(0, number - (CGFloat(numberOfCardsExtraSpace) - 1)) * offset * 0.1)
  }

  var body: some View {
    let cardsArray = Array(cards)
    ZStack(alignment: alignment) {
      ForEach(Array(cardsArray.enumerated()), id: \.element) { el in
        CardView(card: el.element)
          .offset(
            x: CGFloat(el.offset) + offsetCalc(CGFloat(el.offset)),
            y: CGFloat(-el.offset) - offsetCalc(CGFloat(el.offset))
          )
          .zIndex(Double(10 - el.offset))
      }
    }
  }
}

// extension EnumeratedSequence where Base == Array<RenderCard> {
//  var id: String {
//
//  }
// }
