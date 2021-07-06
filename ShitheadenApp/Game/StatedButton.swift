//
//  StatedButton.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import SwiftUI

struct StatedButton<Label>: View where Label: View {
  private let action: ((Bool) -> Void)?

  private let label: (() -> Label)?
  let isSelected: Bool

  init(action: ((Bool) -> Void)? = nil, label: (() -> Label)? = nil, isSelected: Bool) {
    self.action = action
    self.label = label
    self.isSelected = isSelected
  }

  var body: some View {
    Button {
      self.action?(!self.isSelected)
    } label: {
      label?()
        .overlay(RoundedRectangle(cornerSize: .init(width: 10, height: 10)).foregroundColor(.clear)
                  .border(isSelected ? Color.green : Color.clear, width: 5)
                  .cornerRadius(10))
        .animation(.linear, value: isSelected)
    }.buttonStyle(PlainButtonStyle())
  }
}
