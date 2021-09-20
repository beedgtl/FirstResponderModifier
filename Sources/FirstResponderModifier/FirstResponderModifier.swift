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

public struct FirstResponderModifier: ViewModifier {
  @Binding var isFirstResponder: Bool

  @State private var responderViewSubject = CurrentValueSubject<UIView?, Never>(nil)

  public func body(content: Content) -> some View {
    content
      .introspectTextField { view in
        updateResponderViewIfNeeded(view)
      }
      .introspectScrollView {
        guard let view = $0 as? UITextView else { return }
        updateResponderViewIfNeeded(view)
      }
      .onReceive(responderViewSubject) { _ in
        updateFirstResponder()
      }
      .onReceive(Just(isFirstResponder)) { _ in
        updateFirstResponder()
      }
  }

  private func updateResponderViewIfNeeded(_ view: UIView) {
    guard responderViewSubject.value !== view else { return }
    responderViewSubject.send(view)

    let type = type(of: view)
    _ = try? view.hook(
      #selector(type.becomeFirstResponder),
      methodSignature: (@convention(c) (AnyObject, Selector) -> Bool).self,
      hookSignature: (@convention(block) (AnyObject) -> Bool).self) { store in
      {
        let result = store.original($0, store.selector)
        if !self.isFirstResponder {
          self.isFirstResponder = true
        }
        return result
      }
    }

    _ = try? view.hook(
      #selector(type.resignFirstResponder),
      methodSignature: (@convention(c) (AnyObject, Selector) -> Bool).self,
      hookSignature: (@convention(block) (AnyObject) -> Bool).self) { store in
      {
        let result = store.original($0, store.selector)
        if self.isFirstResponder {
          self.isFirstResponder = false
        }
        return result
      }
    }
  }

  private func updateFirstResponder() {
    guard let view = responderViewSubject.value else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(550)) {
      switch (isFirstResponder, view.isFirstResponder) {
      case (true, false):
        view.becomeFirstResponder()
      case (false, true):
        view.resignFirstResponder()
      default:
        break
      }
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
