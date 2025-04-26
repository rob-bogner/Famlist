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

    private var unitsInt: Int {
        get { Int(units) ?? 1 }
        set { units = String(newValue) }
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    // Einheit TextField - linksbündig
                    TextField("Einheiten", text: $units)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)

                    // Maß-Einheit TextField - linksbündig
                    TextField("Maßeinheit", text: $measure)
                        .multilineTextAlignment(.leading)
                        .textFieldStyle(.roundedBorder)
                    
                    Spacer()
                    
                    // Plus / Minus Buttons - rechtsbündig
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

                TextField("Preis", text: $price)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Symbol", text: $image)
                    .textFieldStyle(.roundedBorder)

                Toggle("Abgehakt", isOn: $isChecked)
            }
            .padding()

            HStack {
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
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .padding(.top)
        .navigationTitle("Item bearbeiten")
        .onAppear {
            name = item.name
            units = String(item.units)
            measure = item.measure
            price = String(item.price)
            image = item.image
            isChecked = item.isChecked
        }
    }

    private func decrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits > 1 {
            currentUnits -= 1
            units = String(currentUnits)
        }
        print("Nach dem Decrement: \(units)")
    }

    private func incrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits < 999 {
            currentUnits += 1
            units = String(currentUnits)
        }
        print("Nach dem Increment: \(units)")
    }

    func saveChanges() {
        let updatedItem = ItemModel(
            id: item.id,
            image: image,
            name: name,
            units: Int(units) ?? 1,
            measure: measure,
            price: Double(price) ?? 0.0,
            isChecked: isChecked
        )
        listViewModel.updateItem(updatedItem)
    }
}

#Preview {
    EditItemView(item: ItemModel(name: "Milch"))
        .environmentObject(ListViewModel())
}
