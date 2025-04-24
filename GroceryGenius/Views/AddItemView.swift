import SwiftUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: ListViewModel
    @State private var item: String = ""
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
            units: 1,
            measure: "",
            price: 0.0,
            isChecked: false
        )
        listViewModel.addItem(newItem)
    }

    var body: some View {
        VStack {
            TextField("Enter Item Name", text: $item)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .focused($isItemFieldFocused)

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
