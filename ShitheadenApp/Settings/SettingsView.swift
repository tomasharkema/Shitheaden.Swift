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
  @Binding var state: Bool

  var body: some View {
    Toggle(title, isOn: $state)
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
            state: Binding(get: {
              storage.rules.contains(.againAfterPass)
            }, set: {
              let newRules = $0 ? storage.rules.union(.againAfterPass) : storage.rules
                .subtracting(.againAfterPass)
              storage.rules = newRules
            })
          )
          Setting(
            title: "Krijg opnieuw de beurt als je een 10 of 4 dezelfde kaarten opgooit",
            state: Binding(get: {
              storage.rules.contains(.againAfterGoodBehavior)
            }, set: {
              let newRules = $0 ? storage.rules.union(.againAfterGoodBehavior) : storage.rules
                .subtracting(.againAfterGoodBehavior)
              storage.rules = newRules
            })
          )
          Setting(
            title: "Krijg open kaart wanneer je open kaart niet kan",
            state: Binding(get: {
              storage.rules.contains(.getCardWhenPassOpenCardTables)
            }, set: {
              let newRules = $0 ? storage.rules.union(.getCardWhenPassOpenCardTables) : storage
                .rules.subtracting(.getCardWhenPassOpenCardTables)
              storage.rules = newRules
            })
          )
          Setting(
            title: "Je mag passen ondanks dat je niet kan",
            state: Binding(get: {
              storage.rules.contains(.unfairPassingAllowed)
            }, set: {
              let newRules = $0 ? storage.rules.union(.unfairPassingAllowed) : storage.rules
                .subtracting(.unfairPassingAllowed)
              storage.rules = newRules
            })
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
