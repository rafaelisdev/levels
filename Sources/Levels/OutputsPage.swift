import SwiftUI

/// The panel's second page (no new window): which outputs apps play on, and how each
/// one is lined up with the others.
struct OutputsPage: View {
    @ObservedObject var model: MixerModel
    let back: () -> Void

    /// Outputs that get an offset slider: every playing output except a built-in one,
    /// which is the reference everything else is lined up to.
    private var adjustable: [OutputChoice] {
        model.outputs.filter { model.plays(on: $0.id) && !$0.isBuiltIn }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: back) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Outputs")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    if model.engineBusy {
                        // Taps are rebuilt in the background; the panel stays responsive.
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.45)
                            .frame(width: 14, height: 14)
                        Text("Lining up…")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)

            Text("Play on several outputs at once. Levels lines them up so they sound together.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            SectionLabel("Play on")
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            ForEach(model.outputs) { output in
                OutputRow(output: output,
                          isDefault: output.id == model.defaultOutputUID,
                          isOn: model.plays(on: output.id)) { model.toggleOutput(output.id) }
            }

            if model.isSyncing && !adjustable.isEmpty {
                SectionLabel("Sync")
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                if let summary = model.syncSummary {
                    DelayTimeline(summary: summary, outputs: model.outputs)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                ForEach(adjustable) { output in
                    OffsetRow(output: output, offset: model.syncOffset(output.id)) {
                        model.setSyncOffset($0, for: output.id)
                    }
                }
                Text("Play something with a clear beat and move a device until the echo is gone.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
        }
        .padding(.bottom, 12)
    }
}

private struct OutputRow: View {
    let output: OutputChoice
    let isDefault: Bool
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isOn ? .accentColor : Color(NSColor.tertiaryLabelColor))
                Image(systemName: output.symbol)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(output.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if isDefault {
                    Text("Default")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDefault)   // the default output always plays; change it in macOS
        .help(LocalizedStringKey(isDefault ? "The default output always plays" : ""))
    }
}

/// Offset slider for one output (by ear), with 1 ms steps for the last bit.
///
/// While dragging, the number and the knob follow the finger at once, but the audio is
/// re-timed only once the slider rests for a moment: every re-time is a short dip, and
/// a stream of them while dragging sounds rough.
private struct OffsetRow: View {
    let output: OutputChoice
    let offset: Double
    let set: (Double) -> Void

    @State private var dragValue: Double?
    @State private var pendingApply: DispatchWorkItem?

    private let range = MixerModel.offsetRange
    private var shown: Double { dragValue ?? offset }

    private func drag(to value: Double) {
        let ms = (value * 1000).rounded() / 1000
        dragValue = ms
        pendingApply?.cancel()
        let apply = DispatchWorkItem {
            set(ms)
            dragValue = nil
        }
        pendingApply = apply
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: apply)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: output.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(output.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                StepButton(symbol: "minus") { set(shown - 0.001) }
                Text(verbatim: String(format: "%+.0f ms", shown * 1000))
                    .font(Font.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 54, alignment: .center)
                StepButton(symbol: "plus") { set(shown + 0.001) }
            }
            VolumeSlider(value: Float((shown - range.lowerBound) / (range.upperBound - range.lowerBound))) { v in
                drag(to: range.lowerBound + Double(v) * (range.upperBound - range.lowerBound))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

private struct StepButton: View {
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Why there is a delay, at a glance: every output's own latency (solid) plus how long
/// Levels holds it back (light) so all of them land at the same moment.
private struct DelayTimeline: View {
    let summary: SyncSummary
    let outputs: [OutputChoice]

    private var slowest: Double { max(summary.outputs.map(\.own).max() ?? 0, 0.001) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Delay")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(verbatim: String(format: "%.0f ms", summary.delay * 1000))
                    .font(Font.system(size: 11, weight: .semibold).monospacedDigit())
            }
            ForEach(summary.outputs, id: \.uid) { output in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(outputs.first { $0.id == output.uid }?.name ?? output.uid)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                        // Two Text values, not one ternary string, so both get translated.
                        (output.held < 0.0005 ? Text("slowest") : Text("waits \(Int((output.held * 1000).rounded())) ms"))
                            .font(Font.system(size: 10.5).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * CGFloat(output.own / slowest))
                            if output.held >= 0.0005 {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity(0.25))
                            }
                        }
                    }
                    .frame(height: 5)
                    .animation(.easeInOut(duration: 0.25), value: output.own)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}
