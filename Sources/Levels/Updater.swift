import AppKit
import LevelsCore
import Security

/// Keeps Levels up to date the same way however it was installed (Homebrew, the
/// install script, by hand). It reads the latest release's `update.json` at launch and
/// once a day; installing downloads the zip, checks its signature and contents, swaps
/// the app in place and relaunches. The Homebrew cask says `auto_updates true`, so
/// `brew upgrade` leaves updates to the app.
///
/// It installs without asking only when Levels is signed with a Developer ID. An
/// ad-hoc signed build looks like a new app to macOS after every update and loses the
/// audio permission, so then it only offers the update in the panel.
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case available(UpdateManifest)
        case installing(UpdateManifest)
        /// Couldn't replace the app where it is (not writable, run from a translocated
        /// copy) or the download didn't check out: the panel offers the download page.
        case failed(UpdateManifest)
    }

    static let shared = Updater()
    static let releasesPage = URL(string: "https://github.com/rafaelisdev/levels/releases/latest")!

    /// Public half of the key release zips are signed with (scripts/sign_update.swift).
    private static let publicKey = "4TMvlyW+5JzqSZO4Bf9zhY5V03Q8RAVXoNMO98woPCc="
    private static let feed = URL(string: "https://github.com/rafaelisdev/levels/releases/latest/download/update.json")!
    private static let checkInterval: TimeInterval = 24 * 3600
    private static let lastCheckKey = "lastUpdateCheck"

    @Published private(set) var state = State.idle

    /// Asked before installing unattended: restarting Levels drops its taps for a
    /// moment, so nothing should be playing and the panel should be closed.
    var canInstallUnattended: () -> Bool = { false }

    private let appURL = Bundle.main.bundleURL
    private let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init)
    /// The Developer ID team Levels is signed by; nil for ad-hoc builds. Updates must
    /// come from the same team.
    private let teamID = Updater.signingTeam()
    private var timer: Timer?

    func start() {
        // Only a real app bundle updates itself, not a dev build run from .build.
        guard appURL.pathExtension == "app", current != nil, timer == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.check() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.tick() }
        if DebugFlags.debug { listenForDebugCommands() }
    }

    private func tick() {
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(last) >= Self.checkInterval { check() }
        if case .available = state, teamID != nil, canInstallUnattended() { install() }
    }

    func check() {
        UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
        let request = URLRequest(url: DebugFlags.updateFeed ?? Self.feed,
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let data, Self.succeeded(response),
                  let manifest = try? JSONDecoder().decode(UpdateManifest.self, from: data) else { return }
            DispatchQueue.main.async { self?.offer(manifest) }
        }.resume()
    }

    private func offer(_ manifest: UpdateManifest) {
        guard let current, let version = AppVersion(manifest.version), version > current,
              let minimum = AppVersion(manifest.minimumSystemVersion), minimum <= .system else { return }
        if case .installing = state { return }
        log("update \(manifest.version) available")
        state = .available(manifest)
    }

    /// Download, verify, swap, relaunch. On any failure the app stays as it was.
    func install() {
        guard case .available(let manifest) = state else { return }
        guard canReplaceApp else {
            state = .failed(manifest)
            return
        }
        state = .installing(manifest)
        URLSession.shared.downloadTask(with: manifest.url) { [weak self] file, response, _ in
            guard let self else { return }
            // The downloaded file is deleted when this block returns, so stage it here.
            let staged = Result { try self.stage(file, response: response, manifest: manifest) }
            DispatchQueue.main.async { self.finish(staged, manifest: manifest) }
        }.resume()
    }

    // MARK: Steps

    private enum Failure: Error {
        case download, signature, contents
    }

    /// Checks the signature, unpacks the zip next to the app (same volume, so the swap
    /// is a rename) and makes sure it holds Levels, at the promised version, intact.
    private func stage(_ file: URL?, response: URLResponse?, manifest: UpdateManifest) throws -> URL {
        guard let file, Self.succeeded(response) else { throw Failure.download }
        let zip = try Data(contentsOf: file)
        guard UpdateSignature.isValid(zip, signature: manifest.signature, publicKey: Self.publicKey) else {
            throw Failure.signature
        }
        let folder = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                 appropriateFor: appURL, create: true)
        do {
            let archive = folder.appendingPathComponent("Levels.zip")
            try zip.write(to: archive)
            try Self.run("/usr/bin/ditto", "-x", "-k", archive.path, folder.path)
            let app = folder.appendingPathComponent("Levels.app")
            let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
            guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                  info?["CFBundleShortVersionString"] as? String == manifest.version,
                  Self.isIntact(app, team: teamID) else { throw Failure.contents }
            return app
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    private func finish(_ staged: Result<URL, Error>, manifest: UpdateManifest) {
        do {
            let app = try staged.get()
            // The running copy keeps its open files; the relaunch starts the new one.
            let replaced = Result {
                try FileManager.default.replaceItemAt(appURL, withItemAt: app, backupItemName: nil,
                                                      options: .usingNewMetadataOnly)
            }
            try? FileManager.default.removeItem(at: app.deletingLastPathComponent())   // the staging folder
            _ = try replaced.get()
            log("installed \(manifest.version), relaunching")
            relaunch()
        } catch {
            log("update failed: \(error)")
            state = .failed(manifest)
        }
    }

    /// Quit, and open the new copy once this process is gone (never two at once).
    private func relaunch() {
        let waiter = Process()
        waiter.executableURL = URL(fileURLWithPath: "/bin/sh")
        waiter.arguments = ["-c", "while /bin/kill -0 \(getpid()) 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$0\"",
                            appURL.path]
        // Not tied to our pipes, so it outlives us.
        waiter.standardInput = FileHandle.nullDevice
        waiter.standardOutput = FileHandle.nullDevice
        waiter.standardError = FileHandle.nullDevice
        do {
            try waiter.run()
            NSApp.terminate(nil)
        } catch {
            // Already installed; it takes effect on the next launch.
            state = .idle
        }
    }

    // MARK: Checks

    private var canReplaceApp: Bool {
        let files = FileManager.default
        return !appURL.path.contains("/AppTranslocation/")
            && files.isWritableFile(atPath: appURL.deletingLastPathComponent().path)
            && files.isWritableFile(atPath: appURL.path)
    }

    private static func succeeded(_ response: URLResponse?) -> Bool {
        (response as? HTTPURLResponse).map { $0.statusCode == 200 } ?? (response != nil)   // file:// in tests
    }

    /// The bundle's code signature is valid (nothing changed after signing) and, for a
    /// Developer ID build, comes from the same team.
    private static func isIntact(_ app: URL, team: String?) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        if let team {
            let text = "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\"" as CFString
            guard SecRequirementCreateWithString(text, [], &requirement) == errSecSuccess else { return false }
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }

    private static func signingTeam() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess
        else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }

    private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure.contents }
    }

    // MARK: Debug

    /// `update:check` and `update:install` through the debug notification (`--debug`).
    private func listenForDebugCommands() {
        let name = Notification.Name("io.github.rafaelisdev.levels.debug")
        DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            switch note.object as? String {
            case "update:check": self?.check()
            case "update:install": self?.install()
            default: break
            }
        }
    }

    private func log(_ text: String) {
        guard DebugFlags.debug else { return }
        print(text)
        fflush(stdout)
    }
}
