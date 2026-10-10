# mbtx-install デザインドック

> 前提となる調査結果は [research.md](research.md) を参照。ここでは設計判断と仕様をまとめる。

## 背景・モチベーション

- **1ファイル完結へのこだわり**: ツールごとにディレクトリを切りたくない。パッケージレジストリ(mooncakes 等)に公開するほどでもない小さなツールを扱いたい。PATH を個別に追加せず、どこからでもコマンド名だけで呼び出したい。
- 他言語の体験:
  - Deno: `deno install -g script.ts` で 1 ファイルのままグローバルコマンド化できる(理想の体験)。
  - Python + uv: PEP 723 (Inline Script Metadata) と `uv run` shebang で 1 ファイル実行は可能だが、配置管理は別途必要になりがち。
- 現状の MoonBit の障壁:
  - `.mbtx` は `moon run script.mbtx` または `moonx script.mbtx` が必須で、単体でのグローバル配置ができない(moonx は常に Wasm 実行)。
  - `moon install` は `~/.moon/bin` へ配置できて便利だが、対象は main パッケージ(ディレクトリ + `moon.pkg`)に限られ、`.mbtx` は `is-main: true required` で拒否される。

## 目的 / 非目的

### 目的

- `mbtx-install path/to/mytool.mbtx` 一発で、`mytool` コマンドを `~/.moon/bin` にインストールする。
- 手元に残るのは `.mbtx` 1ファイルのみ。作業ツリーを汚さない。
- ツール自身も MoonBit 製とし、`moon install` で自己導入できる構造にする。

### 非目的(初期版)

- パッケージのビルド・公開(mooncakes への publish)は扱わない。
- 複数ファイル・モジュール横断のプロジェクトのインストールは扱わない(それは `moon install` の仕事)。

## 基本方針: ルートA「直接ビルド + コピー」

調査の結果、スキャフォールドを経由しない以下の流れが最小構成かつ最も堅いと判断した。

```
mbtx-install mytool.mbtx
  ├─ キャッシュ領域に一意な作業ディレクトリを用意 (例: ~/.mbtx-install/<hash>/)
  ├─ moon build --target native --target-dir <cache> <abspath>/mytool.mbtx   # デフォルトはデバッグビルド
  │    → <cache>/mytool.mbtx/native/debug/build/single/single.exe
  │      (--release 指定時は native/release/ 配下)
  └─ single.exe を ~/.moon/bin/mytool としてコピー(上書き)
```

### ルートAを選ぶ理由

- `.mbtx` の `import` ブロック(`@version` 指定、`@alias`、import-all `*`)を **MoonBit 本体の script-mode に解釈させられる**。変換層が要らず、構文の将来拡張にも追従できる。
- 生成ファイルは `moon.mod`/`moon.pkg`/`main.mbt` への分解が不要で、失敗ポイントが少ない。
- `--target-dir` で成果物を完全にキャッシュ側へ隔離できることを実機確認済み。

### 却下した代替案

- **ルートB: スキャフォールド生成 + `moon install`**
  キャッシュに `moon.mod` / `moon.pkg` / `cmd/<name>/main.mbt` を生成して `moon install` に渡す案。`moon install` の公式導線に乗れる利点があるが、import ブロックの分解(module deps → moon.mod、package import → moon.pkg、バージョン剥がし)を自前実装する必要があり、import-all 等の script-mode 専用構文をロストする。複雑さに対して利点が薄い。
- **`moonx` への薄いラッパ**
  `moonx` は `.mbtx` をその場実行できるが常に Wasm バックエンドで、起動速度・スタンドアロン性でネイティブに劣る。インストール済みコマンドとしての体験が目的なので不採用。
- **`moon install <file>.mbtx` への期待**
  現状 `is-main: true required` で拒否される。upstream が `.mbtx` 直指定に対応すれば本ツールは薄くできる(将来の再検討事項)。

## 詳細仕様

### CLI

```
mbtx-install <path-or-url> [--name <cmd>] [--bin <dir>] [--release]
```

- 第1引数: ローカルの `.mbtx` パス(初期版はローカルのみ。URL は将来拡張)。
- `--name`: コマンド名の上書き。デフォルトはファイル名(下記)。
- `--bin`: インストール先。デフォルト `~/.moon/bin`(`moon install` の標準に準拠)。
- `--release`: リリースビルド(最適化)に切替。デフォルトは**デバッグビルド**(ビルド時間優先。MoonBit は Rust 同様 debug/release が分かれており、デバッグ版の方がビルドが速い)。
- 失敗時は非ゼロ終了 + 何が失敗したか(ビルド/コピー/依存解決)を表示。

### コマンド名の決定

- `mytool.mbtx` → `mytool`(basename の `.mbtx` 拡張子を除いたもの)。
- `.mbtx` 以外の拡張子、拡張子なし、basename が不正な場合はエラー。

### キャッシュ・作業ディレクトリ

- 場所: **`~/.mbtx-install/`** に一意なディレクトリを切る(レビューでの提案を採用。`~/.moon` の慣例に揃う)。OS 標準キャッシュ(XDG 等)案は却下。
- 一意性: 入力 `.mbtx` の**絶対パスのハッシュ**(例: SHA-256 先頭 12 桁)をディレクトリ名に使い、同名ファイルの別パス同士が衝突しないようにする。
- 保持物: `--target-dir` 配下のビルド成果物(`.moon_db` 等の moon キャッシュ含む)。再ビルド時に moon の増分ビルドが効くよう、同じ hash ディレクトリを使い回す。

### 成果物の特定

- `moon build` の `.mbtx` 向け出力は仮想パッケージ `single` 固定(`<target-dir>/<file>.mbtx/native/<profile>/build/single/single.exe`)。この規約は moon の実装詳細で変わり得るため、以下の順で特定する:
  1. `moon build --dry-run` の出力からリンク行 `-o <path>` をパース(規約非依存)
  2. フォールバックとして `<target-dir>` 配下の `*.exe` 探索
- 補足: `.mbtx` を `moon new` したプロジェクト内に置いてビルドしても `single` パッケージになることは実機で確認済み。`single` 自体を回避するには実パッケージへの変換(ルートB)が必要で、今回は採用しない。

### 更新 / 再インストール

- 同名コマンドは**確認なしで上書き**。内容が変わっていなくても再ビルド→再コピー(moon の増分ビルドで実質軽い)。
- 上書き前に既存バイナリが「mbtx-install 製かどうか」を判定する仕組みは持たない(初期版)。`--name` 競合はユーザー責任。

### ビルドターゲット

- 基本は `native`。**デフォルトはデバッグビルド**(ビルド時間優先の方針。実行速度が欲しい場合は `--release` オプション)。調査済み: release 約 470KB / debug 約 790KB、どちらも libc のみ依存のネイティブバイナリ。
- Wasm 出力をオプションで残すかは検討中(`~/.moon/bin` に wasm を置いても直接実行できないので、wrapper が必要になり当初目的とズレる)。

### 依存関係の解決

- `.mbtx` の `import` ブロックに追従するだけ。`@version` 指定はそのまま honor、無指定はローカルレジストリインデックスの最新。
- インデックスが古い/未取得で解決に失敗した場合のエラーメッセージに「`moon update` を実行して再試行」の案内を含める(初期版では自動 `moon update` はしない。勝手にネットワークアクセスしない方針)。

### ツール自身の構造

- 通常の MoonBit モジュールとして構成し、`cmd/mbtx-install` に `pkgtype(kind: "executable")` の main パッケージを置く。
- `moon install` で自己インストール可能にする(README に `moon install podhmo/mbtx-install/cmd/mbtx-install` or git URL 手順を記載)。
- 内部処理(プロセス起動、ファイルコピー、パス・環境変数解決)には `moonbitlang/async` 系の `@shell.Cmd` や `@fs` を使う方針(エージェント向け自動化の既定構成と揃える)。

## エラーハンドリング方針

- `.mbtx` が存在しない / 拡張子が違う → 使用法を出して終了。
- `moon` が PATH に無い → 明確に「moon が見つからない」と言う。
- `moon build` 失敗 → moon の診断をそのまま素通しで表示(リダイレクトしない)。
- `~/.moon/bin` が PATH に無い → 警告のみ(インストール自体は成功させる)。

## 未決事項・今後の検討(オープン)

1. **メタデータの任意拡張**: description やコマンド名上書きを `.mbtx` 内に書きたくなった場合のフォーマット。候補: `///|` コメント内の独自キー(例 `/// mbtx: description=...`)。現状は `--name` オプションで足りるはずで、必要性が出てから。
2. **リモート URL インストール**: `mbtx-install https://.../tool.mbtx`。ダウンロード→同一フローに乗せるだけだが、信頼境界として別タスク。
3. **アンインストール / 一覧 / キャッシュクリア**: `mbtx-install --uninstall mytool`(バイナリ削除 + 管理下キャッシュ削除)。インストール時にメタファイル(管理下マーカ)を残すかが論点。
4. **shebang 対応**: ~~`.mbtx` 先頭に shebang を書けるか~~ → 実機検証済みで**不可**(`#` は字句エラー)。直接実行にはバイナリ化必須のため、本項はクローズ。
5. **upstream 連携**: `moon install` の `.mbtx` 対応を upstream に提案するか。対応されればルートAのコピー処理ごと置き換えられる可能性。
6. **Windows 対応**: `*.exe` suffix とネイティブツールチェーン問題(MOON_CC shim or MSVC)。→ **制限事項として [issue #3](https://github.com/podhmo/mbtx-install/issues/3) で追跡**し、あとで検討する方針(レビュー確定)。初期版の対象プラットフォームは Linux/macOS とみなす。

## 決定事項まとめ

| 項目 | 決定 |
|---|---|
| ルート | ルートA: `moon build --target native --target-dir <cache>` + 成果物を `~/.moon/bin` へコピー |
| コマンド名 | ファイル名(`*.mbtx` 拡張子を除く)、`--name` で上書き可 |
| 配置先 | `~/.moon/bin`(`--bin` 変更可) |
| キャッシュ | `~/.mbtx-install/<abspath-hash>/` |
| ビルドプロファイル | デフォルト debug、`--release` で切替 |
| 成果物特定 | `--dry-run` 出力のリンク行パース → `*.exe` 探索フォールバック |
| 更新 | 無条件上書き |
| 依存 | `.mbtx` の `import` ブロックに追従(自動 `moon update` なし) |
| 実装 | MoonBit 製、`moon install` で自己導入可 |
| Windows | 制限事項(issue で追跡) |
