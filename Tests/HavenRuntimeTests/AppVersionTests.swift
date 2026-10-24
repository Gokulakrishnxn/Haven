import Foundation
import Testing
import HavenCore

@Suite struct AppVersionTests {
    @Test func parsesCommonForms() {
        #expect(AppVersion("1.2.3")?.parts == [1, 2, 3])
        #expect(AppVersion("v0.10.0")?.parts == [0, 10, 0])
        #expect(AppVersion(" V2 ")?.parts == [2])
        #expect(AppVersion("1.0.0-beta.1")?.isPrerelease == true)
    }

    @Test func rejectsNonVersions() {
        for bad in ["", "v", "abc", "1.x.3", "1..2", "-1.0", "1.2.-3"] { #expect(AppVersion(bad) == nil, "\(bad)") }
    }

    @Test func ordersNumericallyNotAlphabetically() {
        #expect(AppVersion("0.10.0")! > AppVersion("0.9.0")!)
        #expect(AppVersion("1.2.0")! > AppVersion("1.1.9")!)
        #expect(AppVersion("2.0.0")! > AppVersion("1.99.99")!)
        #expect(AppVersion("1.0")! == AppVersion("1.0.0")!)
        #expect(AppVersion("1.0.0-beta")! < AppVersion("1.0.0")!)
    }

    private func release(_ json: String) -> ReleaseInfo? { ReleaseInfo.parse(Data(json.utf8)) }

    @Test func parsesAGitHubRelease() throws {
        let r = try #require(release(#"{"tag_name":"v0.2.0","html_url":"https://github.com/Gokulakrishnxn/Haven/releases/tag/v0.2.0","body":"Notes","draft":false,"prerelease":false}"#))
        #expect(r.version == AppVersion("0.2.0"))
        #expect(r.isNewer(than: AppVersion("0.1.0")!))
        #expect(!r.isNewer(than: AppVersion("0.2.0")!))
        #expect(!r.isNewer(than: AppVersion("0.3.0")!))
    }

    @Test func ignoresDraftsPrereleasesAndUnsafeLinks() {
        #expect(release(#"{"tag_name":"v9.0.0","html_url":"https://github.com/x/y","draft":true}"#) == nil)
        #expect(release(#"{"tag_name":"v9.0.0","html_url":"https://github.com/x/y","prerelease":true}"#) == nil)
        #expect(release(#"{"tag_name":"v9.0.0","html_url":"http://github.com/x/y"}"#) == nil)
        #expect(release(#"{"tag_name":"v9.0.0","html_url":"https://evil.example/download"}"#) == nil)
        #expect(release(#"{"tag_name":"not-a-version","html_url":"https://github.com/x/y"}"#) == nil)
        #expect(release("garbage") == nil)
    }
}
