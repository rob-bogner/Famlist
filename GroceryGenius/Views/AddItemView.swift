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
        VStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    TextField("Enter Item Name", text: $item)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .focused($isItemFieldFocused)

                    HStack(spacing: 10) {
                        TextField("Units", text: $units)
                            .keyboardType(.numberPad)
                            .frame(width: 70)
                            .multilineTextAlignment(.leading)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)

                        TextField("Measure", text: $measure)
                            .multilineTextAlignment(.leading)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: decrementUnits) {
                                Image(systemName: "minus.circle")
                                    .font(.title)
                                    .foregroundColor(Color.accentColor)
                            }

                            Button(action: incrementUnits) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                    .foregroundColor(Color.accentColor)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    addButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            isItemFieldFocused = true
        }
    }
}

#Preview {
    AddItemView().environmentObject(ListViewModel())
}
