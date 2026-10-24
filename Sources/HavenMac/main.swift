import Foundation
import HavenSecurity

// haven-mac <command> [--option value ...]
//
//   status                              whether Haven can control apps
//   list-apps                           running apps
//   list-windows                        on-screen windows
//   snapshot [--app NAME]               outline of the app's front window, with [eN] references
//   click --ref eN | --x N --y N        press an element or click a point
//   type --text "..." [--ref eN]        type text (never into password fields)
//   key --combo cmd+s                   press a key combination
//   scroll --dy N [--ref eN]            scroll (positive is up)
//   open-app --name NAME                launch an app
//   activate-app --name NAME            bring an app to the front
//
// Haven asks the person once per task before anything that changes the screen.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let name = args.first, MacCommand(rawValue: name) != nil else {
    fail("usage: haven-mac status|list-apps|list-windows|snapshot|click|type|key|scroll|open-app|activate-app [--option value ...]")
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
let response = VaultClient.send(WireRequest(action: "mac", task: task, command: name, args: options))
print(response.message)
exit(response.ok ? 0 : 1)
