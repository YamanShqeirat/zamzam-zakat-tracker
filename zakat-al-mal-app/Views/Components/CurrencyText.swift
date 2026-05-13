import SwiftUI

struct CurrencyText: View {
    let amount: Decimal
    var currencyCode: String = "USD"

    var body: some View {
        Text(amount.formatted(.currency(code: currencyCode)))
    }
}

#Preview {
    VStack(alignment: .leading) {
        CurrencyText(amount: 1234.56)
        CurrencyText(amount: 47832).font(.largeTitle)
    }
    .padding()
}
