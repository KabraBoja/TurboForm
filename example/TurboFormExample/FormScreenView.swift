import SwiftUI
import TurboForm

struct FormScreenView: View {

    @StateObject var viewModel = FormViewModel()

    var body: some View {
        VStack(spacing: 12.0) {
            Text("FILTERS")
                .font(.title2)
                .fontWeight(.bold)
                .padding()

            SingleSelectionFieldView(viewModel: viewModel.transactionField) { value in
                Task { // Example: using async/await
                    await viewModel.form.commit(Field.transaction.update(value: value))
                    viewModel.updateValues()
                }
            }

            SingleSelectionFieldView(viewModel: viewModel.propertyTypeField) { value in
                Task {
                    await viewModel.form.commit(Field.propertyType.update(value: value))
                    viewModel.updateValues()
                }
            }

            FieldView(viewModel: viewModel.priceMinField)

            FieldView(viewModel: viewModel.priceMaxField)

            SingleSelectionFieldView(viewModel: viewModel.rentingPeriodField) { value in
                Task {
                    await viewModel.form.commit(Field.rentingPeriod.update(value: value))
                    viewModel.updateValues()
                }
            }

            MultiSelectionFieldView(viewModel: viewModel.featuresField) { value in
                Task {
                    if let featuresSet = Field.features.value(viewModel.form) {
                        var new = featuresSet
                        if new.contains(value) {
                            new.remove(value)
                        } else {
                            new.insert(value)
                        }
                        await viewModel.form.commit(Field.features.update(value: new))
                        viewModel.updateValues()
                    }
                }
            }
            
            Spacer()
        }
        .task {
            viewModel.updateValues()
        }
        .padding()
    }
}

struct FieldView<T>: View {
    @ObservedObject var viewModel: FieldViewModel<T>

    var body : some View {
        Group {
            if let value = viewModel.value {
                VStack {
                    HStack {
                        Text("\(viewModel.id.rawValue.capitalized)")
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    HStack {
                        Text("\(value)")
                            .font(.body)
                            .fontWeight(.light)
                        Spacer()
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

struct SingleSelectionFieldView<T: Hashable>: View {
    @ObservedObject var viewModel: SingleSelectionFieldViewModel<T>
    let output: (T) -> Void

    init(viewModel: SingleSelectionFieldViewModel<T>, output: @escaping (T) -> Void) {
        self.viewModel = viewModel
        self.output = output
    }

    var body : some View {
        Group {
            if let value = viewModel.value {
                VStack {
                    HStack {
                        Text("\(viewModel.id.rawValue.capitalized)")
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    HStack {
                        ForEach(viewModel.possibleValues, id: \.self) { possibleValue in
                            Button {
                                output(possibleValue)
                            } label: {
                                Text("\(possibleValue)")
                                    .font(.body)
                                    .fontWeight(.light)
                                    .foregroundStyle(possibleValue == value ? Color.accentColor : .black)
                            }
                        }
                        Spacer()
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

struct MultiSelectionFieldView<T: Hashable>: View {
    @ObservedObject var viewModel: MultiSelectionFieldViewModel<T>
    let output: (T) -> Void

    init(viewModel: MultiSelectionFieldViewModel<T>, output: @escaping (T) -> Void) {
        self.viewModel = viewModel
        self.output = output
    }

    var body : some View {
        Group {
            if let value = viewModel.value, let possibleValues = viewModel.possibleValues {
                VStack {
                    HStack {
                        Text("\(viewModel.id.rawValue.capitalized)")
                            .font(.body)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    HStack {
                        ForEach(possibleValues, id: \.self) { possibleValue in
                            Button {
                                output(possibleValue)
                            } label: {
                                Text("\(possibleValue)")
                                    .font(.body)
                                    .fontWeight(.light)
                                    .foregroundStyle(value.contains(possibleValue) ? Color.accentColor : .black)
                            }
                        }
                        Spacer()
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    let viewModel = FormViewModel()
    return FormScreenView(viewModel: viewModel)
}
