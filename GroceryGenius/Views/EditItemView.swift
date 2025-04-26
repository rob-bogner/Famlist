// MARK: - EditItemView.swift

import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: ListViewModel
    let item: ItemModel

    @State private var name: String = ""
    @State private var units: String = "1"
    @State private var measure: String = ""
    @State private var price: String = "0.0"
    @State private var image: String = ""
    @State private var isChecked: Bool = false
    @FocusState private var isNameFieldFocused: Bool

    private var unitsInt: Int {
        get { Int(units) ?? 1 }
        set { units = String(newValue) }
    }
    
    private var priceFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter Item Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
                .focused($isNameFieldFocused)

            HStack {
                TextField("Units", text: $units)
                    .keyboardType(.numberPad)
                    .frame(width: 70)
                    .multilineTextAlignment(.leading)
                    .textFieldStyle(.roundedBorder)

                TextField("Measure", text: $measure)
                    .multilineTextAlignment(.leading)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        decrementUnits()
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title)
                            .foregroundColor(Color.accentColor)
                    }

                    Button(action: {
                        incrementUnits()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title)
                            .foregroundColor(Color.accentColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            TextField("Price", value: Binding(
                get: {
                    Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                },
                set: {
                    price = priceFormatter.string(from: NSNumber(value: $0)) ?? ""
                }
            ), formatter: priceFormatter)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1)

            TextField("Symbol", text: $image)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)

            Toggle("Checked", isOn: $isChecked)
            
            HStack(spacing: 8) {
                Button(action: {
                    dismiss()
                }, label: {
                    Text("Cancel")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.cornerRadius(10))
                        .foregroundColor(.white)
                        .font(.headline)
                })

                Button(action: {
                    saveChanges()
                    dismiss()
                }, label: {
                    Text("Save")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.cornerRadius(10))
                        .foregroundColor(.white)
                        .font(.headline)
                })
            }
            .padding(.top, 35)
        }
        .padding(.horizontal)
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle("Edit Item")
        .onAppear {
            name = item.name
            units = String(item.units)
            measure = item.measure
            price = String(item.price)
            image = item.image
            isChecked = item.isChecked
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isNameFieldFocused = true
            }
        }
    }

    private func decrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits > 1 {
            currentUnits -= 1
            units = String(currentUnits)
        }
//        print("Nach dem Decrement: \(units)")
    }

    private func incrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits < 999 {
            currentUnits += 1
            units = String(currentUnits)
        }
//        print("Nach dem Increment: \(units)")
    }

    func saveChanges() {
        let updatedItem = ItemModel(
            id: item.id,
            image: image,
            name: name,
            units: Int(units) ?? 1,
            measure: measure,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0,
            isChecked: isChecked
        )
        listViewModel.updateItem(updatedItem)
    }
}

#Preview {
    EditItemView(item: ItemModel(name: "Milch"))
        .environmentObject(ListViewModel())
}
