import Foundation
import TurboForm

// MARK: Form Entity

struct Field {
    enum Id: String, Equatable {
        case transaction
        case propertyType
        case priceMin
        case priceMax
        case rentingPeriod
        case features
        case possibleFeatures
    }

    static let transaction = FieldAccessor<Id, Transaction>(id: .transaction)
    static let propertyType = FieldAccessor<Id, PropertyType>(id: .propertyType)
    static let priceMin = FieldAccessor<Id, Price>(id: .priceMin)
    static let priceMax = FieldAccessor<Id, Price>(id: .priceMax)
    static let rentingPeriod = FieldAccessor<Id, RentingPeriod>(id: .rentingPeriod)
    static let features = FieldAccessor<Id, Set<Feature>>(id: .features)
    static let possibleFeatures = FieldAccessor<Id, [Feature]>(id: .possibleFeatures)
}


// MARK: Domain Entities

enum Price: Hashable {
    case undefined
    case amount(Int)
}

enum PropertyType: Hashable, CaseIterable {
    case home
    case office
    case garage
}

enum Transaction: Hashable, CaseIterable {
    case sale
    case rent
}

enum RentingPeriod: Hashable, CaseIterable {
    case weekly
    case monthly
    case yearly
}

enum Feature: Hashable, CaseIterable {
    case garageAutomaticDoor
    case garageCamera
    case lift
    case heating
    case balcony
    case swimmingPool
}

let garageFeatures: [Feature] = [.garageAutomaticDoor, .garageCamera]
let homeFeatures: [Feature] = [.swimmingPool, .lift, .balcony, .heating]

// MARK: Domain Validators

let transactionValidator = Validator(Transaction.sale) { value in
    return switch value {
    case .sale: true
    case .rent: true
    }
}

let propertyTypeValidator = Validator(PropertyType.home) { value in
    return switch value {
    case .home: true
    case .office: true
    case .garage: true
    }
}

let salePriceValidator = Validator(Price.undefined) { value in
    switch value {
    case .undefined: true
    case .amount(let amount): amount >= 50_000 && amount <= 2_500_000
    }
}

let rentPriceValidator = Validator(Price.undefined) { value in
    switch value {
    case .undefined: true
    case .amount(let amount): amount >= 100 && amount <= 10_000
    }
}

let rentingPeriodValidator = Validator(RentingPeriod.monthly) { value in
    switch value {
    case .monthly: return true
    case .weekly: return true
    case .yearly: return true
    }
}

let garageFeaturesValidator = Validator<Set<Feature>>([]) { values in
    let validFeatures = Set<Feature>(garageFeatures)
    return values.isSubset(of: validFeatures)
}

let homeFeaturesValidator = Validator<Set<Feature>>([]) { values in
    let validFeatures = Set<Feature>(homeFeatures)
    return values.isSubset(of: validFeatures)
}
