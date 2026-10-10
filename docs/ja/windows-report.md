# 調査レポート: Windows 対応 (issue #3)

実機(Windows Server 2022)での検証結果と方針案。随時追記する調査メモ。

- 調査日: 2026-10-10
- 環境: Windows Server 2022 / `moon 0.1.20260920` / MinGW gcc (choco) / `MOON_CC=C:/moon-cc-shim/gcc.exe` (podhmo/moonbit-individual-handbook の blueprint が作った `-D_CRT_RAND_S` 注入 shim) / MSVC 未導入

---

## 1. 実機検証結果(すべてこのマシンで再現済み)

### 1.1 moon ツールチェーン自体

- `moon` / `moonx` は `%USERPROFILE%\.moon\bin` に存在し、ユーザ PATH に入っている(インストーラが登録)。
- **C コンパイラの自動探索**: MinGW があると `C:\ProgramData\mingw64\mingw64\bin\cc.exe` が使われた。`--dry-run` 出力に `C:/ProgramData/mingw64/mingw64/bin/cc.exe -o ...` と明記。
- MinGW を PATH から外すと `no system C compiler found; tried cc, gcc, clang`。**バンドルの `internal/tcc.exe` は Windows では探索対象に入っていない**(blueprint の「tcc ではランタイムがビルド不可」と一致)。
- **MSVC 実機検証(同日・このマシンに VS2022 BuildTools + VCTools 導入後)**: vcvars64 で INCLUDE/LIB をロードして `cl.exe` が PATH にある状態では、**`MOON_CC` 未設定でも moon は自動的に `cl.exe` を検出**(`--dry-run` に `cl.exe /nologo /std:c11 /utf-8 /MT /Fo...` の実コマンド確認)。「tried cc, gcc, clang」の文言は cc 系が見つからなかった時の限定メッセージで、`cl` は別経路で検出される模様。
- `MOON_CC=<cl.exe フルパス>` でも動作(vcvars64 の INCLUDE/LIB 環境変数が必要——ヘッダ/ライブラリ解決のため。`cl.exe` 単体の PATH 追加だけでは不十分な点に注意。DevBox/PowerShell で恒久化するなら vcvars64 起動ショートカット経由が実質必須)。

### 1.2 `.mbtx` の native ビルド

| 条件 | 結果 |
|---|---|
| MinGW 素( `cc` 自動探索) | **失敗**: `~/.moon/lib/runtime/env.c:244: error: implicit declaration of function 'rand_s'` — blueprint 記録の `_CRT_RAND_S` 問題そのまま |
| `MOON_CC=C:/moon-cc-shim/gcc.exe` | **成功**: `single.exe` 約 246KB(debug)、実行して正しく出力。`--release` も成功 |
| `moonbitlang/async` 依存の `.mbtx` + shim | **失敗**: `async/src/internal/event_loop/fs.c:23: #error "Currently only MSVC is supported on Windows"` |

- 成果物パス規約は Linux と同一: `<target-dir>/<file>.mbtx/native/<profile>/build/single/single.exe`。
- `--dry-run` のリンク行は `-o ./_build/.../single.exe`(相対パス・`/` 区切り)を実機確認。`find_link_target` の `.exe` パースはそのまま効く。

### 1.3 `moonbitlang/async` の Windows 事情(最重要)

- `async/src/internal/event_loop/` に `thread_pool.c` `fs.c` `process.c` `iocp.c` 等があり、**複数ファイルに `#ifndef _MSC_VER → #error "Currently only MSVC is supported on Windows"`** の明示ガード。
- Windows 用実装(`event_loop_windows.mbt`, `io_windows.c`, `process_windows.mbt`, `windows_console.mbt`)は存在するが **MSVC 専用**。MinGW は意図的に排除されている。
- 帰結:
  - **mbtx-install 本体(`installer` は `moonbitlang/async/fs` + `async/shell` に依存)は MinGW shim ではビルドできない**(`moon install ./cmd/mbtx-install` 実機失敗確認)。
  - **`moonbitlang/async` を import する `.mbtx` のインストールも同じ壁**(dep-async.mbtx で実機確認)。
  - core/x 系のみの `.mbtx`(`x/fs` 等)は MinGW shim でビルド・実行できる(dep-xfs.mbtx で実機確認)。

### 1.4 `moon install` の Windows 挙動

- `moon install ./cmd/main --bin <dir>` → **`main.exe` として配置**(`.exe` 接尾辞は moon 側が付ける)。成功メッセージ `Installed 'main' to '<dir>\main.exe'`。
- デフォルト配置先は `~/.moon/bin` = `%USERPROFILE%\.moon\bin`(インストーラがユーザ PATH に登録済み)。
- **MSVC 環境で `moon install ./cmd/mbtx-install` が完走**: `mbtx-install.exe`(938KB)生成・配置成功。つまり**ツール本体は MSVC でネイティブビルド可能**。

### 1.4.1 MSVC 製 mbtx-install.exe の実行結果(実機・これが本丸)

- `--help` は正常表示。
- `mbtx-install hello.mbtx --bin <dir>` → **`error: HOME is not set`** で終了(HOME 未設定の実害をそのまま踏んだ)。
- `HOME=C:\Users\Administrator` を手動セットして再実行 → 次は `@fs.exists(): "...\bin3/C:\\Users\\Administrator\\wintest\\hello"` で OSError。**`basename()` が `\` 区切りを知らず `rev_find("/")` でフルパスをそのまま返し、`command_name` が `C:\...\hello` をコマンド名にした**結果、`dest` が `bin3/C:\...` という非法名に。パス正規化系のバグが実害として確認できた(レポートの差分表の1行目ではなく複数行が実害)。
- `--list` は正常動作(`(no installs recorded)`)。manifest 読み書きの骨格自体は Windows でも動く。

### 1.5 Windows ネイティブの環境変数

- 実機の native バイナリから `@env.get_env_var` で確認: **`HOME` は未設定**、`USERPROFILE=C:\Users\Administrator`、`MOON_HOME` 未設定。
- → 現行コードの `@env.get_env_var("HOME")` は **Windows で確実に死ぬ**("HOME is not set" で exit 1)。

## 2. コード差分リスト(全て `installer/` に局在)

| 箇所 | Unix 前提 | Windows の事実 | 対応 |
|---|---|---|---|
| home 解決 | `HOME` | `HOME` 未設定 | `MOON_HOME → HOME → USERPROFILE` の順で解決(moon 自身は `%USERPROFILE%\.moon` に置いている) |
| `cache_key` | `/`→`-` | `C:\...` には `\` と `:` が残り、`:` は Windows のディレクトリ名で**違法** | 先に `\`→`/` 正規化 → `:`→`-` → `/`→`-` |
| `basename`/`dirname` | `rev_find("/")` | 実パスは `\` 区切り | 入口で `\`→`/` に正規化してから従来処理 |
| `resolve_link_target` | `has_prefix("/")` で絶対判定 | `C:\...` / `C:/...` は `/` で始まらない | ドライブレター(`^[A-Za-z]:`)・UNC(`\\`)も絶対扱い |
| PATH 分割 | `:` | `;` | プラットフォームで切替 |
| `program_on_path("moon")` | 裸名 | `moon.exe` | `.exe`/`PATHEXT` 考慮 |
| インストール名 | `<bin>/<name>` | `<name>.exe` でないと実行不可 | Windows では `dest = name + ".exe"` |
| `is_valid_name` | `/` のみ排除 | `<>\:"/\\|?*` が Windows ファイル名で違法 | 文字セット拡張 |
| `chmod(0o755)` / `permission=0o755,0o644` | POSIX | Windows では意味なし | 既に失敗黙殺済み、そのまま可 |
| 表示文言 | `Installed 'x' to '...'` | dest が `.exe` 付きになる | 表示も `.exe` 込みに |
| `e2e/run.sh` | bash | 要 PowerShell | `run.ps1` 併置 or 統一 runner |
| `--list` 表示 | `name -> source` | 同上 | `.exe` 含むか要決め(推奨: 記録名は `name`、実ファイルは `name.exe`) |

### 差分の大きさ

- 上記はほぼ `paths.mbt` + `install.mbt` の I/O 層に集中し、**ドメインの設計変更はゼロ**。新たに必要なのは「プラットフォーム判定」の1点のみ(検討: `moonbitlang/core` の環境情報 or 環境変数 `OS=Windows_NT` / `PATHEXT` の存在で判定)。

## 3. 案の比較

### 案A: **MSVC 必須化**(推奨)

- 事実:`moonbitlang/async` が `_MSC_VER` を強制 → **本体も async 依存スクリプトも MSVC 以外では結局ビルド不可**。MinGW shim で動くのは async 不使用スクリプトだけ。
- 要件:`Visual Studio Build Tools`(C++ ワークロード)+ Windows SDK。moon 側は `MOON_CC=cl.exe`(または clang-cl)明示が確実。
- コスト:README の前提記述 + 上記パス差分のみ。**実装変更量は最小**。
- 備考:MSVC Build Tools は開発者の Windows 環境では一般的。ユーザー負担は「一度入れれば済む」型。

### 案B: **MinGW + MOON_CC shim**

- 検証済み:async 不使用 `.mbtx` は完動(single.exe 実行確認)。
- しかし **本体がビルドできない**ため、そのままでは mbtx-install を Windows で動かせない。
- 変形B′:本体を async-free に書き換え(`x/fs` + `extern "c"` プロセス起動)。技術的に可能だが realpath/プロセス capture を FFI 自前化する必要があり、**工数に対し「async 不使用スクリプトしかインストールできない」制約が残って利点が薄い**。
- 結論:単独では不成立。B′ も非推奨。

### 案C: **Wasm + wrapper**

- design.md で既に却下(moonx は常に Wasm・起動遅・moon runtime 必須)。今回の検証で覆す材料なし。**却下維持**。

### 案D: **WSL のみサポート(現状維持)**

- Windows 上の WSL では現行 Linux 実装がそのまま動く(ツールチェーンも unix.sh で入る)。
- コスト:README に「Windows は WSL 経由」の記述のみ。
- issue 記載の「ユーザーの利用想定は当面 WSL 中心」と整合。ネイティブ対応の手戻りリスクが嫌ならこちら。

## 4. 推奨

**A(MSVC 必須)+ D(WSL 記述)の併用**が実質最小で誠実:

1. README/設計ドキュメント:Windows ネイティブは「MSVC Build Tools 必須(または WSL 経由)」と明記。
2. コード:§2 の差分を実装(HOME 解決・cache_key 正規化・`;`・`.exe`・ファイル名文字・ドライブ判定)。これらは「Windows 対応」の本丸であり、MSVC 経路を選んでも必須。
3. MinGW shim は「async 不使用スクリプトのみ動く経路」として注記程度に留め、サポート経路にしない(本体が通らないため)。
4. `moonbitlang/async` が将来 MinGW/clang-cl を許容すれば案B の条件が変わる → upstream 連携の検討事項に追加してよい。

## 5. 未検証・残課題

- ~~MSVC 実機未検証~~ → **解消(同日検証)**: `moon install ./cmd/mbtx-install` 完走、`mbtx-install.exe --help` 動作、実行時の Unix 前提バグも実機で再現(§1.4.1)。
- ~~moon の MSVC 自動探索~~ → **解消**: `cl.exe` が PATH にあれば `MOON_CC` 未設定でも自動検出されることを `--dry-run` 出力で確認。
- **`@fs`/`@shell` の Windows ランタイム詳細**(`realpath` が `\` を返すか、`walk` の区切り、`@shell.Cmd` が cmd 経由か直接 spawn か、stdout/stderr の Capture 実装):パス正規化実装の詳細設計に依存。MSVC 環境で `mbtx-install` を直せば順次検証できる状態にある。
- **`@fs.mkdir(recursive)` が非法名(`:` 含有)で何を返すか**: dest 判定の前段でどう落ちるか実機未確認(今回は dest で先に OSError した)。
- **実使用レベルの e2e**: `.exe` 付け・manifest・`--list`・上書きガードを含めた Windows 版フローは、コード修正後に `run.ps1`(or 同等)で確認する段階。
