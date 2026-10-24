import Testing
@testable import HavenSecurity

@Suite struct MacControlTests {
    @Test func readOnlyCommandsDoNotNeedPermission() {
        for c in [MacCommand.status, .listApps, .listWindows, .snapshot] { #expect(!c.mutates, "\(c)") }
    }

    @Test func commandsThatChangeThingsNeedPermission() {
        for c in [MacCommand.click, .type, .key, .scroll, .openApp, .activateApp] { #expect(c.mutates, "\(c)") }
    }

    @Test func passwordManagersAndSystemSettingsAreBlocked() {
        #expect(MacPolicy.isBlocked(bundleID: "com.1password.1password"))
        #expect(MacPolicy.isBlocked(bundleID: "com.apple.systempreferences"))
        #expect(MacPolicy.isBlocked(bundleID: "com.apple.keychainaccess"))
        #expect(!MacPolicy.isBlocked(bundleID: "com.apple.finder"))
        #expect(!MacPolicy.isBlocked(bundleID: nil))
    }

    @Test func keyCombosParse() {
        #expect(KeyCombo.parse("cmd+s") == KeyCombo(keyCode: 1, flags: 0x100000))
        #expect(KeyCombo.parse("Cmd+Shift+4") == KeyCombo(keyCode: 21, flags: 0x100000 | 0x20000))
        #expect(KeyCombo.parse("return") == KeyCombo(keyCode: 36, flags: 0))
        #expect(KeyCombo.parse("option+left") == KeyCombo(keyCode: 123, flags: 0x80000))
    }

    @Test func badKeyCombosAreRejected() {
        #expect(KeyCombo.parse("") == nil)
        #expect(KeyCombo.parse("banana") == nil)
        #expect(KeyCombo.parse("hyper+s") == nil)
        #expect(KeyCombo.parse("cmd+") == nil)
    }

    @Test func snapshotListsLabeledElementsWithRefs() {
        let tree = SnapshotNode(role: "AXWindow", label: "Settings", children: [
            SnapshotNode(role: "AXGroup", label: "", children: [
                SnapshotNode(role: "AXButton", label: "Save", ref: "e1", frame: (412, 640, 96, 36)),
                SnapshotNode(role: "AXTextField", label: "Name", ref: "e2"),
            ]),
        ])
        let text = SnapshotRenderer.render(tree)
        #expect(text.contains("window \"Settings\""))
        #expect(text.contains("[e1] button \"Save\" @412,640 96x36"))
        #expect(text.contains("[e2] textfield \"Name\""))
        #expect(!text.contains("group"))  // unlabeled container flattened
    }

    @Test func snapshotIsCappedAndSaysSo() {
        let many = (0..<1000).map { SnapshotNode(role: "AXButton", label: "b\($0)", ref: "e\($0)") }
        let text = SnapshotRenderer.render(SnapshotNode(role: "AXWindow", label: "W", children: many), maxLines: 50)
        #expect(text.split(separator: "\n").count <= 52)
        #expect(text.hasSuffix("(outline truncated)"))
    }
}
