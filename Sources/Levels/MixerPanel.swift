import SwiftUI

// Written against the macOS 11 SwiftUI API set (foregroundColor, no TimelineView,
// no AnyShapeStyle, no .borderedProminent) so one UI runs on every supported system.

private extension Color {
    static let tertiaryText = Color(NSColor.tertiaryLabelColor)
}

struct MixerPanel: View {
    @ObservedObject var model: MixerModel
    var close: () -> Void = {}
    @State private var showOthers = false
    @State private var showingOutputs = false

    private var active: [AudioApp] {
        model.apps.filter { $0.isPlaying || model.volume(of: $0.id) < 1 || model.isMuted($0.id) }
            .sorted { ($0.isPlaying ? 0 : 1, $0.name) < ($1.isPlaying ? 0 : 1, $1.name) }
    }

    private var others: [AudioApp] {
        let ids = Set(active.map(\.id))
        return model.apps.filter { !ids.contains($0.id) }
    }

    var body: some View {
        Group {
            if showingOutputs {
                OutputsPage(model: model) { withAnimation(.easeInOut(duration: 0.2)) { showingOutputs = false } }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                mainPage
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 330)
    }

    private var mainPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            if model.menuBarIconHidden {
                HiddenIconNotice { model.menuBarIconHidden = false }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            masterCard
                .padding(.horizontal, 12)

            if model.perAppSupported {
                if model.permission != .authorized {
                    PermissionBanner(status: model.permission) { model.requestPermission() }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }

                SectionLabel("Apps")
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                appList

                if let error = model.errorMessage {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error).lineLimit(3)
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            } else {
                LegacyNotice(version: model.systemVersion)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
            }

            Divider().padding(.top, 6)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            LevelsMark(size: 26)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 1) {
                // Wordmark: semibold, tight tracking (-0.05 em) as on the brand board.
                Text("Levels")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.75)
                Text(LocalizedStringKey(model.perAppSupported ? "Volume for every app" : "Device volume"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: Output device

    private var masterCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                // Tapping the device opens the Outputs page (per-app volume systems only).
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showingOutputs = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: model.outputSymbol)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 14)
                        Text(model.outputName)
                            .font(.system(size: 11.5, weight: .medium))
                            .lineLimit(1)
                        if model.isSyncing {
                            Text(verbatim: "+\(model.activeOutputs.count - 1)")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 5)
                                .background(Capsule().fill(Color.primary.opacity(0.1)))
                        }
                        if model.perAppSupported {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .foregroundColor(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!model.perAppSupported)
                Spacer()
                if let v = model.masterVolume {
                    PercentText(value: model.masterMuted ? 0 : v)
                }
            }
            if let v = model.masterVolume {
                HStack(spacing: 10) {
                    Button { model.toggleMasterMute() } label: {
                        Image(systemName: speakerSymbol(model.masterMuted ? 0 : v))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.primary.opacity(0.08)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(LocalizedStringKey(model.masterMuted ? "Unmute" : "Mute"))

                    VolumeSlider(value: v, muted: model.masterMuted) { model.setMasterVolume($0) }
                }
            } else {
                Text("This device has no volume control")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    // MARK: Apps

    @ViewBuilder
    private var appList: some View {
        if model.apps.isEmpty {
            EmptyState()
        } else {
            let rows = active.count + (showOthers ? others.count : 0)
            if rows > 6 {
                ScrollView(.vertical, showsIndicators: true) {
                    appRows
                }
                .frame(height: 6 * 50 + 36)
            } else {
                appRows
            }
        }
    }

    private var appRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            if active.isEmpty {
                Text("Nothing is playing right now")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            ForEach(active) { row(for: $0) }

            if !others.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showOthers.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showOthers ? 90 : 0))
                        Text("Other apps with sound")
                        Text(verbatim: "\(others.count)")
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                        Spacer()
                    }
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if showOthers {
                    ForEach(others) { row(for: $0) }
                        .transition(.opacity)
                }
            }
        }
    }

    private func row(for app: AudioApp) -> some View {
        AppRow(app: app,
               volume: model.volume(of: app.id),
               muted: model.isMuted(app.id),
               onChange: { model.setVolume($0, for: app.id) },
               onMute: { model.toggleMute(app.id) },
               onReset: { model.reset(app.id) })
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if model.launchAtLoginSupported {
                Toggle(isOn: $model.launchAtLogin) {
                    Text("Launch at login")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)   // long translations shrink instead of wrapping
                }
                .toggleStyle(SwitchToggleStyle())
                .controlSize(.mini)
                .font(.system(size: 11.5))
            }
            Spacer()
            if model.perAppSupported {
                Button("Reset") { model.resetAll() }
                    .buttonStyle(FooterButtonStyle())
                    .fixedSize()
                    .help("Set every app back to full volume")
            }
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(FooterButtonStyle())
                .fixedSize()
                .keyboardShortcut("q")
        }
    }
}

// MARK: - App row

struct AppRow: View {
    let app: AudioApp
    let volume: Float
    let muted: Bool
    let onChange: (Float) -> Void
    let onMute: () -> Void
    let onReset: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onMute) {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 30, height: 30)
                        .saturation(muted ? 0 : 1)
                        .opacity(muted ? 0.45 : 1)
                    if muted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(Color.red))
                            .offset(x: 3, y: 3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .help(LocalizedStringKey(muted ? "Unmute" : "Mute"))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(1)
                    if app.isPlaying && !muted {
                        PlayingIndicator()
                            .transition(.opacity)
                    }
                    Spacer(minLength: 4)
                    PercentText(value: muted ? 0 : volume)
                }
                VolumeSlider(value: volume, muted: muted, onChange: onChange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.045 : 0))
                .padding(.horizontal, 6)
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: muted)
        .contextMenu {
            Button(LocalizedStringKey(muted ? "Unmute" : "Mute"), action: onMute)
            Button("Reset to full volume", action: onReset)
        }
    }
}

// MARK: - Controls

/// Thin track with an accent fill and a white knob that grows while you use it.
struct VolumeSlider: View {
    let value: Float
    var muted: Bool = false
    let onChange: (Float) -> Void

    @State private var hovering = false
    @State private var dragging = false

    private let track: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let knob: CGFloat = dragging ? 15 : (hovering ? 14 : 12)
            let x = CGFloat(min(max(value, 0), 1)) * (width - knob)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: track)

                Group {
                    if muted {
                        Capsule().fill(Color.secondary.opacity(0.45))
                    } else {
                        Capsule().fill(LinearGradient(gradient: Gradient(colors: [Color.accentColor.opacity(0.75), Color.accentColor]),
                                                      startPoint: .leading, endPoint: .trailing))
                    }
                }
                .frame(width: x + knob / 2, height: track)

                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0, y: 0.5)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                    .frame(width: knob, height: knob)
                    .offset(x: x)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !dragging { dragging = true }
                        let v = (g.location.x - knob / 2) / max(width - knob, 1)
                        onChange(Float(min(max(v, 0), 1)))
                    }
                    .onEnded { _ in dragging = false }
            )
            .animation(.easeOut(duration: 0.12), value: knob)
        }
        .frame(height: 16)
        .onHover { hovering = $0 }
    }
}

struct PercentText: View {
    let value: Float
    var body: some View {
        Text(verbatim: "\(Int((value * 100).rounded()))%")
            .font(Font.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundColor(.secondary)
            .frame(minWidth: 34, alignment: .trailing)
    }
}

/// Three little bars that bounce while the app is making sound.
struct PlayingIndicator: View {
    @State private var up = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            bar(duration: 0.42, delay: 0)
            bar(duration: 0.31, delay: 0.12)
            bar(duration: 0.50, delay: 0.05)
        }
        .frame(height: 9, alignment: .bottom)
        .onAppear { up = true }
        .help("Playing now")
    }

    private func bar(duration: Double, delay: Double) -> some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 2, height: up ? 9 : 3)
            .animation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay), value: up)
    }
}

struct SectionLabel: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)          // Text.tracking (macOS 10.15); must come before textCase
            .foregroundColor(.tertiaryText)
            .textCase(.uppercase)
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "speaker.zzz")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.tertiaryText)
            Text("No apps with sound")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text("Play music or a video and the app will show up here")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
    }
}

struct LegacyNotice: View {
    let version: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text("Per-app volume needs macOS 14.2")
                    .font(.system(size: 12, weight: .semibold))
                Text("On macOS \(version), apps can’t control each other’s sound. Device volume still works.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
    }
}

/// Shown when macOS hid the menu bar icon because the menu bar is full.
struct HiddenIconNotice: View {
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 15))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 6) {
                Text("macOS hid the Levels icon")
                    .font(.system(size: 12, weight: .semibold))
                Text("The menu bar is full, so the icon sits behind the camera notch. Hold ⌘ and drag icons to make room, or open Levels again from Spotlight to bring up this panel.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Got it", action: dismiss)
                    .buttonStyle(ProminentButtonStyle(color: .accentColor))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.10)))
    }
}

struct PermissionBanner: View {
    let status: AudioCapturePermission.Status
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(status == .denied ? "No access to app audio" : "Levels needs access to app audio"))
                    .font(.system(size: 12, weight: .semibold))
                Text(LocalizedStringKey(status == .denied
                     ? "Turn on Levels in System Settings → Privacy & Security → Screen & System Audio Recording."
                     : "macOS will ask for “System Audio Recording Only” access. Audio stays on your Mac and is never recorded."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(LocalizedStringKey(status == .denied ? "Open System Settings" : "Allow"), action: action)
                    .buttonStyle(ProminentButtonStyle(color: .orange))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}

struct ProminentButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.75 : 1))
            )
    }
}

struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.07))
            )
    }
}

func speakerSymbol(_ v: Float) -> String {
    switch v {
    case ..<0.01: return "speaker.slash.fill"
    case ..<0.34: return "speaker.wave.1.fill"
    case ..<0.67: return "speaker.wave.2.fill"
    default: return "speaker.wave.3.fill"
    }
}
