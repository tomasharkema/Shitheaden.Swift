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

  let selectedCards: [RenderCard]
  let select: (([RenderCard], Bool) -> Void)?

  @State var hasLongPressed = false

  @ViewBuilder
  func v(c: RenderCard) -> some View {
    if let select = select {
      StatedButton(
        action: { selected in
          if !hasLongPressed {
            select([c], selected)
          }
          hasLongPressed = false
        }, label: {
          CardView(card: c)
        }, isSelected: selectedCards.contains(c)
      )
      .simultaneousGesture(LongPressGesture().onEnded {
        print($0)
        if $0 {
          hasLongPressed = true
          select(cards.filter { $0.card?.number == c.card?.number }, true)
        }
      })
      .buttonStyle(PlainButtonStyle())
    } else {
      CardView(card: c)
    }
  }

  var body: some View {
    OrientationStack(orientation: orientation, spacing: -20) {
      ForEach(Array(cards.enumerated()), id: \.element) { index, c in
        v(c: c).zIndex(Double(-index))
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
