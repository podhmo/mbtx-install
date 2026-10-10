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
- [x] **`--version` の追加(中)** ([usability-report.md](docs/ja/usability-report.md) F-6,
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
- [ ] **Windows 対応** ([#3](https://github.com/podhmo/mbtx-install/issues/3)):
  `*.exe` suffix とネイティブツールチェーン問題(MOON_CC shim or MSVC)。
  制限事項として issue で追跡中。
- [ ] **キャッシュ名への `+v<ver>+<profile>` サフィックス** ([#4](https://github.com/podhmo/mbtx-install/issues/4)):
  必要になればディレクトリ名を `+` 区切りで拡張する案。issue で追跡中。
