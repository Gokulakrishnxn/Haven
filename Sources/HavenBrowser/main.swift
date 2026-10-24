import Foundation
import HavenSecurity

// haven-browser <command> [--option value ...]
//
//   status                              whether the Haven extension is connected
//   list-tabs                           open tabs (only connected sites show their titles)
//   snapshot [--tab ID]                 outline of the page with [bN] references
//   extract-text [--tab ID]             the page's visible text
//   click --ref bN                      click an element
//   type --ref bN --text "..." [--append true]   fill a field (never password fields)
//   select --ref bN --value "..."       choose a dropdown option
//   scroll --dy N [--ref bN]            scroll (positive is up)
//   navigate --url URL | open-tab --url URL | back | forward | refresh
//   activate-tab --tab ID | close-tab --tab ID | wait --ms N
//
// Works only on sites the person connected from the extension. Haven asks once per task before
// anything that changes a page. This command never receives a credential.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let name = args.first, BrowserCommand(rawValue: name) != nil else {
    fail("usage: haven-browser status|list-tabs|snapshot|extract-text|click|type|select|scroll|navigate|open-tab|back|forward|refresh|activate-tab|close-tab|wait [--option value ...]")
}
args.removeFirst()

var options: [String: String] = [:]
var i = 0
while i < args.count {
    guard args[i].hasPrefix("--"), i + 1 < args.count else { fail("options look like --name value (got \(args[i]))") }
    options[String(args[i].dropFirst(2))] = args[i + 1]
    i += 2
}

let task = ProcessInfo.processInfo.environment["HAVEN_TASK_ID"] ?? ""
let response = VaultClient.send(WireRequest(action: "browser", task: task, command: name, args: options))
print(response.message)
exit(response.ok ? 0 : 1)
