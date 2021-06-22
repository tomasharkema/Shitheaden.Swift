//
//  CardWaverView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared
import SwiftUI

struct CardWaverView: View {
  let cards: [RenderCard]
  let orientation: Orientation

  let selectedCards: Set<RenderCard>
  let select: ((RenderCard, Bool) -> Void)?

  var body: some View {
    OrientationStack(orientation: orientation, spacing: -10) {
      ForEach(Array(cards.enumerated()), id: \.element) { index, c in
        Group {
          if let select = select {
            StatedButton(
              action: { selected in
                select(c, selected)
              }, label: {
                CardView(card: c)
              }, isSelected: selectedCards.contains(c)
            )
            .buttonStyle(PlainButtonStyle())
          } else {
            CardView(card: c)
          }
        }.zIndex(Double(-index))
      }
    }
  }
}

struct CardWaverView_Previews: PreviewProvider {
  static var previews: some View {
    VStack {
      CardWaverView(
        cards: .init(open: Card.allCases),
        orientation: .horizontal,
        selectedCards: [],
        select: nil
      )
    }
  }
}
