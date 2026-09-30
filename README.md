# Rime

macOS のメニューバーを、必要な項目だけが見える状態に整理する軽量アプリです。macOS 15 以降で動きます。macOS 26 以降の設定画面にはネイティブの Liquid Glass を使い、macOS 15 ではシステム素材で同じ構造を保ちます。

## 使い方

1. `⌘` を押しながらメニューバーの項目をドラッグし、「│」仕切りの左へ移動します。
2. Rime の矢印をクリックすると、隠した項目を一時表示できます。
3. `⌥` を押しながら矢印をクリックすると、常時隠す区画も表示します。
4. 右クリックで設定、すべて表示、終了を選べます。

Rime は自分自身のステータスアイテムを幅広い仕切りとして使い、その左の項目を画面外へ押し出します。画面収録、アクセシビリティ、ネットワーク接続は使いません。項目の配置は macOS が記憶します。

## ビルド

Xcode 26.3 と [XcodeGen](https://github.com/yonaskolb/XcodeGen) が必要です。

```sh
xcodegen generate
xcodebuild -project Rime.xcodeproj -scheme Rime -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
open DerivedData/Build/Products/Debug/Rime.app
```

配布する場合は Apple Developer ID で署名し、公証してください。ログイン時起動はアプリを `/Applications` に置いた状態で設定するのが確実です。

## 実装範囲

- 表示・隠す・常時隠すの3区画
- クリック、Option クリック、右クリック操作
- 自動収納と待ち時間、ポインタがメニューバー上にある間の待機
- 起動時収納、ログイン時起動
- 設定画面の Liquid Glass（macOS 26+）、視差効果低減への対応

他のアプリの項目名や画像を取得する検索機能、トリガー、プロファイルは現在の実装範囲外です。画面のノッチや macOS のメニューバー自動非表示によって、隠した項目の再表示位置が変わる場合があります。

調査と優先順位は [docs/research-and-requirements.md](docs/research-and-requirements.md) に記載しています。
