import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case overview = "使い方"
    case behavior = "動作"
    case appearance = "外観"
    case about = "Rime について"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .overview: "square.split.3x1"
        case .behavior: "slider.horizontal.3"
        case .appearance: "paintpalette"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @State private var page: SettingsPage = .overview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { preferences.accent == 0 ? Color(red: 0.31, green: 0.50, blue: 0.88) : .teal }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(.primary.opacity(0.07)).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    Group {
                        switch page {
                        case .overview: overview
                        case .behavior: behavior
                        case .appearance: appearance
                        case .about: about
                        }
                    }
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(32)
            }
        }
        .frame(minWidth: 680, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(tint)
        .animation(reduceMotion || !preferences.subtleMotion ? nil : .smooth(duration: 0.3), value: page)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 11) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 35, height: 35)
                    .glassCard(corner: 11)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rime").font(.system(size: 17, weight: .semibold))
                    Text("メニューバーを、すっきり。")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 25)

            ForEach(SettingsPage.allCases) { destination in
                Button {
                    page = destination
                } label: {
                    Label(destination.rawValue, systemImage: destination.symbol)
                        .font(.system(size: 13, weight: page == destination ? .semibold : .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundStyle(page == destination ? tint : .primary)
                        .background(page == destination ? tint.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == destination ? .isSelected : [])
            }
            Spacer()
            Text("v1.0 · macOS 15+")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.leading, 12)
        }
        .padding(19)
        .frame(width: 213)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(page.rawValue)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        switch page {
        case .overview: "最初の1分で、よく使う項目だけを残せます。"
        case .behavior: "表示と収納のタイミングを整えます。"
        case .appearance: "静かで見やすい表示に調整します。"
        case .about: "軽く、分かりやすいメニューバー管理。"
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                sectionChip("常時隠す", icon: "eye.slash", color: .secondary)
                Image(systemName: "line.diagonal.arrow").foregroundStyle(.tertiary)
                sectionChip("隠す", icon: "eye", color: tint)
                Image(systemName: "line.diagonal.arrow").foregroundStyle(.tertiary)
                sectionChip("表示", icon: "sparkle", color: .green)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .glassCard(corner: 20)

            VStack(alignment: .leading, spacing: 0) {
                instruction(1, "Command を押しながらドラッグ", "アプリのアイコンを仕切り「│」の左右へ移動します。")
                Divider().padding(.leading, 43)
                instruction(2, "矢印をクリック", "隠した項目の表示と収納を切り替えます。")
                Divider().padding(.leading, 43)
                instruction(3, "Option + クリック", "常時隠す項目も一時的に表示します。")
            }
            .glassCard(corner: 20)

            Label("macOS のアイコン配置は OS が記憶します。Rime は他のアプリの項目を読み取らず、仕切りだけで整理します。", systemImage: "hand.raised")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionChip(_ title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 19, weight: .medium)).foregroundStyle(color)
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .frame(maxWidth: .infinity)
    }

    private func instruction(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 27, height: 27)
                .background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
    }

    private var behavior: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 13) {
                Text("隠した項目の表示場所").font(.system(size: 13, weight: .semibold))
                Picker("表示場所", selection: $preferences.revealLocation) {
                    Label("メニューバー内", systemImage: "menubar.rectangle").tag(0)
                    Label("メニューバーの下", systemImage: "rectangle.bottomhalf.inset.filled").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(preferences.revealLocation == 0
                     ? "元のアイコンをメニューバー内に広げます。ノッチのある Mac では一部が重なる場合があります。"
                     : "ノッチを避け、メニューバーの下に専用のパネルを表示します。項目の取得と操作にアクセシビリティの許可が必要です。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(corner: 20)

            VStack(spacing: 0) {
                settingRow("常時隠す区画", detail: "普段は表示しない項目用の仕切りを追加", icon: "eye.slash", toggle: $preferences.alwaysHiddenEnabled)
                Divider().padding(.leading, 52)
                settingRow("起動時に収納", detail: "メニューバーを整理した状態で開始", icon: "rectangle.compress.vertical", toggle: $preferences.startCollapsed)
                Divider().padding(.leading, 52)
                settingRow("ログイン時に起動", detail: "Mac にサインインしたら自動で開始", icon: "power", toggle: Binding(get: { preferences.launchAtLogin }, set: { preferences.launchAtLogin = $0 }))
            }
            .glassCard(corner: 20)

            VStack(spacing: 0) {
                settingRow("自動で収納", detail: "表示後、使い終えたら元に戻す", icon: "timer", toggle: $preferences.autoCollapse)
                if preferences.autoCollapse {
                    Divider().padding(.leading, 52)
                    HStack {
                        Text("待ち時間").font(.system(size: 13, weight: .medium))
                        Slider(value: $preferences.collapseDelay, in: 1...60, step: 1)
                        Text("\(Int(preferences.collapseDelay)) 秒")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 44, alignment: .trailing)
                    }.padding(16)
                    Divider().padding(.leading, 52)
                    settingRow("ポインタが上にある間は待つ", detail: "項目を操作している途中で閉じない", icon: "cursorarrow", toggle: $preferences.waitForPointer)
                }
            }
            .glassCard(corner: 20)

            if let error = preferences.launchError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12)).foregroundStyle(.red)
            }
        }
    }

    private func settingRow(_ title: String, detail: String, icon: String, toggle: Binding<Bool>) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: toggle).labelsHidden()
        }
        .padding(16)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("アクセント").font(.system(size: 13, weight: .semibold))
                HStack(spacing: 12) {
                    accentButton("ブルー", value: 0, color: Color(red: 0.31, green: 0.50, blue: 0.88))
                    accentButton("ティール", value: 1, color: .teal)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(corner: 20)

            VStack(spacing: 0) {
                settingRow("控えめなモーション", detail: "画面の切り替えを自然に見せる", icon: "waveform.path", toggle: $preferences.subtleMotion)
            }
            .glassCard(corner: 20)

            Label("「視差効果を減らす」が有効な場合、画面のアニメーションを停止します。", systemImage: "accessibility")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private func accentButton(_ title: String, value: Int, color: Color) -> some View {
        Button { preferences.accent = value } label: {
            HStack(spacing: 9) {
                Circle().fill(color).frame(width: 17, height: 17)
                Text(title).font(.system(size: 12))
                if preferences.accent == value { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
            }
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(preferences.accent == value ? color.opacity(0.13) : Color.primary.opacity(0.04), in: Capsule())
        }.buttonStyle(.plain)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 35)).foregroundStyle(tint)
                Text("Rime").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("必要なアイコンを、必要なときに。")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                Text("Rime は macOS のステータスアイテムを仕切りとして利用します。標準表示は追加権限なし。下部パネルでは項目の検出と操作にアクセシビリティ許可を使います。画面収録とネットワーク接続は使いません。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(23).frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(corner: 20)
        }
    }
}

private extension View {
    @ViewBuilder func glassCard(corner: CGFloat) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: corner))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner).strokeBorder(.primary.opacity(0.07)))
        }
    }
}
