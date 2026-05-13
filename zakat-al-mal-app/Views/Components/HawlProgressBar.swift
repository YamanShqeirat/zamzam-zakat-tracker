import SwiftUI

struct HawlProgressBar: View {
    let elapsedDays: Int
    let totalDays: Int
    let daysRemaining: Int

    private var progress: Double {
        guard totalDays > 0 else { return 0 }
        return min(1, max(0, Double(elapsedDays) / Double(totalDays)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            HStack {
                Text("\(elapsedDays) / \(totalDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(daysRemaining) days remaining")
                    .font(.caption.bold())
            }
        }
    }
}

#Preview {
    HawlProgressBar(elapsedDays: 247, totalDays: 354, daysRemaining: 107)
        .padding()
}
