import Foundation

public struct Field<IdType: Equatable & Hashable> {
    public let id: IdType
    public let value: Any

    internal init(id: IdType, value: Any) {
        self.id = id
        self.value = value
    }
}

public struct Fields<IdType: Equatable & Hashable> {
    public let items: [Field<IdType>]

    public func value<T>(_ id: IdType) -> T? {
        items.first(where: { $0.id == id })?.value as? T
    }

    init(fields: [Field<IdType>]) {
        self.items = fields
    }
}

public struct Merge<IdType: Equatable & Hashable> {
    
    public let id: UUID = UUID()
    public let commits: [Commit<IdType>]
    public let modified: [Modified<IdType>]
    public let added: Fields<IdType>
    public let updated: Fields<IdType>
    public var addedOrUpdated: Fields<IdType> { Fields(fields: added.items + updated.items) }
    public let removed: Fields<IdType>
    public let fields: Fields<IdType>
    public let author: Author

    internal init(commits: [Commit<IdType>], fields: Fields<IdType>, modified: [Modified<IdType>], author: Author) {
        self.fields = fields
        self.modified = modified
        self.added = Fields(fields: modified.compactMap {
            return switch $0 {
            case .added(let id, let value, _, _): Field(id: id, value: value)
            case .updated(_, _, _): nil
            case .removed(_, _): nil
            }
        })
        self.updated = Fields(fields: modified.compactMap {
            return switch $0 {
            case .added(_, _, _, _): nil
            case .updated(let id, let value, _): Field(id: id, value: value)
            case .removed(_, _): nil
            }
        })
        self.removed = Fields(fields: modified.compactMap {
            return switch $0 {
            case .added(_, _, _, _): nil
            case .updated(_, _, _): nil
            case .removed(let id, let lastValue): Field(id: id, value: lastValue)
            }
        })
        self.commits = commits
        self.author = author
    }
}

public struct Commit<IdType: Equatable & Hashable> {

    public let id: UUID = UUID()
    public let fields: Fields<IdType>
    public let modified: [Modified<IdType>]
    public let added: Fields<IdType>
    public let updated: Fields<IdType>
    public var addedOrUpdated: Fields<IdType> { Fields(fields: added.items + updated.items) }
    public let removed: Fields<IdType>
    public let errors: [CommitError<IdType>]
    public let author: Author

    internal init(fields: Fields<IdType>, added: [Modified<IdType>], updated: [Modified<IdType>], removed: [Modified<IdType>], errors: [CommitError<IdType>], author: Author) {
        self.fields = fields
        self.modified = added + updated + removed
        self.added = Fields(fields: added.compactMap {
            return switch $0 {
            case .added(let id, let value, _, _): Field(id: id, value: value)
            case .updated(_, _, _): nil
            case .removed(_, _): nil
            }
        })
        self.updated = Fields(fields: updated.compactMap {
            return switch $0 {
            case .added(_, _, _, _): nil
            case .updated(let id, let value, _): Field(id: id, value: value)
            case .removed(_, _): nil
            }
        })
        self.removed = Fields(fields: removed.compactMap {
            return switch $0 {
            case .added(_, _, _, _): nil
            case .updated(_, _, _): nil
            case .removed(let id, let lastValue): Field(id: id, value: lastValue)
            }
        })
        self.errors = errors
        self.author = author
    }
}

public enum CommitError<IdType>: Error {
    
    case commitInProgress
    case fieldNotFound(id: IdType, value: Any)
    case validationFailed(id: IdType, value: Any, validatorId: UUID)
    case invalidValueType(id: IdType, value: Any, validatorId: UUID)
    case maxIterationsReached

    public var description: String {
        return switch self {
        case .commitInProgress:
            "Can't modify the Form while commit is in progress. Recursive changes not allowed."
        case .fieldNotFound(let id, let value):
            "Updating field \(id) with value: \(value) failed because field does not exist."
        case .validationFailed(id: let id, value: let value, validatorId: _):
            "Field \(id) validation failed with value: \(value)"
        case .invalidValueType(id: let id, value: let value, validatorId: _):
            "Field \(id) received an invalid value TYPE: \(value)"
        case .maxIterationsReached:
            "Max iterations reached. Form is reaching infinite recursion."
        }
    }
}

public enum Modified<IdType: Equatable & Hashable> {
    case added(id: IdType, value: Any, previousValue: Any, overriding: Bool)
    case updated(id: IdType, value: Any, previousValue: Any)
    case removed(id: IdType, lastValue: Any)

    public var id: IdType {
        switch self {
        case .added(let id, _, _, _): id
        case .updated(let id, _, _): id
        case .removed(let id, _): id
        }
    }
}

public enum Modification<IdType: Equatable & Hashable> {
    /// Adds a new field and its related validator.
    ///
    /// If the field does not exist the field  will be setted with the default value of the validator.
    ///
    /// If the field already exists, the previousValue will be validated with new validator and if it's valid, the field will be setted with the previousValue; if it's not valid, then the field will be setted with the default value from the validator.
    case add(id: IdType, validator: AnyValidator)

    /// Adds  a new field and its related validator and then sets  the value to the field.
    ///
    /// If the field does not exist the value will be validated by the new validator. If the value is valid, then the field will be setted with the value.
    /// If the value is not valid, then the field will be setted with the default value from the validator.
    ///
    /// If the field already exists the value will be validated by the new validator. If the value is valid, then the field will be setted with the value.
    /// If the value is not valid, then the previousValue will be validated by the new validator.
    /// If the previousValue is valid, the field will be setted with the previousValue; if it's not valid, then the field will be setted with the default value from the validator.
    case addAndUpdate(id: IdType, value: Any, validator: AnyValidator)

    /// Sets a value to an existing field.
    ///
    /// The new value is validated. If the value is not valid the field remains unmodified.
    /// If the field does not exist, it raises a warning.
    case update(id: IdType, value: Any)

    /// Removes an existing field.
    ///
    /// If the field does not exist, it raises a warning.
    case remove(id: IdType)

    public var id: IdType {
        switch self {
        case .add(let id, _): id
        case .addAndUpdate(let id,_, _): id
        case .update(let id, _): id
        case .remove(let id): id
        }
    }
}

public enum ValidatorResult<T> {
    case success
    case failure
    case invalidType
}

public protocol AnyValidator {
    var validatorId: UUID { get }
    var defaultValueAsAny: Any { get }
    func validate(value: Any) async -> ValidatorResult<Any>
}

public struct Validator<T>: AnyValidator {
    let validateClosure: ((T) async -> Bool)
    public let defaultValue: T
    public let validatorId: UUID = UUID()

    public init(_ defaultValue: T, validate: @escaping (T) -> Bool) {
        self.defaultValue = defaultValue
        self.validateClosure = validate
    }

    public func validate(value: Any) async -> ValidatorResult<Any> {
        if let value = value as? T {
            return await validateClosure(value) ? .success : .failure
        } else {
            return .invalidType
        }
    }

    public var defaultValueAsAny: Any {
        defaultValue
    }

    public static func alwaysValid(_ defaultValue: T) -> Validator<T> {
        Validator(defaultValue, validate: { _ in true })
    }
}

public struct FieldAccessor<IdType: Equatable & Hashable, T> {
    public let id: IdType

    public init(id: IdType) {
        self.id = id
    }

    // Modifications input

    public func add(validator: Validator<T>) -> Modification<IdType> {
        .add(id: id, validator: validator)
    }

    public func add(value: T, validator: Validator<T>) -> Modification<IdType> {
        .addAndUpdate(id: id, value: value, validator: validator)
    }

    public func remove() -> Modification<IdType> {
        .remove(id: id)
    }

    public func update(value: T) -> Modification<IdType> {
        .update(id: id, value: value)
    }

    // Fields output

    public func value(_ from: Fields<IdType>) -> T? {
        from.value(id)
    }

    // Form output

    @MainActor
    public func value(_ from: TurboForm<IdType>) -> T? {
        from.fields.value(id)
    }

    // Commit output

    @MainActor
    public func value(_ from: Commit<IdType>) -> T? {
        from.fields.value(id)
    }

    public func addedOrUpdated(_ from: Commit<IdType>) -> T? {
        from.addedOrUpdated.value(id)
    }

    public func updated(_ from: Commit<IdType>) -> T? {
        from.updated.value(id)
    }

    public func added(_ from: Commit<IdType>) -> T? {
        from.added.value(id)
    }

    public func removed(_ from: Commit<IdType>) -> T? {
        from.removed.value(id)
    }

    // Merge output

    @MainActor
    public func value(_ from: Merge<IdType>) -> T? {
        from.fields.value(id)
    }

    public func addedOrUpdated(_ from: Merge<IdType>) -> T? {
        from.addedOrUpdated.value(id)
    }

    public func updated(_ from: Merge<IdType>) -> T? {
        from.updated.value(id)
    }

    public func added(_ from: Merge<IdType>) -> T? {
        from.added.value(id)
    }

    public func removed(_ from: Merge<IdType>) -> T? {
        from.removed.value(id)
    }
}

public enum Author {
    case form
    case user
    case other(String)
}

public enum HistoryItem<IdType: Equatable & Hashable> {
    case commit(Commit<IdType>)
    case merge(Merge<IdType>)
}

public class TurboForm<IdType: Equatable & Hashable>: Identifiable {

    public let id: String
    public var maxIterations = 100
    public var maxHistoryLength = 50

    public private(set) var fields: Fields<IdType> = Fields(fields: [])
    public private(set) var history: [HistoryItem<IdType>] = []
    public var onCommit: ((Commit<IdType>) async -> [Modification<IdType>]) = { _ in return [] }

    public init(id: String) {
        self.id = id
    }

    @discardableResult
    public func commit(_ modification: Modification<IdType>, author: Author = .form) async -> Merge<IdType> {
        await commit([modification], author: author)
    }

    @discardableResult
    public func commit(_ modifications: [Modification<IdType>], author: Author = .form) async -> Merge<IdType> {
        await queue.enqueue {
            await self.executeCommit(modifications, author: author)
        }
    }

    public func commit(_ modifications: [Modification<IdType>], author: Author = .form, completion: @escaping @MainActor (Merge<IdType>) -> Void) {
        Task { @MainActor in
            let merge = await queue.enqueue {
                await self.executeCommit(modifications, author: author)
            }
            completion(merge)
        }
    }

    @MainActor
    private var commitInProgress = false
    private var internalFields: [FieldInternal<IdType>] = []
    private let queue = SerialQueue<IdType>()

    @MainActor
    private func executeCommit(_ modifications: [Modification<IdType>], author: Author) async -> Merge<IdType> {
        if !commitInProgress {
            commitInProgress = true
            let commits = await applyModifications(modifications, author: author)
            commitInProgress = false
            return commits
        } else {
            let commit = Commit<IdType>(fields: Fields(fields: []), added: [], updated: [], removed: [], errors: [.commitInProgress], author: author)
            return Merge<IdType>(commits: [commit], fields: Fields(fields: []), modified: [], author: author)
        }
    }

    private func applyModifications(_ modifications: [Modification<IdType>], author: Author) async -> Merge<IdType> {
        var newModifications: [Modification<IdType>] = uniqueByIdKeepingLast(modifications)
        var iterations = 0
        var author = author
        var accCommits: [Commit<IdType>] = []
        var iterationFields = Fields<IdType>(fields: [])
        let originalFields = fields
        var squashed: [Modified<IdType>] = []

        while !newModifications.isEmpty && iterations < maxIterations {
            var added: [Modified<IdType>] = []
            var updated: [Modified<IdType>] = []
            var removed: [Modified<IdType>] = []
            var errors: [CommitError<IdType>] = []
            for modification in newModifications {
                switch modification {
                case .add(let id, let validator):
                    let newValue: Any
                    if let previousFieldIdx = internalFields.firstIndex(where: { $0.id == id }) {
                        let previousValue = internalFields[previousFieldIdx].value
                        internalFields[previousFieldIdx].setValidator(validator)

                        switch await validator.validate(value: previousValue) {
                        case .success:
                            newValue = previousValue
                        case .failure:
                            errors.append(.validationFailed(id: id, value: previousValue, validatorId: validator.validatorId))
                            newValue = validator.defaultValueAsAny
                        case .invalidType:
                            errors.append(.invalidValueType(id: id, value: previousValue, validatorId: validator.validatorId))
                            newValue = validator.defaultValueAsAny
                        }
                        internalFields[previousFieldIdx].setValue(newValue)
                        if !areEqual(newValue, previousValue) {
                            added.append(.added(id: id, value: newValue, previousValue: previousValue, overriding: true))
                        }
                    } else {
                        newValue = validator.defaultValueAsAny
                        internalFields.append(FieldInternal(id: id, value: newValue, validator: validator))
                        added.append(.added(id: id, value: newValue, previousValue: newValue, overriding: false))
                    }
                case .addAndUpdate(let id, let value, let validator):
                    let newValue: Any
                    if let previousFieldIdx = internalFields.firstIndex(where: { $0.id == id }) {
                        let previousValue = internalFields[previousFieldIdx].value
                        internalFields[previousFieldIdx].setValidator(validator)

                        switch await validator.validate(value: value) {
                        case .success:
                            newValue = value
                        case .failure:
                            errors.append(.validationFailed(id: id, value: value, validatorId: validator.validatorId))
                            switch await validator.validate(value: previousValue) {
                            case .success:
                                newValue = previousValue
                            case .failure:
                                errors.append(.validationFailed(id: id, value: previousValue, validatorId: validator.validatorId))
                                newValue = validator.defaultValueAsAny
                            case .invalidType:
                                errors.append(.invalidValueType(id: id, value: previousValue, validatorId: validator.validatorId))
                                newValue = validator.defaultValueAsAny
                            }
                        case .invalidType:
                            errors.append(.invalidValueType(id: id, value: value, validatorId: validator.validatorId))
                            newValue = validator.defaultValueAsAny
                        }
                        internalFields[previousFieldIdx].setValue(newValue)
                        if !areEqual(newValue, previousValue) {
                            added.append(.added(id: id, value: newValue, previousValue: previousValue, overriding: true))
                        }
                    } else {
                        switch await validator.validate(value: value) {
                        case .success:
                            newValue = value
                        case .failure:
                            errors.append(.validationFailed(id: id, value: value, validatorId: validator.validatorId))
                            newValue = validator.defaultValueAsAny
                        case .invalidType:
                            errors.append(.invalidValueType(id: id, value: value, validatorId: validator.validatorId))
                            newValue = validator.defaultValueAsAny
                        }
                        internalFields.append(FieldInternal(id: id, value: newValue, validator: validator))
                        added.append(.added(id: id, value: newValue, previousValue: newValue, overriding: false))
                    }
                case .update(let id, let value):
                    let previousValue: Any
                    if let previousFieldIdx = internalFields.firstIndex(where: { $0.id == id }) {
                        previousValue = internalFields[previousFieldIdx].value
                        let validator = internalFields[previousFieldIdx].validator
                        switch await validator.validate(value: value) {
                        case .success:
                            internalFields[previousFieldIdx].setValue(value)
                            updated.append(.updated(id: id, value: value, previousValue: previousValue))
                        case .failure:
                            errors.append(.validationFailed(id: id, value: value, validatorId: validator.validatorId))
                        case .invalidType:
                            errors.append(.invalidValueType(id: id, value: value, validatorId: validator.validatorId))
                        }
                    } else {
                        errors.append(.fieldNotFound(id: id, value: value))
                    }
                case .remove(let id):
                    if let idx = internalFields.firstIndex(where: { $0.id == id }) {
                        let lastValue = internalFields[idx].value
                        internalFields.remove(at: idx)
                        removed.append(.removed(id: id, lastValue: lastValue))
                    }
                }
            }

            if iterations == (maxIterations - 1) {
                errors.append(.maxIterationsReached)
            }

            let newFields = Fields(fields: internalFields.map { Field(id: $0.id, value: $0.value) })
            let commit = Commit<IdType>(fields: newFields, added: added, updated: updated, removed: removed, errors: errors, author: author)

            await Task { @MainActor in
                fields = newFields
                history.append(.commit(commit))
                if history.count > maxHistoryLength {
                    history = Array(history.dropFirst())
                }
            }.value

            if (added.count + updated.count + removed.count) > 0 {
                newModifications = await onCommit(commit)
                author = .form
            } else {
                newModifications = []
            }

            iterationFields = newFields
            accCommits.append(commit)
            iterations += 1
        }

        // Squash modifications
        for commit in accCommits {
            for mod in commit.modified {
                let originalValue = originalFields.items.first(where: { $0.id == mod.id })?.value
                if let idx = squashed.firstIndex(where: { $0.id == mod.id }) {
                    switch mod {
                    case .added(let id, let value, _, _):
                        if let originalValue {
                            squashed[idx] = .updated(id: id, value: value, previousValue: originalValue)
                        } else {
                            squashed[idx] = .added(id: id, value: value, previousValue: value, overriding: false)
                        }
                    case .updated(let id, let value, _):
                        if let originalValue {
                            squashed[idx] = .updated(id: id, value: value, previousValue: originalValue)
                        } else {
                            squashed[idx] = .added(id: id, value: value, previousValue: value, overriding: false)
                        }
                    case .removed(let id, _):
                        if let originalValue {
                            squashed[idx] = .removed(id: id, lastValue: originalValue)
                        }
                    }
                } else {
                    switch mod {
                    case .added(let id, let value, _, _):
                        if let originalValue {
                            squashed.append(.updated(id: id, value: value, previousValue: originalValue))
                        } else {
                            squashed.append(.added(id: id, value: value, previousValue: value, overriding: false))
                        }
                    case .updated(let id, let value, _):
                        if let originalValue {
                            squashed.append(.updated(id: id, value: value, previousValue: originalValue))
                        } else {
                            squashed.append(.added(id: id, value: value, previousValue: value, overriding: false))
                        }
                    case .removed(let id, _):
                        if let originalValue {
                            squashed.append(.removed(id: id, lastValue: originalValue))
                        }
                    }
                }
            }
        }

        let merge = Merge(commits: accCommits, fields: iterationFields, modified: squashed, author: author)

        await Task { @MainActor in
            history.append(.merge(merge))
            if history.count > maxHistoryLength {
                history = Array(history.dropFirst())
            }
        }.value

        return merge
    }

    private func areEqual(_ l: Any, _ r: Any) -> Bool {
        if let l = l as? any Hashable, let r = r as? any Hashable, l.hashValue == r.hashValue {
            return true
        }
        return false
    }

    private func uniqueByIdKeepingLast(_ items: [Modification<IdType>]) -> [Modification<IdType>] {
        var seenIds: [IdType] = []
        return items.reversed().filter { item in
            guard !seenIds.contains(item.id) else { return false }
            seenIds.append(item.id)
            return true
        }
        .reversed()
    }
}

internal struct FieldInternal<IdType: Equatable & Hashable> {
    let id: IdType
    private(set) var validator: AnyValidator
    private(set) var value: Any

    init(id: IdType, value: Any, validator: AnyValidator) {
        self.id = id
        self.value = value
        self.validator = validator
    }

    mutating func setValue(_ value: Any) {
        self.value = value
    }

    mutating func setValidator(_ validator: AnyValidator) {
        self.validator = validator
    }
}

internal actor SerialQueue<IdType: Equatable & Hashable> {
    func enqueue(_ task: @escaping @Sendable () async -> Merge<IdType>) async -> Merge<IdType> {
        await Task {
            await task()
        }.value
    }
}
