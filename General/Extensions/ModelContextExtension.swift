import Foundation
import SwiftData

extension ModelContext {
    /// Upsert helper that fetches by predicate, updates if found, otherwise inserts a new model.
    @discardableResult
    func upsert<T: PersistentModel>(
        predicate: Predicate<T>,
        update: (T) -> Void,
        create: () -> T,
        save: Bool = true
    ) throws -> T {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1

        if let existing = try fetch(descriptor).first {
            update(existing)
            if save { try self.save() }
            return existing
        }

        let newModel = create()
        insert(newModel)
        if save { try self.save() }
        return newModel
    }
}
