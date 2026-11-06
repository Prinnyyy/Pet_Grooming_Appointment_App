import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class GroomerOfferKeyboardTests: XCTestCase {
    func testNativeAccessoriesAndResponderDismissalForBothEditors() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: Editors())
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.endEditing(true); window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        try await Task.sleep(for: .milliseconds(150))
        host.view.layoutIfNeeded()
        let price = try XCTUnwrap(descendant(UITextField.self, in: host.view))
        let message = try XCTUnwrap(descendant(UITextView.self, in: host.view))
        XCTAssertNotNil(price.inputAccessoryView)
        XCTAssertNotNil(message.inputAccessoryView)
        // Exercise both controls twice, including resignation/reacquisition after a
        // background-style endEditing. No offer or remote data is submitted.
        for input in [price as UIView, message, price, message] {
            XCTAssertTrue(input.becomeFirstResponder())
            try await Task.sleep(for: .milliseconds(350))
            XCTAssertTrue(input.isFirstResponder)
            let accessory = try XCTUnwrap(input.inputAccessoryView)
            XCTAssertFalse(accessory.isOpaque)
            XCTAssertEqual(accessory.backgroundColor, UIColor.clear)
            XCTAssertNotNil(accessory.window, "The Done control must be owned by the native keyboard")
            XCTAssertEqual(accessory.bounds.height, 64, accuracy: 1)
            XCTAssertGreaterThan(accessory.bounds.width, 300)
            XCTAssertTrue(UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil), "Price must not reject the standard keyboard-dismiss action")
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertFalse(input.isFirstResponder, "The focus binding must not reopen the keyboard")
        }
    }

    private struct Editors: View {
        @State private var price = "95"
        @State private var message = "Keep this draft"
        @State private var focus: GroomerOfferFocusTarget?
        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        GroomerVisitOfferPriceInput(text: $price, focusedTarget: $focus, pointSize: 40, usesRowStyle: true)
                        GroomerVisitOfferMessageInput(text: $message, focusedTarget: $focus)
                    }.padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .modifier(GroomerVisitRequestFooter(showsPrimary: true, isEditing: focus != nil) { Button("Send offer") {} })
            }
        }
    }

    private func descendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        if let view = view as? T { return view }
        return view.subviews.lazy.compactMap { self.descendant(type, in: $0) }.first
    }
}
