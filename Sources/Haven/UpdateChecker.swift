import Foundation
import HavenCore

/// Looks for a newer Haven release on GitHub. It only reads the public "latest release" page and sends no
/// information about you or your Mac; installing is left to the person (the link opens the release page).
@MainActor
final class UpdateChecker {
    enum State: Equatable {
        case idle, checking, upToDate, noReleases
        case available(ReleaseInfo)
        case failed(String)
    }

    static let releasesURL = URL(string: "https://api.github.com/repos/Gokulakrishnxn/Haven/releases/latest")!

    private(set) var state: State = .idle { didSet { onChange?(state) } }
    var onChange: ((State) -> Void)?

    /// Version of the running app, or nil for a development build run without an app bundle.
    let current: AppVersion? = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)

    var currentText: String { current.map(\.description) ?? "development build" }

    /// Checks at launch at most once a day, and only if the person has not turned it off.
    func checkAutomaticallyIfDue() {
        guard current != nil, Preferences.autoUpdateCheck else { return }
        if let last = Preferences.lastUpdateCheck, Date().timeIntervalSince(last) < 24 * 3600 { return }
        Task { await check() }
    }

    func check() async {
        guard let current else {
            state = .failed("Development builds do not check for updates. Build the app with scripts/build-app.sh.")
            return
        }
        state = .checking
        var request = URLRequest(url: Self.releasesURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Haven/\(current)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            Preferences.lastUpdateCheck = Date()
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 { state = .noReleases; return }
            guard status == 200 else { state = .failed("GitHub answered with status \(status)."); return }
            guard let release = ReleaseInfo.parse(data) else { state = .upToDate; return }
            state = release.isNewer(than: current) ? .available(release) : .upToDate
        } catch {
            state = .failed("Could not reach GitHub.")
        }
    }
}
