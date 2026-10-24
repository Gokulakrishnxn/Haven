import Foundation
import HavenSecurity

// haven-vault login --site <host> [--field username|password] --reason "<why>"
// Asks the Haven app to fill a saved login into the field that is focused in the browser.
// The person approves with Touch ID. This command never receives the credential.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard args.first == "login" else {
    fail("usage: haven-vault login --site <host> [--field username|password] --reason \"<why>\"")
}
args.removeFirst()

var site: String?, reason = "", field = FillField.password
var i = 0
while i < args.count {
    let value = i + 1 < args.count ? args[i + 1] : nil
    switch args[i] {
    case "--site": site = value
    case "--reason": reason = value ?? ""
    case "--field":
        guard let v = value, let f = FillField(rawValue: v) else { fail("--field must be username or password") }
        field = f
    default: fail("unknown option \(args[i])")
    }
    i += 2
}
guard let site, !site.isEmpty else { fail("--site is required") }

let task = ProcessInfo.processInfo.environment["HAVEN_TASK_ID"] ?? ""
let response = VaultClient.send(WireRequest(site: site, field: field, reason: reason, task: task))
print(response.message)
exit(response.ok ? 0 : 1)
