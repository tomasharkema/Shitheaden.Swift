//
//  AlertView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 22/06/2021.
//

import SwiftUI

struct AlertControlView: UIViewControllerRepresentable {
  @Binding var textString: String
  @Binding var showAlert: Bool

  var title: String
  var message: String

  // Make sure that, this fuction returns UIViewController, instead of UIAlertController.
  // Because UIAlertController gets presented on UIViewController
  func makeUIViewController(context _: UIViewControllerRepresentableContext<AlertControlView>)
    -> UIViewController
  {
    let c = UIViewController()
    // Create UIAlertController instance that is gonna present on UIViewController
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    // Adds UITextField & make sure that coordinator is delegate to UITextField.
    alert.addTextField { textField in
      textField.placeholder = "Enter some text"
      textField.text = self.textString // setting initial value
    }

    // As usual adding actions
    alert
      .addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),
                               style: .destructive) { _ in

          // On dismiss, SiwftUI view's two-way binding variable must be update (setting false) means, remove Alert's View from UI
          alert.dismiss(animated: true) {
            self.showAlert = false
          }
        })

    alert
      .addAction(UIAlertAction(title: NSLocalizedString("Submit", comment: ""),
                               style: .default) { _ in
          // On submit action, get texts from TextField & set it on SwiftUI View's two-way binding varaible `textString` so that View receives enter response.
          if let textField = alert.textFields?.first, let text = textField.text {
            self.textString = text
          }

          alert.dismiss(animated: true) {
            self.showAlert = false
          }
        })

    // Most important, must be dispatched on Main thread,
    // Curious? then remove `DispatchQueue.main.async` & find out yourself, Dont be lazy
    DispatchQueue.main.async { // must be async !!
      c.present(alert, animated: true, completion: {
        self.showAlert = false // hide holder after alert dismiss

      })
    }

    return c
  }

  func updateUIViewController(
    _: UIViewController,
    context _: UIViewControllerRepresentableContext<AlertControlView>
  ) {}
}
