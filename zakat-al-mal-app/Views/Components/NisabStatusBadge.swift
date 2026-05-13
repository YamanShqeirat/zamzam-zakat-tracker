import SwiftUI

struct NisabStatusBadge: View {
    enum State {
        case aboveNisab
        case belowNisab
        case unknown // no gold price yet
    }

    let state: State

    init(state: State) {
        self.state = state
    }

    init(isAboveNisab: Bool) {
        self.state = isAboveNisab ? .aboveNisab : .belowNisab
    }

    private var dotColor: Color {
        switch state {
        case .aboveNisab: return .green
        case .belowNisab: return .secondary
        case .unknown:    return .orange
        }
    }

    private var label: String {
        switch state {
        case .aboveNisab: return "ABOVE NISAB"
        case .belowNisab: return "BELOW NISAB"
        case .unknown:    return "AWAITING GOLD PRICE"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(dotColor)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        NisabStatusBadge(state: .aboveNisab)
        NisabStatusBadge(state: .belowNisab)
        NisabStatusBadge(state: .unknown)
    }
    .padding()
}
