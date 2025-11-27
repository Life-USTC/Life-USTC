import Foundation
import SwiftData

@Model
final class CachedJSON {
    @Attribute(.unique) var key: String
    var data: Data
    var updatedAt: Date

    init(key: String, data: Data, updatedAt: Date = Date()) {
        self.key = key
        self.data = data
        self.updatedAt = updatedAt
    }
}

extension ModelContext {
    func replaceAll<T: PersistentModel>(_: T.Type, with items: [T]) throws {
        let existing = try? fetch(FetchDescriptor<T>())
        existing?.forEach { delete($0) }
        for item in items { insert(item) }
        try save()
    }

    func replaceSingle<T: PersistentModel>(_: T.Type, with item: T) throws {
        let existing = try? fetch(FetchDescriptor<T>())
        existing?.forEach { delete($0) }
        insert(item)
        try save()
    }

    func cacheJSON(key: String, data: Data) throws {
        let descriptor = FetchDescriptor<CachedJSON>(predicate: #Predicate { $0.key == key })
        let cached = (try? fetch(descriptor))?.first ?? CachedJSON(key: key, data: data)
        cached.data = data
        cached.updatedAt = Date()
        insert(cached)
        try save()
    }

    func getCachedJSON(key: String) throws -> Data? {
        let descriptor = FetchDescriptor<CachedJSON>(predicate: #Predicate { $0.key == key })
        return try fetch(descriptor).first?.data
    }
}
