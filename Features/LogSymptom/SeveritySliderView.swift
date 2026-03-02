import SwiftUI
import UIKit

struct SeveritySliderView: View {
    @Binding var value: Double

    private let thumbSize: CGFloat = 30
    private let trackHeight: CGFloat = 10

    var body: some View {
        VStack(spacing: Theme.spacingM) {
            // Value row
            HStack(alignment: .lastTextBaseline, spacing: Theme.spacingS) {
                Text("\(Int(value))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(severityColor)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.25), value: value)

                Text("/ 10")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(severityEmoji)
                        .font(.system(size: 32))
                    Text(severityLabel)
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(severityColor)
                        .animation(.spring(duration: 0.25), value: value)
                }
            }

            // Custom gradient track
            GeometryReader { geo in
                let width = geo.size.width
                let fraction = value / 10.0

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                        .frame(height: trackHeight)

                    // Gradient fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.18, green: 0.76, blue: 0.34),
                                    Color(red: 0.98, green: 0.80, blue: 0.10),
                                    Color(red: 1.00, green: 0.50, blue: 0.12),
                                    Color(red: 0.94, green: 0.22, blue: 0.22)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(trackHeight, width * fraction),
                            height: trackHeight
                        )
                        .animation(.spring(duration: 0.2), value: value)

                    // Thumb
                    Circle()
                        .fill(severityColor)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: severityColor.opacity(0.45),
                                radius: 6, x: 0, y: 3)
                        .offset(x: max(0, min(
                            width - thumbSize,
                            width * fraction - thumbSize / 2
                        )))
                        .animation(.spring(duration: 0.2), value: value)
                }
                .frame(height: thumbSize)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let newFraction = drag.location.x / width
                            let raw = max(0, min(10, newFraction * 10))
                            let snapped = (raw).rounded()
                            if snapped != value {
                                value = snapped
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                )
            }
            .frame(height: thumbSize)

            // Step labels
            HStack {
                Text("0")
                Spacer()
                Text("5")
                Spacer()
                Text("10")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    private var severityColor: Color {
        Theme.severityColor(for: Int(value))
    }

    private var severityLabel: String {
        switch Int(value) {
        case 0:     return "None"
        case 1...3: return "Mild"
        case 4...5: return "Moderate"
        case 6...7: return "Severe"
        case 8...9: return "Very severe"
        default:    return "Unbearable"
        }
    }

    private var severityEmoji: String {
        switch Int(value) {
        case 0:     return "😊"
        case 1...3: return "🙂"
        case 4...5: return "😐"
        case 6...7: return "😖"
        case 8...9: return "😣"
        default:    return "😫"
        }
    }
}

#Preview {
    VStack {
        SeveritySliderView(value: .constant(7))
            .padding()
    }
}
