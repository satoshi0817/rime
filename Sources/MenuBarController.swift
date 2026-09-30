import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let preferences: Preferences
    private let openSettings: () -> Void
    private let bar = NSStatusBar.system
    private var toggle: NSStatusItem!
    private var hiddenDivider: NSStatusItem!
    private var alwaysDivider: NSStatusItem!
    private var hiddenExpanded = false
    private var alwaysExpanded = false
    private var collapseTimer: Timer?
    private var observations = Set<AnyCancellable>()
    private var belowBar: BelowBarController?
    private let compactWidth: CGFloat = 12
    private let concealedWidth: CGFloat = 10_000

    init(preferences: Preferences, openSettings: @escaping () -> Void) {
        self.preferences = preferences
        self.openSettings = openSettings
        super.init()
        hiddenExpanded = !preferences.startCollapsed
        alwaysExpanded = !preferences.startCollapsed
        installItems()
        observePreferences()
        startPointerMonitor()
    }

    private func installItems() {
        // NSStatusBar lays out newly created items to the left of existing ones.
        toggle = bar.statusItem(withLength: NSStatusItem.squareLength)
        toggle.autosaveName = "Rime.Toggle"
        toggle.button?.image = NSImage(systemSymbolName: "chevron.left.2", accessibilityDescription: "Rime の隠し項目")
        toggle.button?.image?.isTemplate = true
        toggle.button?.toolTip = "クリックで表示 / 収納 · Option クリックですべて表示 · 右クリックでメニュー"
        toggle.button?.target = self
        toggle.button?.action = #selector(toggleClicked)
        toggle.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        hiddenDivider = bar.statusItem(withLength: hiddenExpanded ? compactWidth : concealedWidth)
        hiddenDivider.autosaveName = "Rime.HiddenDivider"
        configureDivider(hiddenDivider, description: "隠す項目の境界")

        alwaysDivider = bar.statusItem(withLength: alwaysExpanded ? compactWidth : concealedWidth)
        alwaysDivider.autosaveName = "Rime.AlwaysDivider"
        configureDivider(alwaysDivider, description: "常時隠す項目の境界")
        alwaysDivider.isVisible = preferences.alwaysHiddenEnabled
        updateImage()
    }

    private func configureDivider(_ item: NSStatusItem, description: String) {
        item.button?.title = "│"
        item.button?.font = .systemFont(ofSize: 11, weight: .light)
        item.button?.toolTip = "\(description) · Command を押しながらドラッグして位置を調整"
        item.button?.target = self
        item.button?.action = #selector(dividerClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.setAccessibilityLabel(description)
    }

    private func observePreferences() {
        preferences.$alwaysHiddenEnabled.dropFirst().sink { [weak self] enabled in
            guard let self else { return }
            self.alwaysExpanded = false
            self.alwaysDivider.length = self.concealedWidth
            self.alwaysDivider.isVisible = enabled
            self.updateImage()
        }.store(in: &observations)
        preferences.$autoCollapse.dropFirst().sink { [weak self] _ in self?.scheduleCollapse() }.store(in: &observations)
        preferences.$collapseDelay.dropFirst().sink { [weak self] _ in self?.scheduleCollapse() }.store(in: &observations)
        preferences.$revealLocation.dropFirst().sink { [weak self] _ in
            self?.belowBar?.close()
            self?.setExpanded(hidden: false, always: false)
        }.store(in: &observations)
    }

    private func startPointerMonitor() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkPointer() }
        }
    }

    private func checkPointer() {
        guard preferences.autoCollapse, hiddenExpanded || alwaysExpanded else { return }
        if preferences.waitForPointer && pointerIsInMenuBar {
            collapseTimer?.invalidate()
            collapseTimer = nil
        } else if collapseTimer == nil {
            scheduleCollapse()
        }
    }

    private var pointerIsInMenuBar: Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else { return false }
        return NSEvent.mouseLocation.y >= screen.frame.maxY - max(screen.frame.maxY - screen.visibleFrame.maxY, 25)
    }

    @objc private func toggleClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else if event?.modifierFlags.contains(.option) == true {
            reveal(all: true)
        } else {
            reveal(all: false)
        }
    }

    private func reveal(all: Bool) {
        if preferences.revealLocation == 1 {
            if belowBar == nil {
                belowBar = BelowBarController(anchor: toggle.button!, preferences: preferences,
                                              alwaysBoundary: { [weak self] in
                    self?.alwaysDivider.button?.window?.frame.maxX ?? -CGFloat.greatestFiniteMagnitude
                })
            }
            belowBar?.toggle(includeAlwaysHidden: all)
        } else {
            setExpanded(hidden: !hiddenExpanded || all, always: all)
        }
    }

    @objc private func dividerClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showContextMenu() }
        else { toggleClicked() }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: hiddenExpanded ? "隠す" : "隠した項目を表示", action: #selector(toggleHidden), keyEquivalent: "")
        menu.addItem(withTitle: "すべて表示", action: #selector(showAll), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "設定…", action: #selector(openSettingsAction), keyEquivalent: "")
        menu.addItem(withTitle: "Rime を終了", action: #selector(quit), keyEquivalent: "")
        for item in menu.items { item.target = self }
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent ?? NSEvent(), for: toggle.button!)
    }

    @objc private func toggleHidden() { reveal(all: false) }
    @objc private func showAll() { reveal(all: true) }
    @objc private func openSettingsAction() { openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func setExpanded(hidden: Bool, always: Bool) {
        belowBar?.close()
        hiddenExpanded = hidden
        alwaysExpanded = always && preferences.alwaysHiddenEnabled
        animate(hiddenDivider, to: hiddenExpanded ? compactWidth : concealedWidth)
        animate(alwaysDivider, to: alwaysExpanded ? compactWidth : concealedWidth)
        updateImage()
        scheduleCollapse()
    }

    private func updateImage() {
        let symbol = hiddenExpanded ? "chevron.right.2" : "chevron.left.2"
        toggle.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: hiddenExpanded ? "項目を隠す" : "隠した項目を表示")
        toggle.button?.image?.isTemplate = true
    }

    private func scheduleCollapse() {
        collapseTimer?.invalidate()
        collapseTimer = nil
        guard preferences.autoCollapse, hiddenExpanded || alwaysExpanded else { return }
        if preferences.waitForPointer && pointerIsInMenuBar { return }
        collapseTimer = Timer.scheduledTimer(withTimeInterval: max(1, preferences.collapseDelay), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.collapseTimer = nil
                if self.preferences.waitForPointer && self.pointerIsInMenuBar { return }
                self.setExpanded(hidden: false, always: false)
            }
        }
    }

    private func animate(_ item: NSStatusItem, to target: CGFloat) {
        // Resizing a 10,000 pt divider frame by frame makes every status item
        // relayout and can visibly jitter. Keep the bar instantaneous; animate
        // only the settings controls where motion has a useful spatial meaning.
        item.length = target
    }
}
