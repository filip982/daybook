import Foundation

protocol SavedLocationsPersistence: Sendable {
    func load() async -> [SavedLocation]
    func save(_ locations: [SavedLocation]) async
}

actor SavedLocationsFile: SavedLocationsPersistence {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Daybook").appendingPathComponent("saved-locations.json")
    }

    func load() async -> [SavedLocation] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let locations = try? JSONDecoder().decode([SavedLocation].self, from: data) else { return [] }
        return locations
    }

    func save(_ locations: [SavedLocation]) async {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        let directory = fileURL.deletingLastPathComponent()
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
