import AppKit
import ServiceManagement
import SwiftUI

@main
struct RimeApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    @Published var autoCollapse = true { didSet { save("autoCollapse", autoCollapse) } }
    @Published var collapseDelay = 8.0 { didSet { save("collapseDelay", collapseDelay) } }
    @Published var waitForPointer = true { didSet { save("waitForPointer", waitForPointer) } }
    @Published var alwaysHiddenEnabled = true { didSet { save("alwaysHiddenEnabled", alwaysHiddenEnabled) } }
    @Published var startCollapsed = true { didSet { save("startCollapsed", startCollapsed) } }
    @Published var subtleMotion = true { didSet { save("subtleMotion", subtleMotion) } }
    @Published var accent = 0 { didSet { save("accent", accent) } }
    @Published var revealLocation = 0 { didSet { save("revealLocation", revealLocation) } }
    @Published var showDockIcon = true {
        didSet {
            save("showDockIcon", showDockIcon)
            if showDockIcon {
                NSApp.setActivationPolicy(.regular)
            } else if !NSApp.windows.contains(where: { $0.title == "Rime 設定" && $0.isVisible }) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                launchError = error.localizedDescription
            }
            objectWillChange.send()
        }
    }

    @Published var launchError: String?

    private init() {
        if defaults.object(forKey: "autoCollapse") != nil { autoCollapse = defaults.bool(forKey: "autoCollapse") }
        if defaults.object(forKey: "collapseDelay") != nil { collapseDelay = defaults.double(forKey: "collapseDelay") }
        if defaults.object(forKey: "waitForPointer") != nil { waitForPointer = defaults.bool(forKey: "waitForPointer") }
        if defaults.object(forKey: "alwaysHiddenEnabled") != nil { alwaysHiddenEnabled = defaults.bool(forKey: "alwaysHiddenEnabled") }
        if defaults.object(forKey: "startCollapsed") != nil { startCollapsed = defaults.bool(forKey: "startCollapsed") }
        if defaults.object(forKey: "subtleMotion") != nil { subtleMotion = defaults.bool(forKey: "subtleMotion") }
        if defaults.object(forKey: "accent") != nil { accent = defaults.integer(forKey: "accent") }
        if defaults.object(forKey: "revealLocation") != nil { revealLocation = defaults.integer(forKey: "revealLocation") }
        if defaults.object(forKey: "showDockIcon") != nil { showDockIcon = defaults.bool(forKey: "showDockIcon") }
    }

    private func save(_ key: String, _ value: Any) { defaults.set(value, forKey: key) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let preferences = Preferences.shared
    private var controller: MenuBarController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(preferences.showDockIcon ? .regular : .accessory)
        installAppMenu()
        controller = MenuBarController(preferences: preferences, openSettings: { [weak self] in self?.showSettings() })
        let defaults = UserDefaults.standard
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        if defaults.string(forKey: "lastPresentedVersion") != version || ProcessInfo.processInfo.arguments.contains("--settings") {
            defaults.set(version, forKey: "lastPresentedVersion")
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func installAppMenu() {
        let menuBar = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Rime")
        let settings = appMenu.addItem(withTitle: "設定…", action: #selector(showSettingsAction), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(NSMenuItem.separator())
        let quit = appMenu.addItem(withTitle: "Rime を終了", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        appItem.submenu = appMenu
        menuBar.addItem(appItem)
        NSApp.mainMenu = menuBar
    }

    @objc private func showSettingsAction() { showSettings() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Rime 設定"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 680, height: 540)
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(preferences: preferences))
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if !preferences.showDockIcon { NSApp.setActivationPolicy(.accessory) }
    }
}
