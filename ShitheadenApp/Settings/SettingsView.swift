//
//  SettingsView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 06/10/2021.
//

import ShitheadenShared
import SwiftUI

struct Setting: View {
  let title: String
  let rule: Rules
  @ObservedObject var storage = Storage.shared

  var body: some View {
    Toggle(title, isOn: Binding(get: {
      storage.rules.contains(rule)
    }, set: {
      let newRules = $0 ? storage.rules.union(rule) : storage.rules
        .subtracting(rule)
      storage.rules = newRules
    }))
  }
}

struct SettingsView: View {
  @Environment(\.presentationMode) private var presentationMode
  @ObservedObject var storage = Storage.shared

  var body: some View {
    NavigationView {
      Form {
        Section("Regels") {
          Setting(
            title: "Krijg opnieuw de beurt als je niet kan",
            rule: .againAfterPass
          )
          Setting(
            title: "Krijg opnieuw de beurt als je 4 dezelfde kaarten opgooit",
            rule: .againAfterPlayingFourCards
          )
          Setting(
            title: "Krijg open kaart wanneer je open kaart niet kan",
            rule: .getCardWhenPassOpenCardTables
          )
          Setting(
            title: "Je mag passen ondanks dat je niet kan",
            rule: .unfairPassingAllowed
          )
        }

        Button("Herstel standaard 3'en regels") {
          storage.rules = .all
        }

        Button("Herstel standaard Shitheaden regels") {
          storage.rules = .shitheaden
        }
      }
      .navigationTitle("Instellingen")
      .navigationBarItems(trailing: Button("Sluit", action: {
        presentationMode.wrappedValue.dismiss()
      }))
    }
  }
}
