import Foundation
import HavenSecurity

// haven-vault login   --site <host> [--field username|password] --reason "<why>"
// haven-vault approve --action "<what you want to do>" --reason "<why>"
//
// login:   asks the Haven app to fill a saved login into the focused browser field (Touch ID).
// approve: asks the person to allow an action before you take it. Exit status 0 means approved.
// Neither command ever receives a credential.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let usage = """
usage: haven-vault login --site <host> [--field username|password] --reason "<why>"
       haven-vault approve --action "<what>" --reason "<why>"
"""

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first, ["login", "approve"].contains(command) else { fail(usage) }
args.removeFirst()

var site: String?, reason = "", summary = "", field = FillField.password
var i = 0
while i < args.count {
    let value = i + 1 < args.count ? args[i + 1] : nil
    switch args[i] {
    case "--site": site = value
    case "--reason": reason = value ?? ""
    case "--action": summary = value ?? ""
    case "--field":
        guard let v = value, let f = FillField(rawValue: v) else { fail("--field must be username or password") }
        field = f
    default: fail("unknown option \(args[i])")
    }
    i += 2
}

let task = ProcessInfo.processInfo.environment["HAVEN_TASK_ID"] ?? ""
let request: WireRequest
if command == "login" {
    guard let site, !site.isEmpty else { fail("--site is required") }
    request = WireRequest(action: "login", site: site, field: field, reason: reason, task: task)
} else {
    guard !summary.isEmpty else { fail("--action is required") }
    request = WireRequest(action: "approve", reason: reason, task: task, summary: summary)
}
let response = VaultClient.send(request)
print(response.message)
exit(response.ok ? 0 : 1)
