import Cocoa
import Foundation

class MenuBarManager: NSObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let agyBin: String

    override init() {
        let candidates = [
            "/opt/homebrew/bin/agy-switch",
            "/usr/local/bin/agy-switch",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/agy-switch").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("antigravity-account-switcher/switcher_core.py").path
        ]
        var found = "agy-switch"
        for p in candidates {
            if FileManager.default.fileExists(atPath: p) {
                found = p
                break
            }
        }
        self.agyBin = found
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle.fill", accessibilityDescription: "Antigravity Switcher") {
                img.isTemplate = true
                button.image = img
            }
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "Antigravity Switcher"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshUI()
    }

    func runProcess(_ args: [String], background: Bool = true) {
        let task = Process()
        task.launchPath = "/bin/bash"
        let fullCmd = "\"\(agyBin)\" " + args.map { "\"\($0)\"" }.joined(separator: " ")
        task.arguments = ["-c", fullCmd]
        task.launch()
        if !background {
            task.waitUntilExit()
        }
    }

    func getCurrentKeychainToken() -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/security"
        task.arguments = ["find-generic-password", "-s", "gemini", "-a", "antigravity", "-w"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           str.hasPrefix("go-keyring-base64:") {
            return str
        }
        return nil
    }

    func loadManifest() -> [String: [String: Any]] {
        let manifestPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/accounts/manifest.json").path
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return [:]
        }
        return json
    }

    func refreshUI() {
        let currToken = getCurrentKeychainToken()
        let manifest = loadManifest()
        var activeKey: String? = nil

        if let tok = currToken {
            for (k, v) in manifest {
                if let tf = v["token_file"] as? String,
                   let savedTok = try? String(contentsOfFile: tf, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                   savedTok == tok {
                    activeKey = k
                    break
                }
            }
        }

        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                let label = activeKey ?? (currToken != nil ? "Active" : "Offline")
                button.imagePosition = .imageOnly
                button.title = ""
                button.toolTip = "Antigravity Switcher [\(label)]"
            }
        }
    }

    // NSMenuDelegate
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let currToken = getCurrentKeychainToken()
        let manifest = loadManifest()
        var activeKey: String? = nil

        if let tok = currToken {
            for (k, v) in manifest {
                if let tf = v["token_file"] as? String,
                   let savedTok = try? String(contentsOfFile: tf, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                   savedTok == tok {
                    activeKey = k
                    break
                }
            }
        }

        // Header Item
        let headerTitle = activeKey != nil ? "🟢 Active: \(activeKey!)" : (currToken != nil ? "🟢 Active Session (Unsaved)" : "🔴 Not Signed In")
        let headerItem = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Saved Accounts Section
        let sortedKeys = manifest.keys.sorted()
        if !sortedKeys.isEmpty {
            for k in sortedKeys {
                let isActive = (k == activeKey)
                let item = NSMenuItem(title: "\(isActive ? "✓ " : "  ")\(k)", action: isActive ? nil : #selector(onSwitchAccount(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = k
                if isActive {
                    item.state = .on
                }
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // Action: Add New Account (Wizard)
        let addWizardItem = NSMenuItem(title: "➕ Add New Account (Wizard)...", action: #selector(onAddWizard), keyEquivalent: "a")
        addWizardItem.target = self
        menu.addItem(addWizardItem)

        // Action: View Quota & Limits
        let usageItem = NSMenuItem(title: "📊 View Quotas & Limits...", action: #selector(onViewUsage), keyEquivalent: "u")
        usageItem.target = self
        menu.addItem(usageItem)

        // Action: Save Current Account
        let saveItem = NSMenuItem(title: "💾 Save Current Account...", action: #selector(onSaveAccount), keyEquivalent: "s")
        saveItem.target = self
        menu.addItem(saveItem)

        // Action: Open Antigravity
        let openAppItem = NSMenuItem(title: "🚀 Open Antigravity", action: #selector(onOpenAntigravity), keyEquivalent: "")
        openAppItem.target = self
        menu.addItem(openAppItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Menu Bar Switcher", action: #selector(onQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        refreshUI()
    }

    @objc func onSwitchAccount(_ sender: NSMenuItem) {
        guard let account = sender.representedObject as? String else { return }
        runProcess(["--switch", account])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshUI()
        }
    }

    @objc func onAddWizard() {
        runProcess(["--wizard"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshUI()
        }
    }

    @objc func onViewUsage() {
        runProcess(["--usage-gui"])
    }

    @objc func onSaveAccount() {
        runProcess(["--save"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshUI()
        }
    }

    @objc func onOpenAntigravity() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["/Applications/Antigravity.app"]
        try? task.run()
    }

    @objc func onQuit() {
        NSApplication.shared.terminate(nil)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = MenuBarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        manager.setup()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
