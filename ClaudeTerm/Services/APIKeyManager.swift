import Foundation

enum APIKeyManager {
    private static var keyFile: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClaudeTerm")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".apikey")
    }

    static func save(key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        let url = keyFile
        do {
            try data.write(to: url, options: .atomic)
            // Owner read/write only
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
            return true
        } catch {
            return false
        }
    }

    static func load() -> String? {
        guard let data = try? Data(contentsOf: keyFile),
              let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    @discardableResult
    static func delete() -> Bool {
        do {
            try FileManager.default.removeItem(at: keyFile)
            return true
        } catch {
            return false
        }
    }
}
