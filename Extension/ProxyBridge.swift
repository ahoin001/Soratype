import UIKit
import SoratypeEngine

enum ProxyBridge {
    static func apply(_ effects: [EngineEffect], proxy: UITextDocumentProxy) {
        for effect in effects {
            switch effect {
            case .setMarked(let text):
                let range = NSRange(location: (text as NSString).length, length: 0)
                proxy.setMarkedText(text, selectedRange: range)
                if text.isEmpty {
                    proxy.unmarkText()
                }
            case .commit(let text):
                let range = NSRange(location: (text as NSString).length, length: 0)
                proxy.setMarkedText(text, selectedRange: range)
                proxy.unmarkText()
            case .insert(let text):
                proxy.insertText(text)
            case .deleteBackward(let count):
                for _ in 0..<count {
                    proxy.deleteBackward()
                }
            case .replaceTail(let delete, let insert):
                proxy.unmarkText()
                for _ in 0..<delete {
                    proxy.deleteBackward()
                }
                if !insert.isEmpty {
                    proxy.insertText(insert)
                }
            case .strip, .page:
                break
            }
        }
    }
}
