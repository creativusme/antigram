import ObjectiveC
import UIKit
import WebKit

extension WKWebView {
    /// Toglie la barra "‹ › Fine" sopra la tastiera, il dettaglio che più fa sembrare un sito.
    /// Si crea al volo una sottoclasse di WKContentView che non ha inputAccessoryView.
    func hideInputAccessoryBar() {
        guard let contentView = scrollView.subviews.first(where: {
            String(describing: type(of: $0)).hasPrefix("WKContent")
        }) else { return }

        let originalClass: AnyClass = type(of: contentView)
        let subclassName = "\(NSStringFromClass(originalClass))_AntigramNoAccessory"

        if let existing = NSClassFromString(subclassName) {
            object_setClass(contentView, existing)
            return
        }
        guard let subclass = objc_allocateClassPair(originalClass, subclassName, 0) else { return }

        let getter: @convention(block) (AnyObject) -> AnyObject? = { _ in nil }
        let selector = #selector(getter: UIResponder.inputAccessoryView)
        class_addMethod(subclass, selector, imp_implementationWithBlock(getter), "@@:")
        objc_registerClassPair(subclass)
        object_setClass(contentView, subclass)
    }
}
