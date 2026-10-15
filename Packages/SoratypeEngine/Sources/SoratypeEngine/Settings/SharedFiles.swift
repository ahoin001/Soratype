import Foundation

public enum SharedFiles {
    public static func groupContainer() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
    }

    public static func lexiconURL() -> URL? {
        groupContainer()?.appending(path: AppGroup.lexiconFilename)
    }

    public static func memoryURL() -> URL? {
        groupContainer()?.appending(path: AppGroup.memoryFilename)
    }
}
