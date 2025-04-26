import SwiftUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: ListViewModel
    @State private var item: String = ""
    @State private var units: String = "1"
    @State private var measure: String = ""
    @FocusState private var isItemFieldFocused: Bool

    private var addButton: some View {
        Button(action: {
            addItemPressed()
            dismiss()
        }, label: {
            Text("Add Item to List")
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.cornerRadius(10))
                .foregroundColor(.white)
                .font(.headline)
        })
        .padding(.horizontal)
    }

    func addItemPressed() {
        let newItem = ItemModel(
            image: "",
            name: item,
            units: Int(units) ?? 1,
            measure: measure,
            price: 0.0,
            isChecked: false
        )
        listViewModel.addItem(newItem)
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

    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter Item Name", text: $item)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .focused($isItemFieldFocused)

            HStack(spacing: 10) {
                TextField("Units", text: $units)
                    .frame(width: 50)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)

                TextField("Unit", text: $measure)
                    .multilineTextAlignment(.leading)
                    .textFieldStyle(.roundedBorder)

                Spacer()

                HStack(spacing: 10) {
                    Button(action: decrementUnits) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 28))
                            .foregroundColor(Color.accentColor)
                    }

                    Button(action: incrementUnits) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 28))
                            .foregroundColor(Color.accentColor)
                    }
                }
            }
            .padding(.horizontal)

            addButton
        }
        .onAppear {
            isItemFieldFocused = true
        }
    }
}

#Preview {
    AddItemView().environmentObject(ListViewModel())
}
