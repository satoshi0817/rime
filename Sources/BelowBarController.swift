import AppKit
import ApplicationServices
import SwiftUI

private struct ExtraItem: Identifiable {
    let id: String
    let name: String
    let icon: NSImage?
    let element: AXUIElement
    let x: CGFloat
}

@MainActor
final class BelowBarController {
    private weak var anchor: NSStatusBarButton?
    private let preferences: Preferences
    private let alwaysBoundary: () -> CGFloat
    private let fallbackReveal: () -> Void
    private var panel: NSPanel?
    private var includeAlwaysHidden = false

    init(anchor: NSStatusBarButton, preferences: Preferences,
         alwaysBoundary: @escaping () -> CGFloat, fallbackReveal: @escaping () -> Void) {
        self.anchor = anchor
        self.preferences = preferences
        self.alwaysBoundary = alwaysBoundary
        self.fallbackReveal = fallbackReveal
    }

    func toggle(includeAlwaysHidden: Bool) {
        if panel?.isVisible == true && self.includeAlwaysHidden == includeAlwaysHidden {
            close()
            return
        }
        self.includeAlwaysHidden = includeAlwaysHidden
        show()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func show() {
        guard let anchor, let screen = anchor.window?.screen ?? NSScreen.main else { return }
        let trusted = AXIsProcessTrusted()
        let alwaysBoundary = preferences.alwaysHiddenEnabled && !includeAlwaysHidden
            ? self.alwaysBoundary()
            : -CGFloat.greatestFiniteMagnitude
        let items = trusted ? discoverItems(anchorX: anchor.window?.frame.minX ?? screen.frame.midX,
                                             minimumX: alwaysBoundary) : []
        let height: CGFloat = trusted ? min(390, max(166, CGFloat((items.count + 5) / 6) * 88 + 102)) : 205
        let width: CGFloat = 620
        let x = min(max((anchor.window?.frame.midX ?? screen.frame.midX) - width / 2, screen.frame.minX + 12), screen.frame.maxX - width - 12)
        let y = screen.visibleFrame.maxY - height - 8
        let rect = NSRect(x: x, y: y, width: width, height: height)

        if panel == nil {
            let newPanel = NSPanel(contentRect: rect,
                                   styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.level = .statusBar
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel = newPanel
        }
        panel?.setFrame(rect, display: true)
        panel?.contentView = NSHostingView(rootView: BelowBarView(
            items: items,
            trusted: trusted,
            includeAlwaysHidden: includeAlwaysHidden,
            preferences: preferences,
            onPress: { [weak self] item in self?.press(item) },
            onRequestAccess: { [weak self] in self?.requestAccess() },
            onRefresh: { [weak self] in self?.show() },
            onFallback: { [weak self] in self?.showInMenuBar() },
            onClose: { [weak self] in self?.close() }
        ))
        panel?.orderFrontRegardless()
    }

    private func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // The user grants this in System Settings; Refresh re-reads the new state.
    }

    private func press(_ item: ExtraItem) {
        let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
        if result == .success { close() }
        else { showInMenuBar() }
    }

    private func showInMenuBar() {
        close()
        fallbackReveal()
    }

    private func discoverItems(anchorX: CGFloat, minimumX: CGFloat) -> [ExtraItem] {
        var result: [ExtraItem] = []
        for application in NSWorkspace.shared.runningApplications where application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            let element = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.3)
            guard let rawMenu = attribute(kAXExtrasMenuBarAttribute, of: element),
                  CFGetTypeID(rawMenu) == AXUIElementGetTypeID() else { continue }
            let menu = rawMenu as! AXUIElement
            collect(from: menu, application: application, depth: 0, anchorX: anchorX,
                    minimumX: minimumX, into: &result)
        }
        return result.sorted { $0.x < $1.x }
    }

    private func collect(from element: AXUIElement, application: NSRunningApplication,
                         depth: Int, anchorX: CGFloat, minimumX: CGFloat, into items: inout [ExtraItem]) {
        guard depth <= 3 else { return }
        let role = attribute(kAXRoleAttribute, of: element) as? String
        if role == (kAXMenuBarItemRole as String), let x = positionX(of: element),
           x < anchorX - 4, x > minimumX {
            let rawName = (attribute(kAXDescriptionAttribute, of: element) as? String)
                ?? (attribute(kAXTitleAttribute, of: element) as? String)
            let name = rawName?.isEmpty == false ? rawName! : (application.localizedName ?? "メニュー項目")
            let id = "\(application.processIdentifier)-\(x)-\(name)"
            items.append(ExtraItem(id: id, name: name, icon: application.icon, element: element, x: x))
            return
        }
        guard let children = attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] else { return }
        for child in children {
            collect(from: child, application: application, depth: depth + 1,
                    anchorX: anchorX, minimumX: minimumX, into: &items)
        }
    }

    private func positionX(of element: AXUIElement) -> CGFloat? {
        guard let rawValue = attribute(kAXPositionAttribute, of: element),
              CFGetTypeID(rawValue) == AXValueGetTypeID() else { return nil }
        let raw = rawValue as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(raw, .cgPoint, &point) else { return nil }
        return point.x
    }

    private func attribute(_ key: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }
}

private struct BelowBarView: View {
    let items: [ExtraItem]
    let trusted: Bool
    let includeAlwaysHidden: Bool
    @ObservedObject var preferences: Preferences
    let onPress: (ExtraItem) -> Void
    let onRequestAccess: () -> Void
    let onRefresh: () -> Void
    let onFallback: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(preferences.accent == 0 ? .blue : .teal)
                Text(includeAlwaysHidden ? "すべての隠した項目" : "隠した項目")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("バー内で表示", action: onFallback)
                    .help("元のメニューバーに一時表示")
                Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }
                    .help("一覧を更新")
                Button(action: onClose) { Image(systemName: "xmark") }
                    .help("閉じる")
            }
            .buttonStyle(.plain)

            if !trusted {
                VStack(alignment: .leading, spacing: 9) {
                    Text("下に表示するにはアクセシビリティの許可が必要です。")
                        .font(.system(size: 12))
                    Text("項目の名前と位置を読み取り、選んだ項目を開くために使います。画面は記録しません。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Button("アクセスを許可…", action: onRequestAccess)
                }
            } else if items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("表示できる項目がありません")
                        .font(.system(size: 13, weight: .medium))
                    Text("アイコンを ⌘ ドラッグで仕切りの左へ移動し、更新してください。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(items) { item in
                            Button { onPress(item) } label: {
                                VStack(spacing: 7) {
                                    if let icon = item.icon {
                                        Image(nsImage: icon).resizable().interpolation(.high)
                                            .frame(width: 24, height: 24)
                                    } else {
                                        Image(systemName: "app").frame(width: 24, height: 24)
                                    }
                                    Text(item.name).font(.system(size: 10)).lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 68)
                                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .belowBarGlass()
    }
}

private extension View {
    @ViewBuilder func belowBarGlass() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 23))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 23))
                .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.white.opacity(0.18)))
        }
    }
}
