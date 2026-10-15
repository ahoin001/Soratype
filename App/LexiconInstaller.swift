import Foundation
import SoratypeEngine
import SoratypeLexiconBuilder

enum LexiconInstaller {
    static func current() -> LexiconStatus {
        guard let url = SharedFiles.lexiconURL() else {
            return LexiconStatus(
                wordCount: 0,
                byteCount: 0,
                note: "The App Group is unavailable, so the keyboard is using its bundled word list."
            )
        }
        return read(url) ?? LexiconStatus(
            wordCount: 0,
            byteCount: 0,
            note: "Rebuild the word list once to share it with the keyboard."
        )
    }

    static func rebuild() -> LexiconStatus {
        guard let resource = Bundle.main.url(forResource: "english", withExtension: "txt") else {
            return LexiconStatus(wordCount: 0, byteCount: 0, note: "The English word list is missing from the app.")
        }
        let curated = bundled("curated")
        let offensive = bundled("offensive")
        let followers = bundled("followers")
        guard let url = SharedFiles.lexiconURL() else {
            return LexiconStatus(
                wordCount: 0,
                byteCount: 0,
                note: "Turn on the App Group for Soratype before rebuilding. The keyboard still has its bundled list."
            )
        }
        do {
            let text = try String(contentsOf: resource, encoding: .utf8)
            let data = LexiconCompiler.compile(wordList: text, curated: curated, offensive: offensive, followers: followers)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return read(url) ?? LexiconStatus(wordCount: 0, byteCount: data.count, note: "The word list was written.")
        } catch {
            return LexiconStatus(wordCount: 0, byteCount: 0, note: "The word list could not be written.")
        }
    }

    private static func read(_ url: URL) -> LexiconStatus? {
        guard
            let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
            let header = LexiconFormat.header(in: data)
        else {
            return nil
        }
        return LexiconStatus(
            wordCount: header.wordCount,
            byteCount: data.count,
            note: "Installed for the keyboard. It stays on this iPhone."
        )
    }

    private static func bundled(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
