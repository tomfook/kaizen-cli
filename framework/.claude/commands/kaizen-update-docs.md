# Update project documentation

プロジェクト進行に伴い、プロジェクト固有ドキュメント（CLAUDE.md、docs/）の更新を支援する。

**対象**:
- `CLAUDE.md` - プロジェクト固有の必須情報
- `docs/` - プロジェクト固有の詳細情報

**対象外**: `knowledge/` — 横断知識の更新は `/kaizen-reflect-learning` で行う

**実行タイミング**: 作業完了後、ドキュメント更新が必要と感じたとき

**言語**: ユーザーの言語に合わせて応答すること

---

## 実行手順

### Step 1: 現状把握

以下を読み込んで現在の状態を把握:

1. **CLAUDE.md** を読み込み（存在する場合）
2. **docs/** ディレクトリの全ファイルを読み込み
3. **docs/PROJECT_SUMMARY.md** のYAMLフロントマターを確認

### Step 2: 作業履歴から更新候補を抽出

今日の作業履歴（Claude Codeコンテキスト）から以下を特定:

| カテゴリ | 例 |
|---------|---|
| **新たに判明した事実・仕様** | データソースの制約、API仕様、ビジネスルール |
| **意思決定の記録** | 設計判断、採用したアプローチとその理由 |
| **進捗・変更** | 完了したタスク、計画の変更 |
| **成果物の追加・更新** | 新しいファイル、モジュール、機能 |
| **用語の追加** | プロジェクト固有の略語・定義 |
| **プロジェクト固有の教訓** | 失敗したアプローチ、制約・落とし穴、次回の注意点 |

**教訓の振り分け基準**:

- **一般パターン**（プロジェクト横断で通用する知見） → `/kaizen-reflect-learning` で `knowledge/` に反映
- **プロジェクト固有**（このプロジェクトでのみ有効な教訓） → 本コマンドで `docs/LEARNINGS.md` に追記

**新規教訓追加前の knowledge/ 重複チェック（必須）**: 「教訓を `docs/LEARNINGS.md` に追加する」候補が出た場合、追加前に必ず横断 `knowledge/` 既存記述との重複を確認する。外部サービス/ツール仕様起因の制約は `knowledge/` に網羅済みのことが多く、未チェックで docs/ に追加すると後日の棚卸しで削除する後追い作業が発生する。

1. 追加予定の教訓から検索キーワードを2-3個抽出（サービス名・エラー文言・API名・構文要素 等）
2. 次のコマンドで既存記述を探す（knowledge/ の実体と、配布物の skills / commands / agents を走査する。`knowledge/projects/` は対象外）:

   ```bash
   bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-search-knowledge.sh" <keyword> [<keyword>...]
   ```

   - `[H]` のヒット行に付く節（`§`）を読んで、重複かどうかを判定する
   - **`[K]` が 0 件でも「重複なし」とは限らない**（表記揺れ、装飾記号をまたぐ語など）。表記を変えた語でも試す。0 件になる原因の一覧: `.claude/skills/kaizen-reflect-learning/CRITERIA.md § knowledge/ の検索方法`
   - `status=partial`（終了コード 1）は、走査できなかった場所がある。`not-scanned:` の行を確認する（`knowledge/` の無いプロジェクトでは、この重複チェック自体を省く）。`status=error` は検索が実行されていないので、0 件と読まない
3. 結果別処理:

   | 結果 | 処理 |
   |---|---|
   | **完全重複** | docs/ への追加を取りやめ、knowledge/ への参照リンクのみ記載（卒業マーカー形式: `→ knowledge/XXX.md § ... に記載済み`） |
   | **部分重複**（一部のみあり / 補強価値あり） | knowledge/ 側を `/kaizen-reflect-learning` で補強し、docs/ には固有経緯のみ + ポインタを追加。補強が済むまで、エントリに昇格候補のマーカーを付ける（下の「昇格候補を書く」） |
   | **重複なし** | 通常通り docs/ に追加 |

   判断基準: 「次回別プロジェクトで同じ問題に遭遇する人が knowledge/ で見つけられるべきか？」Yes → knowledge/（`/kaizen-reflect-learning` 経由）、No → docs/。

**教訓の棚卸し**（`docs/LEARNINGS.md` が存在する場合）:

最初に、マーカーを読む（昇格待ちの候補、前回の棚卸し、今回見る範囲）:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-learnings-inventory.sh"
```

`[kaizen-learnings-inventory]` ブロックを解析する。ラベルを `grep` で探したり、`git log --since` で差分を取ったりしない（ラベルの検索は、記入フォーマットの例や、候補に言及しただけの文にも当たる。失敗した検索は 0 件と同じに見える）。

| 行 | 読み方 |
|---|---|
| `candidate: L<行> [open] …` | 昇格待ちの候補。下の「昇格候補の処理」で 1 件ずつ行き先を決める |
| `candidate: L<行> [deferred] …` | 先送り中の候補。書かれた再検出条件が、今回の作業で成立したかを確かめる。成立していれば `[open]` と同じに扱う |
| `scope=full` | 全エントリを判定する（理由は `scope_reason=`） |
| `scope=narrowed` | **卒業の判定だけ**、次の 2 つに絞ってよい: `changed:` のファイルが扱う内容に関係しうるエントリ（迷うエントリは判定する）と、見出しの日付が `last_inventory=` 以降のエントリ。`changed=0` なら前者は無い |
| `warning:` | マーカーの書式の崩れ。直す案を Step 3 の提案に含める |
| `status=error`（終了コード `3`） | 読めていない。0 件と読まず、`error=` を伝えて棚卸しを中断する |

範囲を絞れるのは、卒業の判定が `knowledge/` との突き合わせだからである（`knowledge/` が変わっていなければ、結果も変わらない）。「前回 0 件だったから今回も 0 件」とは読まない — `knowledge/` はほぼ毎セッション変わる。陳腐化と内在化は、プロジェクトのコードや依存の変化で決まるので、この差分では絞れない（全エントリを見る）。

既存エントリを確認し、以下に該当するものがあれば削除を提案する:

| 状態 | 基準 | アクション |
|------|------|-----------|
| **卒業** | `knowledge/` に昇格済み | エントリ削除 |
| **陳腐化** | 制約が解消済み（ライブラリ更新、仕様変更等） | エントリ削除 |
| **内在化** | 設計・コードに反映済みで記録の意味がなくなった | エントリ削除 |

**昇格候補を書く**: 次のいずれかで「`knowledge/` に入れるべきだが、まだ入っていない」と判定したら、判定した回にマーカーを書く（Step 3 の提案に含める）。このあと `/kaizen-reflect-learning` を実行する予定でも書く — reflect が棚卸しの結果を受け取る入口は、会話ではなくこのマーカーである（書かなければ、候補は見つけた回で消える）。

- 棚卸しで、既存エントリがプロジェクト横断で通用すると分かった
- 新規教訓の重複チェックが「部分重複」だった（上の表）
- auto memory の棚卸しで、プロジェクト横断の知見が見つかった（下の Step B）

| 対象 | 書く場所 | 行 |
|---|---|---|
| エントリ | そのエントリの最後の bullet | `- **昇格候補**: <横断で残す理由を 1 行>` |
| エントリを持たないもの（auto memory など） | 「棚卸しの記録」の節 | `- **昇格候補**: memory <name> — <理由>` |

- ラベルは `docs/LEARNINGS.md` の言語に合わせる。英語のファイルでは `Promotion candidate`（先送りは `(deferred until: <condition>)`、棚卸しの記録は `Inventory`）
- 候補の行に `→` と `§` を書かない（反映先を決めるのは reflect。`→` で始まる参照は、昇格先マーカーとして照合される）

**昇格候補の処理（棚卸しの完了条件）**: `[open]` の候補が残っている間は、棚卸しを完了としない。候補ごとに、次のどれにするかを Step 3 で提案し、ユーザーが決める（`[deferred]` で条件が成立したものも同じ）。

| 状態 | 行き先 | マーカーの扱い |
|---|---|---|
| 既に `knowledge/` に入っている（検索スクリプトで照合する。前回の reflect が反映した、など） | 卒業 | エントリを削除する。残すなら、候補の行を `- **昇格先**: → knowledge/<path>.md § <節>` に書き換える。エントリを持たない候補は、行を削除する |
| まだ入っていない。今回渡す | 処理 | 行は変えない。最後の報告で、続けて `/kaizen-reflect-learning` を実行するよう案内する（reflect は、候補の行をすべてペイロードに入れる） |
| まだ入っていない。今回は渡さない | 先送り | 行末に `（先送り: <再検出条件>）` を足す。条件は、見直すきっかけになる出来事で書く（「同じ失敗がもう一度起きたら」「別のプロジェクトで同じサービスを使うとき」）。条件の無い先送りは、未消化として数えられる |
| 候補ではなかった（reflect が横断では残さないと判定した、など） | 取り下げ | 行を削除する |

- 候補に言及する文（棚卸しの記録の結果欄、報告）を、行頭の `- **昇格候補**:` の形で書かない。件数は「候補 2 件」のように文の中に書く

**棚卸しの記録を書く**（棚卸しをした回は必ず。Step 4 で実行する）: 上のスクリプトの `record=` の値を使って、「棚卸しの記録」の節に 1 行を書く。

```markdown
- **棚卸し**: <record= の値> — <範囲（全件 / 絞り込み）。卒業 N / 候補 N / 先送り N>
```

- 1 日 1 行。同じ日にもう一度実行したら、その日の行を書き換える（行を増やさない）
- 新しい順に 3 日分まで。4 日目を足すときは、最も古い行を**同じ書き込みで**削る（履歴は git にある）
- 詳細（範囲・`knowledge@<commit>`・内訳）を持つのは最新の行だけ。古い行は「日付 — 結果を 1 行」に縮める
- `knowledge@<commit>` は、次回の範囲を絞る基準になる。`record=` の値をそのまま写す（手で書き換えない）。`record=` に `knowledge@` が無い回（`knowledge/` が git リポジトリでない）は日付だけを書く（次回は全件になる）
- 節が無いファイルでは、冒頭の説明の直後（最初の `## ` の前）に `## 棚卸しの記録`（英語のファイルでは `## Inventory Log`）を作る。記録を残さないと、次回も「前回の棚卸しなし＝全件」になる
- **書いたあとで、スクリプトをもう一度実行する**: `warning:` が無いこと、`[open]` で残っているのが「処理」と決めた候補だけであることを確かめる（書いた直後の書式の崩れは、読み返しでは見つけにくい）

**LEARNINGS.md 肥大化チェック**: 上記の棚卸し後、以下のいずれかに該当したら最大カテゴリの別ファイル切り出しを検討する。

精査トリガー（OR）:
- 行数が 300 行超
- **実質エントリ数**（取り消し線 `### ~~...~~` エントリと `- **昇格先**:` マーカー付き昇格済みエントリを除外したカウント）が 15 件超

切り出し実行条件: トリガー成立、**かつ同一カテゴリに5件以上集中**している場合のみ実施（カテゴリ集中がなければ精査のみ）。切り出し作法: 内容精査で削減を優先し、超過が残る場合のみ最大カテゴリをトピック別に `docs/` の別ファイルへ分割し、元ファイルに参照を残す（詳細指針は `knowledge/meta/DOCUMENTATION_GUIDELINES.md`）。

**NEXT_STEPS の棚卸し**（`docs/NEXT_STEPS.md`。境界定義は `knowledge/meta/DOCUMENTATION_GUIDELINES.md` § Document Role Boundaries）:

本コマンドが NEXT_STEPS の**書込主体**である（`/kaizen-suggest-next` は読み取り専用で、再提案ガード・機熟判定に使うだけ）。以下はすべて**提案**であり、Step 3 で一括表示し Step 4 の承認後に実行する（「実行はユーザー」原則を維持）。

| 操作 | 対象 | アクション |
|------|------|-----------|
| **剪定**（ファイル存在時） | `## Open items` で今セッションに完了した項目 / `## Deferred` で先送り理由・条件が解消・陳腐化した項目 | 削除提案 |
| **追加** | 今セッションで「次にやる」と決めた未着手の実行可能項目 → `## Open items` へ。`/kaizen-reflect-learning` が「要熟考」として示した起票文（その場で knowledge/ に書かなかった提案）も、文面を変えずに `## Open items` へ。意図的に先送りした項目 → `## Deferred` へ（理由・条件＋日付付き） | 追加提案 |
| **新規作成** | ファイルが無く、かつ追加対象がある場合のみ | 2節（`## Open items` / `## Deferred`）スケルトンで作成提案。追加対象が無ければ作らない |

**境界遵守**: 「なぜ決めたか」は `docs/PROJECT_SUMMARY.md § Design Decisions`、「何が失敗したか」は `docs/LEARNINGS.md`。NEXT_STEPS には書かない。短く保つ。

**auto memoryの棚卸し**: memoryディレクトリ内の各ファイルについて、以下の順序で判断する:

**Step A: 永続化判断**（判断基準: `knowledge/meta/DOCUMENTATION_GUIDELINES.md` § Auto Memory）

各memoryの内容を以下の3基準に照らす。**いずれか1つでも該当すれば永続化すべき情報**:
- 失われたら再構築に手間がかかる（復元コスト）
- チームメンバーや未来の自分が参照する可能性がある（読者の存在）
- 「なぜそうしたか」の追跡が必要（意思決定の根拠）

**Step B: 永続化すべき場合 → 配置先を検索**

- プロジェクト固有の知見 → docs/LEARNINGS.md、CLAUDE.md
- プロジェクト横断の知見 → `/kaizen-reflect-learning` で knowledge/ へ

配置先の候補ファイルを実際に読み、同内容が**既に存在するか確認**する:
- 既に存在する → **削除漏れ**。memoryから削除
- 存在しない → **昇格候補**。ドキュメントへの転記を提案。プロジェクト横断の知見で、同じ回に `knowledge/` への反映まで進まないなら、`docs/LEARNINGS.md` の「棚卸しの記録」の節に候補の行を書く（上の「昇格候補を書く」。memory ファイルにはマーカーの置き場が無く、書かなければ reflect の入口に載らない）

**Step C: 永続化不要の場合 → 陳腐化チェック**

一時的な情報で既に無意味（過ぎた期限、完了した状況）なら削除を提案。それ以外は維持。

**禁止**: 配置先の候補ファイルを読まずに「重複なし」と判断すること。

昇格時はドキュメントに転記後、元のmemoryファイルとMEMORY.mdのエントリを削除する（SSOT維持）。

**PROJECT_SUMMARY.md 専用チェック**:

- ステータス変更があれば `status` を更新（planning → developing → released → completed、一時停止は on-hold）
- キーワードとなる技術・概念が増えた → `keywords` に追加
- 技術スタックに変更があれば「Tech Stack」セクションを更新

**結論の自己検証（必須）**: Step 2 で「更新不要」と判断した場合でも、以下を自問する。新たな更新候補が見つかった場合は Step 2 の結果に追加する。

- **暗黙の変更の見落とし**: 新ファイル追加・リネーム・設計変更があったのに CLAUDE.md / PROJECT_SUMMARY.md に未反映ではないか？
- **計画/NEXT_STEPS の陳腐化**: 完了・不要になった項目やファイルパス変更が残っていないか？
- **教訓の取りこぼし**: 失敗・リトライがあったのに教訓として拾えていないか？
- **昇格候補の置き去り**: `[open]` の候補のうち、行き先（卒業 / 処理 / 先送り / 取り下げ）を決めていないものが残っていないか？

### Step 3: 更新提案を一括表示

以下の形式で更新提案を表示:

```markdown
## ドキュメント更新提案

### CLAUDE.md への追加/更新

**現在の行数**: XXX行
**更新後の予想行数**: XXX行

#### 追加提案:
- [セクション名]: [追加内容の要約]

#### 更新提案:
- [セクション名]: [変更内容の要約]

---

### docs/ への追加/更新

#### [ファイル名].md
- [追加/更新内容の要約]

---

### 昇格候補（`candidate:` の行が 1 件でもあれば、全件を表示）

| 候補 | 状態 | 提案する行き先 |
|------|------|---------------|
| [エントリの見出し / memory 名] | open / 先送り中（条件が成立した・していない） / 今回追加 | 卒業 / 処理（続けて reflect） / 先送り（条件: …） / 取り下げ |

---

### auto memory 棚卸し結果

| memory ファイル | 判定 | アクション |
|----------------|------|-----------|
| [ファイル名] | 昇格（→ 配置先） / 削除漏れ / 陳腐化 / 維持 | [具体的なアクション] |

---

### 新規作成提案（必要な場合）

#### docs/[新規ファイル名].md
- [ファイルの目的と内容の要約]

---

承認しますか？（はい / いいえ / ステップバイステップで確認）
```

### Step 4: 承認後に更新実行

ユーザーの承認を得てから更新を実行。

**教訓の棚卸しをした回の追加処理**: `docs/LEARNINGS.md` への編集（エントリの削除、候補のマーカー）をすべて終えてから、棚卸しの記録を書き、`kaizen-learnings-inventory.sh` をもう一度実行して確かめる（Step 2 の「棚卸しの記録を書く」）。「処理」と決めた候補が残る回は、最後の報告に候補の見出しを並べ、続けて `/kaizen-reflect-learning` を実行するよう案内する。

**更新後の検証**: `docs/` や `CLAUDE.md` を検査するテスト・lint があるプロジェクトでは、更新をすべて終えたあとに実行する（参照切れなどは、書いた直後にしか安く直せない）。

**PROJECT_SUMMARY.md更新時の追加処理**（`docs/` の `.md` を追加・削除・改名した回、またはタイトルを変えた回）:

`## Project Documentation` セクションを自動更新する:
1. `docs/` ディレクトリの `.md` ファイルをスキャン
2. 各ファイルの先頭行からタイトルを抽出
3. `## Project Documentation` セクションを最新のファイル一覧で更新

形式:
```markdown
## Project Documentation

- `PROJECT_SUMMARY.md` - Project overview (this file)
- [PLAN.md](./PLAN.md) - Implementation plan
```

### Step 5: プロジェクトレジストリ同期

`docs/PROJECT_SUMMARY.md` と `docs/LEARNINGS.md` を、レジストリ（`knowledge/projects/`）へ同期する。

レジストリは**派生物**で、正本はプロジェクト側の `docs/` にある。`knowledge/projects/` 配下（`INDEX.md`・`details/`・`learnings/`）は手で編集せず、必ず下のスクリプトで更新する（手で直した内容は次の同期で上書きされる）。

**前提条件**: プロジェクトルートに `knowledge/` があること。無ければ「knowledge/ が見つかりません。レジストリ同期をスキップします。」と表示して、Step 5 と Step 6 をスキップする。

**注意**: `knowledge/` はシンボリンクであり、Glob ツールはシンボリンク先を辿れない。レジストリの中身（`knowledge/projects/INDEX.md` など）を確かめるときは、Read ツールでパスを直接指定する。

1. ミラーの同期（`details/{id}.md` と `learnings/{id}.md`）:

   ```bash
   bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-registry.sh" register knowledge
   ```

   プロジェクト ID は `docs/PROJECT_SUMMARY.md` の frontmatter（`project.id`）から読まれる。引数では渡さない（別名のミラーを作る取り違えが起きない）。`[kaizen-registry-register]` ブロックの `status` で分岐:

   | `status` | 対応 |
   |---|---|
   | `ok` | `details=` と `learnings=` の値（`created` / `updated` / `unchanged` / `not-synced` / `kept`）を報告に含める。`learnings=not-synced` のときは `learnings_reason=` も添える（同期されなかった回を無音にしない） |
   | `skipped` | frontmatter に `registry: false` がある。同期しない。手順 2 と Step 6 もスキップする |
   | `error`（終了コード `1`） | `error=` を表示し、Step 5 と Step 6 を中断する（何も書き込まれていない）。`source_lost=` の行があれば、`docs/PROJECT_SUMMARY.md` が失われてミラーだけが残っている。ミラーから復元する案をユーザーに示す |

   `docs/LEARNINGS.md` は、エントリ（`### ` 見出し）が 1 件以上できた回から同期される。一度同期したあとは毎回全文を写す（ミラーに古いエントリを残さない）。フィルタはしない — `→ knowledge/` マーカーの判定は auditor 側で行う。

2. INDEX の再生成:

   ```bash
   bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-registry.sh" sync-index knowledge
   ```

   `details/*.md` の frontmatter から一覧表を作り直す（表の前後の文章は保持される。`INDEX.md` が無ければテンプレートから作る）。`[kaizen-registry-sync-index]` ブロックの `index=`（`updated` / `unchanged` / `created`）と、`added` / `updated` / `removed` の件数を報告に含める。`status=error` なら `error=` を表示する（`INDEX.md` は変更されていない）。

3. 出力に次の行があれば、そのままユーザーに伝える:

   | 行 | 意味 |
   |---|---|
   | `warning:` | 同じ id を持つ details が複数ある／ファイル名と id が食い違う／frontmatter が読めない／details の無い learnings、など。自分のプロジェクトに関するものは、この場で直す案を示す |
   | `kept:` | details が無い（または frontmatter が読めない）ため、手書きの行をそのまま残したプロジェクト。情報は落としていない |
   | `uncommitted:` | 未コミットのミラー。**自分のプロジェクト以外**のものは、他セッションが作業中の可能性がある。その内容も今回の表に反映されている。触らず、あることを伝える |

### Step 6: knowledge/ の自動コミット

Step 5 を実行した場合、**自分のプロジェクトのミラーと INDEX だけ**をコミットする（`<project-id>` は Step 5 の `project_id=` の値）:

```bash
bash "$KAIZEN_CLI_DIR/framework/bin/kaizen-knowledge-commit.sh" \
  -m "kaizen sync: update project registry for <project-id>" \
  -- knowledge/projects/INDEX.md \
     knowledge/projects/details/<project-id>.md \
     knowledge/projects/learnings/<project-id>.md
```

- `learnings/<project-id>.md` が無い回も、3 つとも渡してよい（無いパスは `skipped:` に出るだけで、残りはコミットされる）
- `git add -A` やパスを付けない `git commit` は使わない — knowledge/ は全プロジェクト・全セッションの共有物で、他セッションが編集途中のファイルまで自分のコミットに入る

出力の `[kaizen-knowledge-commit]` ブロックの `status` で分岐:

| 終了コード | `status` | 対応 |
|---|---|---|
| `0` | `committed` | `message:` の件名と `committed:` のファイルが意図どおりか確認して報告 |
| `0` | `nothing` / `skipped` | 変更なし、または git リポジトリでない。そのまま続行 |
| `2` | `error` | git の失敗。`git:` / `failed:` の内容を警告として表示して続行（knowledge/ の変更自体は保持されている） |
| `3` | `error` | パス・引数の誤り。`error=` を読んで直し、再実行する |

`other:` の行（今回のコミットに含めなかった他の未コミット変更）があれば、**触らず**、あることをユーザーに伝える。

> 詳細: `.claude/skills/kaizen-editing-knowledge/FILE_OPERATIONS.md § knowledge/ のコミット`

---

## docs/ 推奨構成・CLAUDE.md 管理ルール

> 詳細: [knowledge/meta/DOCUMENTATION_GUIDELINES.md](knowledge/meta/DOCUMENTATION_GUIDELINES.md)

**要点**:
- CLAUDE.md: 200行以下を目安、超えたらdocs/に切り出し
- docs/PROJECT_SUMMARY.md: **必須、YAMLフロントマター必須**
- docs/その他: 計画・意思決定ログ（任意）

---

## 切り出し時の記載形式

CLAUDE.mdには参照リンクのみ残す:

```markdown
## 分析計画

> 詳細: [docs/ANALYSIS_PLAN.md](./docs/ANALYSIS_PLAN.md)
```

---

## 更新時の注意事項

1. **knowledge/は編集しない**: プロジェクト固有情報のみ対象
2. **簡潔性を維持**: 箇条書き優先、長文は避ける
3. **重複を避ける**: 同じ情報を複数ファイルに書かない
4. **SSOT**: 詳細は1箇所に集約し、他は参照リンクで誘導

---

## PROJECT_SUMMARY.md フォーマット維持ルール

PROJECT_SUMMARY.mdはプロジェクトレジストリへの登録対象。フォーマットを厳守すること。

### YAMLフロントマターの維持

**必須**: ファイル先頭のYAMLフロントマター（`---`で囲まれた部分）を維持・更新する。

```yaml
---
project:
  id: "project-id"           # 必須: 一意識別子
  name: "プロジェクト名"      # 必須: 人間可読な名前
  status: planning           # 必須: planning | developing | released | completed | on-hold
  keywords:                  # 推奨: 検索用キーワード
    - キーワード1
  created: "YYYY-MM-DD"      # 任意: 作成日（レジストリ一覧の並び順に使う。無いと末尾に並ぶ）
  updated: "YYYY-MM-DD"      # 任意: 更新日
---
```

レジストリの一覧表（`knowledge/projects/INDEX.md`）は、この frontmatter から機械的に作られる（Step 5）。読み取るのは `project:` 直下の `id`・`name`・`status`・`keywords`・`created`・`updated`・`registry` だけで、YAML 全般を解釈するわけではない。次の形を守る:

- 値は 1 行に書く（`>-` や `|` のブロックスカラーは使わない）
- `keywords` は `[a, b]` か、`- a` を並べたリストで書く
- レジストリに載せたくないプロジェクトは、`project:` の下に `registry: false` を足す（同期もされない）

### 更新時のチェックリスト

- [ ] YAMLフロントマターが存在するか確認
- [ ] `updated` 日付を更新
- [ ] ステータス変更があれば `status` を更新
- [ ] 新しいキーワードがあれば `keywords` に追加

### 標準セクション構造

以下のセクション見出しを使用（順序推奨）:

| セクション | 用途 |
|-----------|------|
| `## Purpose` | プロジェクトの目的・背景 |
| `## Overview` | 処理内容の概要 |
| `## Tech Stack` | 使用言語・フレームワーク・サービス |
| `## Design Decisions` | ADR的な判断記録 |
| `## Notes` | 運用・開発上の注意 |
| `## Project Documentation` | docs/内の全.mdファイル一覧（自動更新） |

### 禁止事項

- **YAMLフロントマターを削除しない**: 編集時も必ず維持
- **フォーマットを崩さない**: レジストリ同期に影響

---

## 関連コマンド

| コマンド | 目的 |
|---------|------|
| `/kaizen-suggest-next` | 次のステップの提案 |
| `/kaizen-reflect-learning` | knowledge/ への知見反映 |
