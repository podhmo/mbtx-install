# TODO

> **Note on updating this file:** upkeep rules live in
> [`.claude/skills/todo-md/SKILL.md`](.claude/skills/todo-md/SKILL.md) —
> follow them whenever you add or complete a task. Short version: this file
> lists actionable work only (`[ ]` / `[-]`); mark finished work `[x]` — a
> periodic GC sweep appends such entries to `TODO-archive.md`.

This file tracks actionable tasks only; completed work is swept to
`TODO-archive.md` by periodic GC.

## To Be Implemented

### mbtx-install 本体

- [ ] **`mbtx-install uninstall <name>`**
  ([usability-report.md](docs/ja/usability-report.md) F-2, PR #14 コメントで方針了承):
  manifest 導入を前提に実装する。バイナリ(`<bin>/<name>`)と
  workdir(`~/.mbtx-install/<key>`)の削除 + manifest エントリ削除。
  暫定策として README の「Removing an installed command」に
  手動削除手順は記載済み。
- [ ] **`--version` の追加(中)** ([usability-report.md](docs/ja/usability-report.md) F-6,
  PR #14 コメントで中優先度と了承):
  `unexpected argument '--version'` でツール自身のバージョン確認手段がない。
  `.mbtx` はメタデータを持てない(front-matter は import ブロックのみ)ため、
  `moon.pkg` の version をビルド時に埋め込む方式で。issue 報告時に必要。
- [ ] **(low) PATH 警告は絶対パスで表示** ([usability-report.md](docs/ja/usability-report.md) F-9):
  `--bin relbin` のような相対指定だと警告が相対パスのまま出て、
  PATH に何を足すべきか分かりにくい。
- [ ] **(low) コピー失敗時のエラーを人間向け文言にマップ**
  ([usability-report.md](docs/ja/usability-report.md) F-10):
  `OSError("@fs.open()...")` の内部表現が露出するので、
  `Text file busy` 相当の文言に変換する。

### 将来拡張・棚卸し済み検討事項

design.md の「未決事項」から。各項目の詳細はリンク先に置く。

- [ ] **リモート URL インストール** ([design.md](docs/ja/design.md) 未決事項2):
  `mbtx-install https://.../tool.mbtx` — ダウンロードして同一フローへ。
  信頼境界の設計が論点。
- [ ] **アンインストール / 一覧 / キャッシュクリア** ([design.md](docs/ja/design.md) 未決事項3):
  `--uninstall` でバイナリ削除 + 管理下キャッシュ削除。
  管理下マーカのメタファイルを残すかが論点。
- [ ] **メタデータ拡張フォーマット** ([design.md](docs/ja/design.md) 未決事項1):
  description やコマンド名上書きを `.mbtx` 内に書きたい場合の書式。
  候補は `///|` コメント内の独自キー(`/// mbtx: name=foo`)。必要性が出てから。
- [ ] **upstream への `moon install .mbtx` 対応提案** ([design.md](docs/ja/design.md) 未決事項5):
  upstream が受理すれば本ツールのコピー処理ごと置き換えられる可能性。
- [-] **Windows 対応** ([#3](https://github.com/podhmo/mbtx-install/issues/3)):
  実機調査済み([windows-report.md](docs/ja/windows-report.md))。方針:
  MSVC 必須 + WSL 記述の併用(MinGW shim は本体が通らない)。残るのは
  `installer/` のパス差分実装とドキュメント明記。
  - [ ] **home 解決を `MOON_HOME → HOME → USERPROFILE` 順に**:
    Windows native では `HOME` 未設定(`USERPROFILE` のみ)で現行コードは
    exit 1 する(実機確認)。
  - [ ] **cache_key を Windows パス対応に**:
    `\`→`/` 正規化 → `:`→`-` → `/`→`-`。現行は `C:\...` の `:` と `\` が
    残り、Windows でディレクトリ名が違法になる。
  - [ ] **basename/dirname/is_valid_name/resolve_link_target の区切り対応**:
    `\` 区切りパス、ドライブレター `C:`、UNC `\\`、Windows 違法文字
    (`<>\:"/\\|?*`)を入口で正規化・判定。
  - [ ] **インストール名に `.exe` を付ける(Windows)**:
    `moon install` 実機確認で `main.exe` として配置。`<bin>/<name>` の
    ままだと実行不可。manifest の記録名は `name`、実ファイルは
    `name.exe` とする案。
  - [ ] **PATH 分割を `;` に + `program_on_path` の `.exe`/`PATHEXT` 対応**。
  - [ ] **プラットフォーム判定手段を 1 点追加**(`OS=Windows_NT` /
    `PATHEXT` 存在 or moonbitlang/core の環境情報)。
  - [ ] **README の Platforms 記述を更新**:
    「Windows は MSVC Build Tools 必須(または WSL 経由)」に書き換え、
    issue #3 の「制限事項」表現を解消。
  - [ ] **e2e の Windows 版**(`run.ps1` 等)または統一 runner。
  - [x] **MSVC 実機検証**:`moon install ./cmd/mbtx-install` 完走
    (mbtx-install.exe 938KB)。`cl.exe` は PATH にあれば自動検出。
    実行時の Unix 前提バグ(HOME/basename)も実機再現済み
    ([windows-report.md](docs/ja/windows-report.md) §1.4.1)。
- [ ] **キャッシュ名への `+v<ver>+<profile>` サフィックス** ([#4](https://github.com/podhmo/mbtx-install/issues/4)):
  必要になればディレクトリ名を `+` 区切りで拡張する案。issue で追跡中。
