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

- [x] **`mbtx-install` CLI の実装** ([docs/ja/design.md](docs/ja/design.md)):
  ルートA — `moon build --target native --target-dir <cache> <abs>.mbtx` で
  ビルドし、成果物 `single.exe` を `~/.moon/bin/<name>` へコピー。
  CLI は `mbtx-install <path> [-o|--name <cmd>] [--bin <dir>] [--release]`。
- [x] **エラーハンドリング** ([design.md](docs/ja/design.md) エラーハンドリング方針):
  `.mbtx` 不存在 / `moon` が PATH に無い / ビルド失敗時のメッセージ、
  `~/.moon/bin` が PATH に無い場合の警告。
- [x] **README 整備**: 使い方と `moon install` による自己インストール手順
  (`moon install podhmo/mbtx-install/cmd/mbtx-install`)を記載。
- [x] **上書き保護 + インストール記録 (manifest)** ([docs/ja/usability-report.md](docs/ja/usability-report.md) F-1):
  `-o` 名が mbtx-install 自身でインストールしたものでなければ拒否(新規名は常に可)。
  `-o moon` で toolchain 本体を破壊できた事故への対策。判定はキャッシュ
  ディレクトリ名では不可能(`-o` で名とソースが分離するため)なので、
  インストール時に `~/.mbtx-install/config.json`(可能なら jsonc)へ
  name→source 等を記録する manifest 方式とする。
- [ ] **`mbtx-install list` / `mbtx-install uninstall <name>`**
  ([usability-report.md](docs/ja/usability-report.md) F-2, PR #14 コメントで方針了承):
  manifest 導入を前提に実装する。list はインストール済み名とソースの一覧、
  uninstall はバイナリ(`<bin>/<name>`)と workdir(`~/.mbtx-install/<key>`)の
  削除。manifest なしの暫定策として README に手動削除手順を書く手もある。
- [ ] **`-v` / `--verbose` で moon の INFO ログを抑制**
  ([usability-report.md](docs/ja/usability-report.md)): 正常系でも moon の
  INFO ログが素通しして `Installed` 行が埋もれる。既定は静かにし、
  verbose 指定時のみ素通しにする。
- [x] **e2e: manifest 存在確認の追加** ([usability-report.md](docs/ja/usability-report.md) コメント受領):
  `e2e/run.sh` でインストール後に `~/.mbtx-install/config.json` の生成を
  確認する程度をスモークに加える(manifest 実装後)。
- [ ] **symlink 渡し時のコマンド名は渡したパスの basename にする**
  ([usability-report.md](docs/ja/usability-report.md) F-5, PR #14 コメントで方針了承):
  現状は realpath 解決後のベース名でインストールされるため
  `linked-script.mbtx` → `hello-no-deps` ができる。名決定を渡したパスの
  basename に変える(もしくは README に realpath 挙動を明記)。
- [ ] **ビルド失敗時の hint を「直るかも」系の固定文言にする**
  ([usability-report.md](docs/ja/usability-report.md) F-4, PR #14 コメントで方針了承):
  現状は失敗理由にかかわらず「`moon update` を実行」を hint として出すため、
  ユーザーの `.mbtx` の単なるコンパイルエラーにも誤誘導する。
  moon 出力の失敗種別検出は入れず、固定メッセージの文言だけ
  「if dependency resolution failed, `moon update` may fix it」
  のような柔らかい英語の文面に変える。
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
- [ ] **Windows 対応** ([#3](https://github.com/podhmo/mbtx-install/issues/3)):
  `*.exe` suffix とネイティブツールチェーン問題(MOON_CC shim or MSVC)。
  制限事項として issue で追跡中。
- [ ] **キャッシュ名への `+v<ver>+<profile>` サフィックス** ([#4](https://github.com/podhmo/mbtx-install/issues/4)):
  必要になればディレクトリ名を `+` 区切りで拡張する案。issue で追跡中。
