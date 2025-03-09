import XCTest
import TurboForm

final class FormTests: XCTestCase {

    @MainActor
    func testFormValidation1() async throws {
        let form = TurboForm<Field.Id>(id: "test_form")

        form.onCommit = { commit in
            // Apply form rules using modifications.
            var modifications: [Modification<Field.Id>] = []
            switch Field.transaction.addedOrUpdated(commit) {
            case .rent:
                modifications.append(Field.priceMin.add(validator: rentPriceValidator))
                modifications.append(Field.priceMax.add(validator: rentPriceValidator))
                modifications.append(Field.rentingPeriod.add(validator: rentingPeriodValidator))
            case .sale:
                modifications.append(Field.priceMin.add(validator: salePriceValidator))
                modifications.append(Field.priceMax.add(value: .amount(200_000), validator: salePriceValidator))
                modifications.append(Field.rentingPeriod.remove())
            case .none: break
            }

            switch Field.propertyType.addedOrUpdated(commit) {
            case .home:
                modifications.append(Field.features.add(validator: homeFeaturesValidator))
            case .office:
                modifications.append(Field.features.remove())
            case .garage:
                modifications.append(Field.features.add(validator: garageFeaturesValidator))
            case .none: break
            }

            return modifications
        }

        await form.commit([
            Field.transaction.add(value: .sale, validator: transactionValidator),
            Field.propertyType.add(value: .home, validator: propertyTypeValidator),
            Field.priceMin.add(validator: salePriceValidator),
            Field.priceMax.add(validator: salePriceValidator),
            Field.features.add(validator: homeFeaturesValidator),
        ])
        printForm(form.fields)

        XCTAssertTrue(Field.transaction.value(form) == .sale)
        XCTAssertTrue(Field.propertyType.value(form) == .home)
        XCTAssertTrue(Field.priceMin.value(form) == .undefined)
        XCTAssertTrue(Field.priceMax.value(form) == .amount(200_000))
        XCTAssertEqual(Field.rentingPeriod.value(form), nil)

        await form.commit(Field.transaction.update(value: .rent))
        printForm(form.fields)
        XCTAssertEqual(Field.rentingPeriod.value(form), .monthly)
        XCTAssertTrue(Field.priceMax.value(form) == .undefined)

        await form.commit(.update(id: .priceMin, value: Price.amount(500)))
        printForm(form.fields)
        XCTAssertEqual(Field.transaction.value(form), .rent)
        XCTAssertEqual(Field.priceMin.value(form), .amount(500))

        await form.commit([
            Field.transaction.update(value: .sale),
            Field.priceMin.update(value: Price.amount(50_000))
        ])
        printForm(form.fields)
        XCTAssertEqual(Field.transaction.value(form), .sale)
        XCTAssertEqual(Field.priceMin.value(form), .undefined)

        await form.commit([
            Field.priceMin.update(value: Price.amount(50_000))
        ])
        printForm(form.fields)
        XCTAssertEqual(Field.transaction.value(form), .sale)
        XCTAssertEqual(Field.priceMin.value(form), .amount(50_000))

        await form.commit(Field.features.update(value: Set<Feature>([.heating, .balcony])))
        printForm(form.fields)

        var features = try XCTUnwrap(Field.features.value(form))
        XCTAssertTrue(features.contains(.balcony))
        XCTAssertTrue(features.contains(.heating))
        XCTAssertFalse(features.contains(.lift))

        await form.commit(Field.propertyType.update(value: .garage))
        printForm(form.fields)

        features = try XCTUnwrap(Field.features.value(form))
        XCTAssertFalse(features.contains(.balcony))

        await form.commit(Field.features.update(value: Set([Feature.garageAutomaticDoor])))
        printForm(form.fields)

        features = try XCTUnwrap(Field.features.value(form))
        XCTAssertTrue(features.contains(.garageAutomaticDoor))
    }

    @MainActor
    func testFormMaxIterations() async throws {
        let form = TurboForm<Field.Id>(id: "test_form")

        var iterations = 0
        form.onCommit = { commit in
            var modifications: [Modification<Field.Id>] = []
            switch Field.transaction.addedOrUpdated(commit) {
            case .rent:
                modifications.append(.update(id: .transaction, value: Transaction.sale))
            case .sale:
                modifications.append(.update(id: .transaction, value: Transaction.rent))
            case .none: break
            }

            iterations += 1
            return modifications
        }

        await form.commit([
            Field.transaction.add(validator: transactionValidator),
            Field.propertyType.add(validator: propertyTypeValidator),
            Field.priceMin.add(validator: salePriceValidator),
            Field.priceMax.add(validator: salePriceValidator),
        ])
        printForm(form.fields)
        XCTAssertEqual(iterations, form.maxIterations)
        XCTAssertEqual(form.history.count, 50)
    }

    func printForm(_ fields: Fields<Field.Id>) {
        print("FORM: ")
        print("")
        for field in fields.items.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            print("\(field.id): \(field.value)")
        }
        print("")
        print("")
    }
}

// MARK: Domain Entities

struct Field {
    enum Id: String, Equatable {
        case transaction
        case propertyType
        case priceMin
        case priceMax
        case rentingPeriod
        case features
    }

    static let transaction = FieldAccessor<Id, Transaction>(id: .transaction)
    static let propertyType = FieldAccessor<Id, PropertyType>(id: .propertyType)
    static let priceMin = FieldAccessor<Id, Price>(id: .priceMin)
    static let priceMax = FieldAccessor<Id, Price>(id: .priceMax)
    static let rentingPeriod = FieldAccessor<Id, RentingPeriod>(id: .rentingPeriod)
    static let features = FieldAccessor<Id, Set<Feature>>(id: .features)
}

enum Price: Hashable {
    case undefined
    case amount(Int)
}

enum PropertyType: Hashable {
    case home
    case office
    case garage
}

enum Transaction: Hashable {
    case sale
    case rent
}

enum RentingPeriod: Hashable {
    case weekly
    case monthly
    case yearly
}

enum Feature: Hashable {
    case garageAutomaticDoor
    case garageCamera
    case lift
    case heating
    case balcony
    case swimmingPool
}

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
    case .undefined:
        return true
    case .amount(let amount):
        return amount >= 50_000 && amount <= 2_500_000
    }
}

let rentPriceValidator = Validator(Price.undefined) { value in
    switch value {
    case .undefined:
        return true
    case .amount(let amount):
        return amount >= 100 && amount <= 10_000
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
    let validFeatures = Set<Feature>([.garageAutomaticDoor, .garageCamera])
    return values.isSubset(of: validFeatures)
}

let homeFeaturesValidator = Validator<Set<Feature>>([]) { values in
    let validFeatures = Set<Feature>([.swimmingPool, .lift, .balcony, .heating])
    return values.isSubset(of: validFeatures)
}
