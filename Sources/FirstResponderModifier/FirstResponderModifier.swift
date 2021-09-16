//
//  FirstResponderModifier.swift
//  
//
//  Created by Roman Baev on 11.09.2021.
//

import Foundation
import SwiftUI
import Combine
import Introspect
import InterposeKit
import SwiftUIX

public struct FirstResponderModifier: ViewModifier {
  @Binding var isFirstResponder: Bool

  @State private var responderView: UIView?

  public func body(content: Content) -> some View {
    content
      .introspectTextField { view in
        updateResponderViewIfNeeded(view)
      }
      .introspectScrollView {
        guard let view = $0 as? UITextView else { return }
        updateResponderViewIfNeeded(view)
      }
      .onReceive(Just(isFirstResponder)) { _ in
        updateFirstResponder()
      }
      .onAppear {
        /// w8 for the end of modal/navigation controller transition
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(900)) {
          self.updateFirstResponder()
        }
      }
  }

  private func updateResponderViewIfNeeded(_ view: UIView) {
    guard responderView !== view else { return }

    responderView = view

    let type = type(of: view)
    _ = try? view.hook(
      #selector(type.becomeFirstResponder),
      methodSignature: (@convention(c) (AnyObject, Selector) -> Bool).self,
      hookSignature: (@convention(block) (AnyObject) -> Bool).self) { store in
      { `self` in
        let result = store.original(`self`, store.selector)
        if !isFirstResponder {
          isFirstResponder = true
        }
        return result
      }
    }

    _ = try? view.hook(
      #selector(type.resignFirstResponder),
      methodSignature: (@convention(c) (AnyObject, Selector) -> Bool).self,
      hookSignature: (@convention(block) (AnyObject) -> Bool).self) { store in
      { `self` in
        let result = store.original(`self`, store.selector)
        if isFirstResponder {
          isFirstResponder = false
        }
        return result
      }
    }
  }

  private func updateFirstResponder() {
    if isFirstResponder {
      responderView?.becomeFirstResponder()
    } else {
      responderView?.resignFirstResponder()
    }
  }
}

public extension View {
  func firstResponder(
    _ condition: Binding<Bool>
  ) -> some View {
    return modifier(FirstResponderModifier(isFirstResponder: condition))
  }

  func firstResponder<Value>(
    _ condition: Binding<Value?>,
    equals value: Value
  ) -> some View where Value: Hashable {
    let condition = Binding<Bool>(
      get: { condition.wrappedValue == value },
      set: { isFirstResponder in
        if isFirstResponder {
          condition.wrappedValue = value
        } else {
          condition.wrappedValue = nil
        }
      }
    )
    return modifier(FirstResponderModifier(isFirstResponder: condition))
  }
}
