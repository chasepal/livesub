import Foundation

struct VolcengineCredentials: Sendable {
    var appKey: String
    var accessToken: String

    var isComplete: Bool {
        !appKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum CloudCredentialStore {
    private struct StoredCredentials: Codable {
        var appKey: String
        var accessToken: String
    }

    private static let directoryName = "LiveSub"
    private static let fileName = "cloud-credentials.json"

    static func loadVolcengineCredentials() -> VolcengineCredentials? {
        let credentials = loadVolcenginePartialCredentials()
        return credentials.isComplete ? credentials : nil
    }

    static func loadVolcenginePartialCredentials() -> VolcengineCredentials {
        let stored = loadStoredCredentials()
        return VolcengineCredentials(
            appKey: stored.appKey,
            accessToken: stored.accessToken
        )
    }

    static func hasVolcengineCredentials() -> Bool {
        loadVolcengineCredentials()?.isComplete == true
    }

    static func saveVolcengine(appKey: String?, accessToken: String?) throws {
        let existing = loadStoredCredentials()
        let updated = StoredCredentials(
            appKey: appKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? existing.appKey,
            accessToken: accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
        try saveStoredCredentials(updated)
    }

    private static func loadStoredCredentials() -> StoredCredentials {
        guard let url = try? credentialsURL(),
              let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode(StoredCredentials.self, from: data)
        else {
            return StoredCredentials(appKey: "", accessToken: "")
        }
        return stored
    }

    private static func saveStoredCredentials(_ credentials: StoredCredentials) throws {
        let url = try credentialsURL()
        let data = try JSONEncoder().encode(credentials)
        try data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private static func credentialsURL() throws -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Application Support",
            isDirectory: true
        )
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
        }

        return directory.appendingPathComponent(fileName)
    }
}
