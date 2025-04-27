import SwiftUI

/// A view for adding a new item to the shopping list.
struct AddItemView: View {
    
    // MARK: - Properties
    
    /// Dismisses the current view.
    @Environment(\.dismiss) private var dismiss
    
    /// ViewModel providing the data and logic for the list.
    @EnvironmentObject var listViewModel: ListViewModel
    
    /// The entered item name.
    @State private var item: String = ""
    
    /// The entered number of units.
    @State private var units: String = "1"
    
    /// The entered measurement unit.
    @State private var measure: String = ""
    
    /// Controls whether the item text field is focused.
    @FocusState private var isItemFieldFocused: Bool

    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                TextField("Enter Item Name", text: $item)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .focused($isItemFieldFocused)

                HStack {
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

                    HStack(spacing: 10) {
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

                Spacer()

                addItemButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            isItemFieldFocused = true
        }
    }
    
    // MARK: - Subviews
    
    /// Button to add the item to the list.
    private var addItemButton: some View {
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
    
    // MARK: - Functions
    
    /// Adds a new item to the shopping list.
    private func addItemPressed() {
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

    /// Decreases the number of units by 1, with a minimum of 1.
    private func decrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits > 1 {
            currentUnits -= 1
            units = String(currentUnits)
        }
    }

    /// Increases the number of units by 1, up to a maximum of 999.
    private func incrementUnits() {
        var currentUnits = Int(units) ?? 1
        if currentUnits < 999 {
            currentUnits += 1
            units = String(currentUnits)
        }
    }
}

#Preview {
    AddItemView()
        .environmentObject(ListViewModel())
}
