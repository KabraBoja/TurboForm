import SwiftUI
import TurboForm

class SingleSelectionFieldViewModel<T>: ObservableObject {
    let id: Field.Id
    @Published var value: T?
    @Published var possibleValues: [T]

    init(id: Field.Id, value: T?, possibleValues: [T]) {
        self.id = id
        self.value = value
        self.possibleValues = possibleValues
    }
}

class MultiSelectionFieldViewModel<T: Hashable>: ObservableObject {
    let id: Field.Id
    @Published var value: Set<T>?
    @Published var possibleValues: [T]?

    init(id: Field.Id, value: Set<T>?, possibleValues: [T]?) {
        self.id = id
        self.value = value
        self.possibleValues = possibleValues
    }
}

class FieldViewModel<T>: ObservableObject {
    let id: Field.Id
    @Published var value: T?

    init(id: Field.Id, value: T?) {
        self.id = id
        self.value = value
    }
}

class FormViewModel: ObservableObject {

    @Published var transactionField: SingleSelectionFieldViewModel<Transaction> = SingleSelectionFieldViewModel(id: Field.Id.transaction, value: nil, possibleValues: Transaction.allCases)
    @Published var propertyTypeField: SingleSelectionFieldViewModel<PropertyType> = SingleSelectionFieldViewModel(id: Field.Id.propertyType, value: nil, possibleValues: PropertyType.allCases)
    @Published var priceMinField: FieldViewModel<Price> = FieldViewModel(id: Field.Id.priceMin, value: nil)
    @Published var priceMaxField: FieldViewModel<Price> = FieldViewModel(id: Field.Id.priceMax, value: nil)
    @Published var featuresField: MultiSelectionFieldViewModel<Feature> = MultiSelectionFieldViewModel(id: Field.Id.features, value: [], possibleValues: [])
    @Published var rentingPeriodField: SingleSelectionFieldViewModel<RentingPeriod> = SingleSelectionFieldViewModel(id: Field.Id.rentingPeriod, value: nil, possibleValues: RentingPeriod.allCases)

    let form: TurboForm<Field.Id> = TurboForm<Field.Id>(id: "FILTERS")

    init() {
        configureForm()

        // Example: Using sync with completion block
        form.commit([
            Field.transaction.add(value: .sale, validator: transactionValidator),
            Field.propertyType.add(value: .home, validator: propertyTypeValidator),
            Field.priceMin.add(validator: salePriceValidator),
            Field.priceMax.add(validator: salePriceValidator),
            Field.features.add(validator: homeFeaturesValidator),
            Field.possibleFeatures.add(validator: Validator.alwaysValid([])),
        ]) { _ in
            self.updateValues()
        }
    }

    @MainActor
    func updateValues() {
        transactionField.value = Field.transaction.value(form)
        propertyTypeField.value = Field.propertyType.value(form)
        priceMinField.value = Field.priceMin.value(form)
        priceMaxField.value = Field.priceMax.value(form)
        featuresField.value = Field.features.value(form)
        featuresField.possibleValues = Field.possibleFeatures.value(form)
        rentingPeriodField.value = Field.rentingPeriod.value(form)
    }

    private func configureForm() {
        form.onCommit = { commit in
            // Apply form rules using modifications.
            var modifications: [Modification<Field.Id>] = []
            switch Field.transaction.addedOrUpdated(commit) {
            case .rent:
                modifications.append(Field.priceMin.add(value: .amount(200), validator: rentPriceValidator))
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
                modifications.append(Field.possibleFeatures.update(value: homeFeatures))
            case .office:
                modifications.append(Field.features.remove())
                modifications.append(Field.possibleFeatures.update(value: []))
            case .garage:
                modifications.append(Field.features.add(validator: garageFeaturesValidator))
                modifications.append(Field.possibleFeatures.update(value: garageFeatures))
            case .none: break
            }

            return modifications
        }
    }
}

