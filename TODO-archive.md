# TODO archive

> **What this file is:** append-only history of completed work moved out of
> `TODO.md` by a periodic GC sweep (see `.claude/skills/todo-md/SKILL.md` —
> feature PRs never write here, so this file never conflicts). Entries land
> **verbatim** at the end of the file as `- [x]` lines; nested items get a
> `> parent: <title>` context line first. Entries are never rewritten;
> links into docs, issues, and PRs are preserved.
>
> **Reading this file:** do not read it whole — `grep` for a symbol or
> feature name, then read only the surrounding lines (`rg -C` / read with
> an offset).
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
- [x] **`mbtx-install --list`**
  ([usability-report.md](docs/ja/usability-report.md) F-2, PR #14 コメントで方針了承):
  manifest の installs を `name -> source` で一覧表示する(path 不要)。
- [x] **`-v` / `--verbose` で moon の INFO ログを抑制**
  ([usability-report.md](docs/ja/usability-report.md)): 正常系でも moon の
  INFO ログが素通しして `Installed` 行が埋もれる。既定は静かにし、
  verbose 指定時のみ素通しにする。
- [x] **e2e: manifest 存在確認の追加** ([usability-report.md](docs/ja/usability-report.md) コメント受領):
  `e2e/run.sh` でインストール後に `~/.mbtx-install/config.json` の生成を
  確認する程度をスモークに加える(manifest 実装後)。
- [x] **symlink 渡し時のコマンド名は渡したパスの basename にする**
  ([usability-report.md](docs/ja/usability-report.md) F-5, PR #14 コメントで方針了承):
  現状は realpath 解決後のベース名でインストールされるため
  `linked-script.mbtx` → `hello-no-deps` ができる。名決定を渡したパスの
  basename に変える(もしくは README に realpath 挙動を明記)。
- [x] **ビルド失敗時の hint を「直るかも」系の固定文言にする**
  ([usability-report.md](docs/ja/usability-report.md) F-4, PR #14 コメントで方針了承):
  現状は失敗理由にかかわらず「`moon update` を実行」を hint として出すため、
  ユーザーの `.mbtx` の単なるコンパイルエラーにも誤誘導する。
  moon 出力の失敗種別検出は入れず、固定メッセージの文言だけ
  「if dependency resolution failed, `moon update` may fix it」
  のような柔らかい英語の文面に変える。
