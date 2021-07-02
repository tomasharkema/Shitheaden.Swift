//
//  OrientationStack.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import SwiftUI

enum Orientation {
  case horizontal
  case vertical

  func toggle() -> Orientation {
    switch self {
    case .horizontal:
      return .vertical
    case .vertical:
      return .horizontal
    }
  }
}

struct OrientationStack<Content: View>: View {
  let orientation: Orientation
  let spacing: CGFloat?
  @ViewBuilder let content: () -> Content

  init(
    orientation: Orientation,
    spacing: CGFloat? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.orientation = orientation
    self.spacing = spacing
    self.content = content
  }

  var body: some View {
    switch orientation {
    case .horizontal:
      HStack(spacing: spacing) {
        content()
      }
    case .vertical:
      VStack(spacing: spacing) {
        content()
      }
    }
  }
}
