# 調査レポート: `.mbtx` のインストール可能性

`mbtx-install` の設計に必要な事実確認と実験の記録。随時追記する調査メモ。

- 調査日: 2026-10-10
- 環境: `moon 0.1.20260920` / `moonx` 同梱 / Linux x86_64 (Ubuntu 22.04)
- 一次情報: `vendor/moonbit-docs` の [script-mode](https://docs.moonbitlang.com/en/latest/toolchain/moon/script-mode.html) 公式ドキュメント、`moon --help` 系、実機実験

---

## 1. `.mbtx` (script mode) の仕様

公式ドキュメント + 実験で確認できた仕様。

- `.mbtx` = 先頭の `import { ... }` ブロック(省略可) + 通常の MoonBit コード。**トップレベル式は存在せず、`fn main` がエントリポイント**。つまり構造的には「main パッケージの 1 ファイル版」に近い。
- `main` のバリエーションは 3 種:
  - `fn main { }` (同期・エラー伝播なし)
  - `fn main raise { }` (同期・チェック済みエラー伝播あり)
  - `async fn main { }` (非同期。`moonbitlang/async` の import が必須。`raise`/`await` は付けない)
- import ブロックの構文:
  ```mbtx
  import {
    "moonbitlang/core/list" @ls,        // @alias は省略可
    "moonbitlang/async@0.20.2/fs",      // モジュール名に @version を付けられる
    "moonbitlang/core/array" *,         // * で import-all (全定義をスコープへ)
  }
  ```
  - `@version` はモジュール(module)単位。同じモジュールの全 import は同一バージョンであること。
  - バージョン省略時は「ローカルレジストリインデックスが知っている最新版」が使われる。
  - `*` (import-all) は `.mbtx` 専用構文。通常パッケージ(`moon.pkg`)では使えない。
- 実行方法:
  - `moon run script.mbtx [args...]`
  - `cat script.mbtx | moon run -` (stdin)
  - `moon run -e 'fn main { ... }'` (インライン)
  - `moonx script.mbtx` (後述。常に Wasm)
- `moon test script.mbtx` で単体テスト可能(テスト用エントリは `main` を実行しない)。
- `moon check script.mbtx` / `moon build script.mbtx` もプロジェクト外・単体でそのまま動く(実機確認)。
- CLI 引数: `@env.args()`(`moonbitlang/core/env`)で argv 取得可(実機確認)。native バイナリ化すると通常の C argv がそのまま渡り、`arg[0]` = バイナリパス、以降に引数。ただし `moon run`/moonx(Wasm)経由だと `arg[0]` は wasm ファイルパスになるので、インストール後(native)と開発中(wasm)で argv 解釈がズレうる点に注意。

### テスト・lint・check と `.mbtx` (PR コメント受領分、実機検証済み)

- **インラインテストは同じファイルに書ける**。`.mbtx` 内に `test { assert_eq(...) }` ブロックを書くと `moon test file.mbtx` で実行される(`Total tests: 1, passed: 1` / 失敗時は `1 != 2` の diff 表示)。1ファイル志向と矛盾しない。
- `moon test --help` の公式記述: 明示した `.mbtx` パスはそのスクリプトだけをテスト対象にし、テストは生成エントリポイントで走る(スクリプトの `fn main` は実行されない。`fn main` の定義自体は必須)。**パッケージ一括テストでは `.mbtx` は対象外**。プロジェクト外では `.mbt` / `.mbt.md` の単体テストも可能。
- **`moon lint` はこのツールチェーン(0.1.20260920)に存在しない**。`moon lint` を呼ぶと外部実行ファイル `moon-lint` を PATH から探しにいき、未導入なら `no such subcommand` でエラー。docs 上の "lint" 記述は warn-list の警告名 `syntax_lint` (warning 63) を指すだけで、lint サブコマンドではない。→ lint は現状 `.mbtx` 運用の検討対象外(コメントの補足通り)。
- check/build は `.mbtx` をそのまま受理するため、CI 等で品質担保するなら `moon check file.mbtx`(と `moon test`)を使うのが実用的。

### 依存のバージョン固定 (実機検証済み)

参照: <https://docs.moonbitlang.com/ja/latest/toolchain/moon/script-mode.html>

- **直依存の固定は front-matter の `@version` で可能**(`"moonbitlang/x@0.5.3/json5"` → 実際に `moonbitlang/x@0.5.3` が解決・ダウンロードされることを確認)。バージョンは厳密指定のみで、範囲演算子(`>=` 等)は存在しない。
- 同一モジュールから import する全パッケージは同一バージョン必須(公式仕様)。
- バージョン省略時はローカルインデックスの最新版が使われる → **同一 `.mbtx` でも時期・マシンによってビルドされる依存バージョンが変わりうる**(再現性は script 側の `@version` 記述に委ねられる)。
- **`moonbit.deps` は `.mbtx` では参照されない**。隣接ファイルに `moonbitlang/x = "0.5.3"` と書いても front-matter 無指定の import は最新版(0.5.5)が解決された。これは `.mbt.md`(literate ドキュメント)ファイル向けの機構で、「モジュール依存だけ宣言して Moon に import を自動生成させる」用途。
- **推移的依存(依存の依存)のバージョンを `.mbtx` 側から制約する仕組みは存在しない**。指定できるのはスクリプトが直接 import するモジュールのみ。
- mbtx-install 観点: 依存解決は `moon build` に丸投げなので、front-matter `@version` は**ツール側の追加実装なしでそのまま効く**。配布先での再現性を上げたい場合は「スクリプト作者が `@version` を書く」が現時点の唯一の手段。

### メタデータ記述について (要調査だった項目)

- description / author 等のメタデータ用プラグマは**現状存在しない**。script mode に任意メタデータを埋め込む公式構文は見つからなかった。
- 依存関係の記述は `import` ブロックの `@version` が事実上の公式仕様であり、これに追従すればよい。
- 独自メタデータ(例: コマンド名上書き、説明文)が欲しくなった場合は、MoonBit のコメント形式に倣って `///|` ブロック内に独自キーを置く方式が自然(例: `/// mbtx: name=foo`)。デザインドック側で判断。

## 2. `moon build` / `moon run` を `.mbtx` に直接かけた場合

実験: `hello.mbtx` (`fn main { println("hello from mbtx") }`) に対して。

```bash
moon build --target native --release hello.mbtx
```

- 成果物: `_build/hello.mbtx/native/release/build/single/single.exe` (約 473KB)
- 生成バイナリは**素で実行可能**。`ldd` では `libc` のみに依存。スタンドアロンに近い。
- 単体ファイル時の `--target-dir` デフォルトは `<source-dir>/_build/<file-name>`。**`--target-dir` を指定すればビルド成果物を完全に任意ディレクトリへ隔離できる**(スクリプトの置き場所を汚さない)。実験済み:
  ```bash
  moon build --target native --release --target-dir /tmp/mbtx-cache /abs/path/dep.mbtx
  # → /tmp/mbtx-cache/dep.mbtx/native/release/build/single/single.exe
  ```
- パス規則: `<target-dir>/<file-name>/native/release/build/single/single.exe`。`single` は単体ファイル用の仮想パッケージ名と思われる(実装詳細なのでバージョンアップで変わり得る。`*.exe` を探索するフォールバックを設計に入れると安全)。
- `--target native` を省略した場合のデフォルトは Wasm(`.wasm` 出力)。`moon run` は moonrun 経由の Wasm 実行がデフォルト。
- 絶対パス・別ディレクトリからの `moon build <abspath>.mbtx` も動作確認済み。

## 3. `moon install` の挙動

実験: `moon new testproj` (moon 0.1.20260920 生成の標準構造) に対して `moon install ./cmd/main`。

- 結果: `Success: Installed 'main' to '/home/ubuntu/.moon/bin/main'`。
- **インストールされるコマンド名 = パッケージのディレクトリ名**(`cmd/main` → `main`)。
- 再インストールは無条件に成功(上書き動作。エラーにならない)。
- 配置先のデフォルトは `~/.moon/bin/`(`--bin <DIR>` で変更可)。
- `MOON_HOME` 環境変数を見る: `MOON_HOME=/tmp/mhtest moon install ./cmd/m` → `/tmp/mhtest/bin/m` に配置された(検証済み)。`~/.moon` ルート全体(registry/cache/bin)が MOON_HOME に従うので、bin 解決をツール側で再現するなら `$MOON_HOME/bin` を読めばよい。
- `moon install` の SOURCE 解釈順: 1. ローカルパス → 2. git URL → 3. レジストリパス。git URL + `PATH_IN_REPO` や GitHub permalink も可。

### `moon install` に `.mbtx` を直接渡した場合

- プロジェクト外: `moon install ./hello.mbtx` → `Error: not in a Moon project`
- プロジェクト内に `.mbtx` を置いても: `Error: Path ... is not a main package (is-main: true required)`
- つまり **`moon install` は `.mbtx` を直接受理しない**。`.mbtx` は「is-main でない仮想パッケージ `single`」として扱われる模様。
- 通常パッケージで is-main 相当を立てるには `moon.pkg` に `pkgtype(kind: "executable")` を書く(`is-main` フィールド自体は deprecated)。

## 4. `moonx` の位置づけ

`moonx --help` より。

- `moonx script.mbtx` で **インストールせず `.mbtx` を直接実行できる**(事実上 `deno run` 相当)。実機でも動作確認済み。
- ただし **`.mbtx` 実行は常に Wasm バックエンド**(`--target` 選択肢に native はあるが "deprecated and scheduled for removal after 2026-09-14" と明記)。
- `moonx user/module/package[@version]` はレジストリ実行(npx 的)。ローカルパッケージは対象外。
- 結論: moonx は「その場実行」の解だが、ネイティブバイナリを永続配置する用途は満たさない。mbtx-install の存在意義は残る。

## 5. `.mbtx` → 通常パッケージへの変換写像(代替案の検証)

仮にスキャフォールドを生成する場合の対応関係を実機で確認。

| `.mbtx` | 生成先 |
|---|---|
| `import { "mod@ver/pkg" @a }` | `moon.pkg` の `import { "mod/pkg" @a }` (バージョンを剥がす) + `moon.mod` の `import { "mod@ver" }` |
| `fn main` 等のコード本体 | `cmd/<name>/main.mbt` にそのまま |
| (なし) | `cmd/<name>/moon.pkg` に `pkgtype(kind: "executable")` |
| (なし) | `moon.mod` (モジュール名/依存モジュール一覧) |

- `moon.mod` / `moon.pkg` は現行ツールチェーンでは新フォーマット(rr_moon_mod/rr_moon_pkg、いわゆる "moon.mod 形式"。`.json` ではない)。`moon add moonbitlang/x` で `moon.mod` に `import { "moonbitlang/x@0.5.5" }` が追記されることを確認。
- `moon.pkg` 側の `import { "moonbitlang/x/sys" @sys }` 形式は受理されることを実機確認。
- 変換で失われるもの: `*` (import-all)、`@version` 直書き(moon.pkg はバージョンを書けず moon.mod 側の deps へ移す必要)、`-e`/stdin 実行など script-mode 固有の利便性。
- つまり**スキャフォールド生成ルートは import ブロックの分解・書き換えロジックが必須**で、script mode の構文を自前で再実装することになる。一方で直接ビルドルートは import ブロックを MoonBit 本体に解釈させられるため、構文拡張(将来の追加含む)に自動的に追従できる。

## 6. キャッシュ周り

- `moon clean --dep-cache` (依存ソースキャッシュ) / `--build-cache` (ビルド成果物キャッシュ) というグローバルキャッシュ概念が moon に存在。実体は `~/.moon/cache/` 配下(実機に `deps/` が存在)。
- `--target-dir` を使えば mbtx-install 独自のキャッシュディレクトリ(例: `$XDG_CACHE_HOME/mbtx-install/`)にビルド成果物を隔離できる。実機確認済み。
- `moon build` が依存解決に使うレジストリインデックスは `~/.moon/registry` 配下。初回は `moon update` でインデックス取得が必要な可能性あり(今回の環境は既存インデックスありで `moonbitlang/x@0.5.5`, `moonbitlang/async@0.20.2` が即解決できた)。真っ新な環境での初回挙動は未検証。

## 7. 未検証・残課題

- ~~真っ新な環境(レジストリインデックス未取得)で `.mbtx` の外部依存が初回ビルド時に自動解決されるか。`moon update` の事前実行が要るか。~~ → 補足受領: `mbtx-install` というコマンドとして導入・実行する限り、その導入自体に moon ツールチェーン(+レジストリインデックス)が前提になるため、このケースは実運用上ほぼ発生しない=自動解決される。サブコマンドを持つ形態に変わる場合は前提が変わり得るが、そのときはリポジトリ名・ツール名自体も変わる想定。
- `single` 仮想パッケージ名や成果物パス規則は moon の実装詳細。バージョン差分に弱い可能性。→ 回避策(実機確認済み):
  - `moon build --dry-run` の出力(リンク行 `-o <path>/single.exe`)をパースすれば規約に依存せず成果物パスを確定できる。
  - `<target-dir>` 配下の `*.exe` を探索するフォールバックでも十分(その配下に作られる exe は実質1つ)。
  - 補足案(~/.mbtx-install/ 下に一意ディレクトリを切って `moon new`)を検証したが、**プロジェクト内で `.mbtx` をビルドしても成果物は `single` パッケージのまま**だった(`moon new` プロジェクト内で実機確認)。`single` を回避するには `.mbtx` を実パッケージに変換するルートBしかない。作業ディレクトリの場所として `~/.mbtx-install/` 自体は採用する(design.md 反映)。
- `.mbtx` で import-all (`*`) を使ったものも native ビルド・実行できることを確認済み(`--target native --release` で `len=3` を出力)。
- Windows: 成果物は `*.exe`。`MOON_CC` 問題(Windows native は tcc 同梱ではランタイムがビルド不可、MSVC か shim が必要 — moonbit-individual-handbook の記録より)があり、native インストールがそもそも難しい環境がある。→ **制限事項として扱う方針([issue #3](https://github.com/podhmo/mbtx-install/issues/3) で追跡、あとで検討)**。
- `moon install` が内部でどの `--target`/`--release` 設定を使うか → 生成物サイズから native release 相当と推測(インストール済み `main` = 473,776B、手元の release single.exe = 473,760B、debug = 791,744B)。
- debug/release ビルド: Rust 同様に分かれており `--release` で切替。hello.mbtx で debug 0.345s / release 0.384s(小さな差。デバッグ版の方が若干速い)。→ レビュー指摘により **mbtx-install のデフォルトは native デバッグビルド(ビルド時間優先)、`--release` オプションで切替可能**にする方針。
- 同名 `.mbtx` が別ディレクトリにあった場合のコマンド名衝突は仕様上「ファイル名に準拠」なので利用者側の問題。
- キャッシュキー(レビュー反映): 絶対パスハッシュ案は却下し、**絶対パスの `/` を `-` に置換した名前**(Claude Code の projects 保管方式と同型)を採用。git 管理下なら `<owner>-<repo>` をプレフィックスにする案もあったが、単純さ優先で全パス `-` 置換。`-` を含むパス名同士での衝突は可能性として残るが許容(厳密にしたくなったら末尾に短いハッシュを足す余地あり)。プロファイル/世代(debug/release 等)でサブディレクトリを切ると掃除・切り戻しに親切、という指摘も反映。必要になれば `+vX.Y.Z+<profile>` 風の `+` 区切り suffix でディレクトリ名を伸ばす案もあったが、初期版では不要と判断して [issue #4](https://github.com/podhmo/mbtx-install/issues/4) へ。
- `.mbtx` に shebang 行を書けるか → **書けない**(実機確認。`#` は字句エラー、`#!` はパースエラー)。`#!/usr/bin/env moon run` 型の直接実行は不可能なので、実行ファイル化は必須。

## 8. 結論サマリ

- `.mbtx` の依存・import 構文は公式仕様として十分に整っている。メタデータの余地があるのは description 等の補助情報のみ。
- **`moon build --target native --release --target-dir <cache> <file>.mbtx` → 生成 `single.exe` を `~/.moon/bin/<name>` にコピー**、が最小構成で全要件を満たすルート(以降「ルートA」)。
- スキャフォールド + `moon install` ルート(ルートB)も技術的には可能だが、import ブロックの再実装が必要で、script-mode 固有構文を失う。ルートAを推す。
- `moon install <file>.mbtx` 自体が upstream で対応されれば、このツールはほぼ不要になる。upstream へのフィードバック候補。
