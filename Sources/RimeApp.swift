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
    }

    private func save(_ key: String, _ value: Any) { defaults.set(value, forKey: key) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private var controller: MenuBarController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = MenuBarController(preferences: preferences, openSettings: { [weak self] in self?.showSettings() })
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunched") || ProcessInfo.processInfo.arguments.contains("--settings") {
            defaults.set(true, forKey: "hasLaunched")
            showSettings()
        }
    }

    private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Rime 設定"
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 680, height: 500)
            window.contentView = NSHostingView(rootView: SettingsView(preferences: preferences))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
