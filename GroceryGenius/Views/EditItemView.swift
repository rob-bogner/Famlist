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

    var body: some View {
        VStack {
            Form {
                TextField("Name", text: $name)
                TextField("Einheiten", text: $units)
                    .keyboardType(.numberPad)
                TextField("Maßeinheit", text: $measure)
                TextField("Preis", text: $price)
                    .keyboardType(.decimalPad)
                TextField("Symbol", text: $image)

                Toggle("Abgehakt", isOn: $isChecked)
            }

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
