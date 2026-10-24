import Testing
@testable import HavenSecurity

@Suite struct OriginPolicyTests {
    @Test func exactHttpsHostIsAllowed() {
        #expect(OriginPolicy.allows(site: "github.com", pageURL: "https://github.com/login"))
        #expect(OriginPolicy.allows(site: "github.com", pageURL: "https://www.github.com/login?next=/"))
        #expect(OriginPolicy.allows(site: "https://GitHub.com/anything", pageURL: "https://github.com"))
    }

    @Test func plainHttpIsRefused() {
        #expect(!OriginPolicy.allows(site: "github.com", pageURL: "http://github.com/login"))
    }

    @Test func lookalikeAndSubdomainHostsAreRefused() {
        for page in ["https://github.com.evil.example/login", "https://evilgithub.com", "https://login.github.com",
                     "https://github.co", "https://githuЬ.com", "https://github.com@evil.example/"] {
            #expect(!OriginPolicy.allows(site: "github.com", pageURL: page), "\(page)")
        }
    }

    @Test func embeddedUserInfoIsRefused() {
        #expect(!OriginPolicy.allows(site: "github.com", pageURL: "https://user:pw@github.com/"))
    }

    @Test func garbageIsRefused() {
        #expect(!OriginPolicy.allows(site: "github.com", pageURL: "not a url"))
        #expect(!OriginPolicy.allows(site: "github.com", pageURL: ""))
        #expect(!OriginPolicy.allows(site: "github.com", pageURL: "javascript:alert(1)"))
    }
}
