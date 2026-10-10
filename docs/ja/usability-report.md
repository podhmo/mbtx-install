# mbtx-install ユーザビリティ検証レポート

- 日時: 2026-10-10
- 対象: `podhmo/mbtx-install` main (`e2b55f4`、PR #9 マージ済み実装)
- 環境: Ubuntu / moon 0.1.20260920 (`~/.moon/bin/moon`)
- 立場: 不案内なユーザーとして、README と `mbtx-install --help` だけを頼りに操作。失敗の診断目的でのみソース/ドキュメント参照(該当箇所に明記)

## 結論サマリ

基本フロー(インストール→実行→更新→別名共存)はすべて素直に動く。最大の問題は **名前衝突時の無警告上書き**(検証済み: `-o moon` でツールチェーンの `moon` 本体を破壊できる)と、**uninstall/list 不在による追跡不能性**。次点で、正常系でも moon の INFO ログが大量に素通しされて成果物の1行が埋もれる点。

---

## つまずき点

### F-1【confusing】既存コマンドが警告なく上書きされる(ツールチェーン自身を破壊可能)

- シナリオ: rename / collision
- 試したこと:
  - `mbtx-install /tmp/other-script.mbtx -o hello-no-deps`(別ソースを既存名で)
  - `mbtx-install hello-no-deps.mbtx -o moon`(ツールチェーンの `moon` 本体を狙い撃ち)
- 期待: 上書き前に警告・確認、または「どのスクリプト由来か」の判別手段
- 実際: いずれも `Installed '...' to ...` とだけ出て**無警告で上書き**。`-o moon` では `~/.moon/bin/moon` が hello バイナリに置き換わり、`moon --version` が `hello v2 from mbtx` を返す状態になった(検証後に手動復旧)。README の「overwriting unconditionally」は仕様通りだが、`moon`/`moonc`/`moonrun` などツールチェーン名は無防備。別スクリプトから来た同名バイナリかどうかの区別手段が外からは一切ない
- 補足(自己破壊だけは偶然防がれる): `-o mbtx-install` は Linux では `error: cannot write '...': OSError("@fs.open(): ...: Text file busy")`(exit 1)で失敗 — 実行中バイナリの ETXTBSY による**偶然の**保護であり設計上のガードではない。macOS 等では挙動が違う可能性がある上、エラー文面が `@fs.open()` の内部表現をそのまま露出している(別項 F-10)
- 深刻度: **confusing**(明示的に `-o` を打った場合のみだが、ツールチェーン破壊まで警告ゼロ)
- 修正案: インストール済み名→ソースパスの manifest(例 `~/.mbtx-install/manifest.json`)を持ち、(a) 管理外・別ソースのバイナリを上書くとき警告 or `--force` 必須、(b) `moon`, `moonc`, `moonrun`, `mbtx-install` 自身の名前は拒否。最小限なら「overwriting existing command 'X'」の警告行だけでも誤操作は激減する

### F-2【confusing】uninstall / list がなく、後から追跡・掃除ができない

- シナリオ: uninstall
- 試したこと: `mbtx-install uninstall`, `--uninstall`, `remove`, `-u`
- 期待: 削除コマンド、または README に手動手順
- 実際: すべて usage エラー(exit 2)で非対応と分かる。手動では `rm ~/.moon/bin/<name>` でバイナリは消せるが、(a) workdir `~/.mbtx-install/<絶対パス`-`-`連結>` が残り続け(GC なし、10スクリプトで ~29MB)、(b) `-o` で付けた名前→ソースの対応を後から知る術がない、(c) cache dir 命名規則はソースの絶対パス由来で、ユーザーが「どれがどのコマンドのキャッシュか」対応づけにくい
- 深刻度: **confusing**
- 修正案: 短期は README に手動削除手順(`rm ~/.moon/bin/<name>` + `rm -rf ~/.mbtx-install/<path-key>`)。本筋は manifest 導入で `mbtx-install list` / `mbtx-install uninstall <name>`(バイナリ削除+workdir削除)

### F-3【confusing】成功時でも moon の INFO ログが大量に素通しされる

- シナリオ: 全インストール操作
- 試したこと: 任意の `mbtx-install x.mbtx`
- 期待: `Installed 'x' to '...'` が目立つ出力(必要なら進捗1行)
- 実際: 毎回数十行の `INFO moon::rr_build:...` `n2::work:...` トレース + C 警告(dep-async では thread_pool.c の警告まで)が流れ、唯一意味のある `Installed` 行と `Finished. moon: ...` が埋もれる。README は失敗時の診断 passthrough を謳うが、成功時のノイズもそのまま
- 深刻度: **confusing**(初見ユーザーは「エラー?」と身構える)
- 修正案: デフォルトで moon の出力を抑制(ビルド失敗時のみフルログ)し、`--verbose` で従来通り。あるいは stderr を畳んで最後にサマリ

### F-4【minor】ビルド失敗時の hint が「moon update」固定で、自分のコードのコンパイルエラー時も出る

- シナリオ: install basics(壊れたソース)
- 試したこと: `@regexp.compile` を `fn main`(非 raise)で呼ぶソースをインストール → moon が `[4122] Function with error is not allowed in 'fn main'` を正しく報告
- 期待: 文脈に合ったヒント(この場合 moon の診断だけで十分)
- 実際: moon の診断は正確だが、末尾に必ず `hint: if dependency resolution failed, run 'moon update' and retry` が付く。依存解決失敗(本当に moon update が有効)でもコンパイルエラー(無関係)でも同一文面で、後者ではユーザーを遠回りさせうる
- 深刻度: **minor**
- 修正案: moon の出力中に「not found in registry / not found」系を検出したときだけ hint を出す、または文言を「もし依存解決失敗なら〜」ではなく診断末尾への注意書きに留める

### F-5【minor】symlink したスクリプトは realpath 先のベース名でインストールされる

- シナリオ: install basics(別名経路)
- 試したこと: `ln -s hello-no-deps.mbtx linked-script.mbtx` → `mbtx-install linked-script.mbtx`
- 期待: コマンド `linked-script` ができる
- 実際: `Installed 'hello-no-deps'`(realpath 解決後のベース名が使われ、workdir も解決後パスで共有)。`linked-script` コマンドは存在しない。キャッシュ共有としては合理的だが、「渡したファイル名=コマンド名」の直感とずれる
- 深刻度: **minor**
- 修正案: 名前決定は渡したパスの basename にする、または README に realpath 解決を明記

### F-6【minor】`--version` がない

- 試したこと: `mbtx-install --version`
- 実際: `unexpected argument '--version'`(exit 2)。ツール自体のバージョン確認手段なし。issue 報告時に困る
- 修正案: `--version` 追加(moon.pkg の version を埋め込み)

### F-7【minor】中断(Ctrl-C)すると workdir に中途半端な残骸が残る

- シナリオ: interrupted install
- 試したこと: workdir 削除後に `mbtx-install dep-async.mbtx` を開始、ビルド中(LinkCore 実行中)にプロセスグループへ SIGINT
- 実際: mbtx-install と moon がともに停止。`~/.mbtx-install/...` 配下に `native/debug/build` の中間生成物と `.moon_db`/`.moon-lock` が残り、バイナリは**コピーされない**(部分バイナリなし=良い)。同一インストール再実行で増分ビルドが続きから走り正常に完了・動作。回復は完全
- 深刻度: **minor**(残骸は残るが自己修復する)
- 修正案: 必須ではない。気にするなら SIGINT ハンドラで workdir 掃除、または `.tmp` 経由アトミック配置

### F-8【minor】セットアップ段階の摩擦: `moon install` 経路のログが非常に冗長

- シナリオ: setup
- 試したこと: README 通り `moon install https://github.com/podhmo/mbtx-install cmd/mbtx-install`
- 実際: 成功するが 100+ 行の `INFO moon::rr_build` トレースと依存の C 警告が出る(moon 側の挙動で mbtx-install 非依存だが、初見の印象として記録)。`moon install ./cmd/mbtx-install` も同様
- 深刻度: **minor**
- 修正案: README に「大量のビルドログが出るが正常」と一��あると安心。registry 公開後は `moon install podhmo/...` だけ書けばよくなる

### F-9【minor】PATH 警告が相対 `--bin` で相対パスのまま表示される

### F-10【minor】コピー失敗時のエラーが内部 API 表現を露出する

- 試したこと: `mbtx-install hello-no-deps.mbtx -o mbtx-install`(実行中バイナリへの上書き)
- 実際: ビルド自体は走った後、コピーで `error: cannot write '/home/ubuntu/.moon/bin/mbtx-install': OSError("@fs.open(): \"...\": Text file busy")`(exit 1)。原因は分かるが `@fs.open()` という内部表現がそのまま出る
- 深刻度: **minor**
- 修正案: OS エラーは `Text file busy` 相当の人間向け文言にマップする

- 試したこと: `mbtx-install hello-no-deps.mbtx --bin relbin -o rb`
- 実際: `warning: 'relbin' is not on PATH; 'rb' will not run as a command` — 表示が `relbin`(相対)のままで、どこを PATH に足せばよいか一瞬分からない。動作自体は正常(./relbin/rb は走る)
- 深刻度: **minor**
- 修正案: 警告には絶対パスを表示

---

## うまくいった点(went smoothly)

- **セットアップ**: `moon install https://github.com/podhmo/mbtx-install cmd/mbtx-install` が clone 不要で一発成功。`./cmd/mbtx-install` ローカルパスも成功。registry 形式は未公開ゆえ `Module 'podhmo/mbtx-install' not found in registry` と明確なエラー(README の説明通り)
- **`--help` / usage / exit code**: ヘルプは簡潔正確。ファイルなし(exit 2 `file not found`)、非 `.mbtx`(exit 2 `not a .mbtx file`)、`.mbtx` 名のディレクトリ(exit 2 `not a regular file`)、余分な引数(exit 2)、`moon` 不在(exit 1 `error: 'moon' not found on PATH`)、`~/.moon/bin` 非 PATH(警告のみ・インストールは成功) — README の Errors 節と完全一致
- **インストール基礎**: dep-free / `moonbitlang/core`(`@env.args()`)/ `moonbitlang/x`(json5)/ `moonbitlang/async` / `moonbitlang/regexp` が import ブロック記述だけで全て解決・実行。`fn main raise` も普通に使えた
- **壊れた import**: `no-such-org/no-such-pkg` で moon が原因(`module not found`)を明確に報告、exit 255、バイナリは生成されない。workdir にはビルド用 dir が残るのみ
- **更新**: スクリプト編集→再インストールで増分ビルド(3 tasks, ~0.1s)し即反映
- **rename / 共存**: 同一ソースの `-o hola` / `-o hello-b` は workdir 共有で `no work to do`→瞬時に別名追加。v2 インストール後にソースを v3 へ編集→`-o hello-v3` で v2/v3 が別名で共存(install 時点スナップショットが残る)
- **`--bin`**: 存在しない dir は自動作成、`--bin /tmp/mybin` と相対 `--bin relbin` 両方で動作・バイナリ実行可能。PATH 未登録なら警告して成功(F-9 の表示上の小さい揺れはある)
- **fresh 環境**: `HOME=/tmp/fakehome` で `~/.moon/bin`・`~/.mbtx-install` とも自動作成
- **中断→再実行**: SIGINT 直後でも次回実行が自然に完了・バイナリ正常(F-7)
- **`--release`**: `native/release` を別ツリーでビルド(debug ツリーと共存、プロファイル混線なし)

## 検証方法メモ

- `.mbtx` フィクスチャは `~/e2e-scripts/` に集約(添付ファイル参照)
- PATH 操作は `env PATH=...` と `moon` への symlink(`/tmp/moonbin`)で分離して検証
- 中断は非対話シェルでバックグラウンド起動→プロセスグループ SIGINT(Ctrl-C 相当)
- `-o moon` 検証は `~/.moon/bin/moon` を事前バックアップ→確認後即復旧済み(`-o mbtx-install` の検証時も同様に復旧。いずれも現在 `moon`/`mbtx-install` は正常)
