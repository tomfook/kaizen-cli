# Kaizen-CLI: The Concept

## The Problem / 課題

Claude Code is powerful, but each session starts from zero. Project-specific context can be captured in CLAUDE.md, but broader knowledge — industry expertise, technical patterns, lessons from past failures — evaporates when a session ends. Switch projects, and you're repeating yourself again.

Claude Codeは強力だが、セッションごとに知識がゼロに戻る。プロジェクト固有の文脈はCLAUDE.mdで補えるが、より広い知識 — 業界の専門知識、技術パターン、過去の失敗から学んだ教訓 — はセッション終了とともに消える。プロジェクトを切り替えれば、また同じ説明の繰り返しになる。

The obvious answer is "write things down." But when? Maintaining a separate knowledge base feels like extra work — and extra work doesn't get done.

「書き残せばいい」という解決策は明白だ。しかし、いつ？ 知識ベースを別途メンテナンスするのは余計な作業に感じる — そして余計な作業は続かない。

## The Insight: Friction as Material / 着想：引っかかりを材料にする

Kaizen-CLI is built on one key insight: **you don't need a separate improvement process**. The material for improvement is already there — it's the friction you encounter during real work.

Kaizen-CLIは一つの着想に基づいている：**改善のためのプロセスを別に設ける必要はない**。改善の材料はすでにそこにある — 実務の中で遭遇する引っかかりがそれだ。

Every work session naturally produces signals:

どの作業セッションでも、自然にシグナルが生まれる：

- An error you didn't expect → a pitfall worth recording / 想定外のエラー → 記録すべき落とし穴
- A technique you had to look up → knowledge that was missing / 調べ直した技法 → 不足していた知識
- A pattern that worked well → a reusable approach / うまくいったパターン → 再利用できるアプローチ
- A correction the user made → an implicit rule made explicit / ユーザーが修正した箇所 → 暗黙のルールの明文化

These are not "improvement items" to add to a backlog. They're natural byproducts of doing work. Kaizen-CLI captures them and feeds them back into your knowledge base, so the next time you — or any of your projects — encounter the same situation, the knowledge is already there.

これらは「改善項目」としてバックログに積むものではない。作業の自然な副産物だ。Kaizen-CLIはこれらを捉えて知識ベースにフィードバックする。次に同じ状況に遭遇したとき — どのプロジェクトであっても — その知識はすでにそこにある。

**Work and improve are not two separate activities. They are one.**

**作業と改善は、二つの別の活動ではない。一つだ。**

## The Kaizen Cycle / Kaizenサイクル

The cycle wraps around your real work. You don't "run the cycle" — you do your work, and the cycle captures what you learn.

サイクルは実務を包み込む形で回る。「サイクルを回す」のではなく、実務をこなす中で学びが捉えられる。

```
                    ┌──────────────────────────────────────────────┐
                    │                                              │
                    ▼                                              │
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Init   │───▶│ Suggest │───▶│ Plan &  │───▶│ Execute │───▶│ Reflect │
│         │    │  Next   │    │ Decide  │    │(= your  │    │         │
│         │    │         │    │         │    │ actual  │    │         │
│         │    │         │    │         │    │  work)  │    │         │
└─────────┘    └─────────┘    └─────────┘    └─────────┘    └─────────┘
                    ▲                                              │
                    │     Friction from work feeds knowledge/      │
                    │       which accelerates the next cycle       │
                    └──────────────────────────────────────────────┘
```

### Init — プロジェクト初期化

`/kaizen-init-project` sets up a new project: creates a `knowledge/` symlink to the shared knowledge directory, links skills, generates `CLAUDE.md` and `PROJECT_SUMMARY.md`, and registers the project in the cross-project registry.

`/kaizen-init-project` が新規プロジェクトをセットアップする：共有知識ディレクトリへの `knowledge/` symlinkの作成、スキルのリンク、`CLAUDE.md` と `PROJECT_SUMMARY.md` の生成、プロジェクトレジストリへの登録。

This is a one-time step. From this point on, the project has access to all accumulated knowledge from every other project.

これは一度きりのステップ。以降、そのプロジェクトは他のすべてのプロジェクトから蓄積された知識にアクセスできる。

### Suggest Next — 次のステップ提案

`/kaizen-suggest-next` analyzes the current session's work and suggests what to do next. It reads the session history, project context, and accumulated knowledge to generate suggestions at three levels:

`/kaizen-suggest-next` は現在のセッションの作業を分析し、次にやるべきことを提案する。セッション履歴、プロジェクトコンテキスト、蓄積された知識を読み取り、3つのレベルで提案を生成する：

1. **Creative suggestions** — opportunities the user hasn't considered: improvements, extensions, integrations, cross-application to other projects / **創造的提案** — ユーザーが検討できていない機会：改善、発展、統合、他プロジェクトへの横展開
2. **Impact scope checks** — related files or documents that may need updating / **影響範囲チェック** — 更新が必要な関連ファイルやドキュメント
3. **Formal checks** — uncommitted changes, etc. / **形式的チェック** — 未コミットの変更など

The key: suggestions are informed by accumulated knowledge. The more knowledge exists, the more relevant and specific the suggestions become.

ポイント：提案は蓄積された知識に基づく。知識が増えるほど、提案はより的確で具体的になる。

### Plan & Decide — 計画と判断

This is where you decide what to work on. Use Claude Code's plan mode or simply discuss and decide. This is not a Kaizen-CLI-specific step — it's your normal decision-making process.

何に取り組むかを決めるフェーズ。Claude Codeのplanモードを使うか、単に議論して決める。Kaizen-CLI固有のステップではなく、通常の意思決定プロセスそのもの。

### Execute — 実行（＝あなたの実務）

This is **your actual work**. Build features, fix bugs, run analyses, write code. There is nothing special about this step from a Kaizen-CLI perspective — you simply do your job. Skills may auto-invoke during execution to provide guard rails (e.g., `kaizen-editing-knowledge` activates when editing `knowledge/` files).

これが**あなたの実務そのもの**だ。機能の実装、バグ修正、データ分析、コードの記述。Kaizen-CLIの観点からこのステップに特別なことはない — 普段の仕事をするだけ。実行中にスキルが自動発動してガードレールを提供することはある（例：`knowledge/` ファイルの編集時に `kaizen-editing-knowledge` が発動）。

### Reflect — 知見の反映

`/kaizen-reflect-learning` is where friction becomes knowledge. At the end of a work session, it analyzes the session history and extracts learnings:

`/kaizen-reflect-learning` は引っかかりが知識に変わるフェーズだ。作業セッションの終わりに、セッション履歴を分析して学びを抽出する：

| What it captures / 抽出対象 | Example / 例 |
|---|---|
| **Failure → success patterns** | Tried approach A, failed, approach B worked / Aで失敗、Bで成功 |
| **Implicit rules made explicit** | User corrected output → the underlying expectation is recorded / ユーザーが修正 → 背景の期待を記録 |
| **Technical misunderstandings** | Misused an API parameter → correct usage documented / APIパラメータの誤用 → 正しい使い方を記録 |
| **Search inefficiencies** | Took multiple tries to find something → the answer is now in knowledge/ / 複数回の検索 → 答えをknowledge/に追加 |
| **New domain knowledge** | First encounter with a tool or service → key facts recorded / 新しいツールとの初遭遇 → 要点を記録 |
| **Cross-project patterns** | A reusable approach identified → generalized and shared / 再利用可能なアプローチ → 汎用化して共有 |

A critical rule: **failures during the session are unconditionally captured**. If you hit an error and had to retry, that's exactly the kind of knowledge that prevents wasted time in the future. You don't need to judge whether it's "worth recording" — the fact that it caused friction is reason enough.

重要なルール：**セッション中の失敗は無条件で採用される**。エラーに遭遇してリトライが必要だったなら、それこそが将来の時間の浪費を防ぐ知識だ。「記録に値するか」を判断する必要はない — 引っかかりが生じた事実が、それだけで十分な理由になる。

## Why It Accelerates / なぜ加速するのか

The acceleration comes from compounding. Each cycle adds knowledge. Each piece of knowledge eliminates a future friction point.

加速は複利効果から生まれる。サイクルごとに知識が増える。知識の一つ一つが、将来の引っかかりを一つ消す。

Concretely:

具体的には：

- **No more repeated explanations**: Domain rules, coding conventions, and tool-specific quirks are already documented. Claude reads them before starting work. / **説明の繰り返しがなくなる**：ドメインルール、コーディング規約、ツール固有の癖がすでに記録されている。Claudeは作業開始前にそれを読む。
- **No more known pitfalls**: Past failures are recorded as "don't do X, do Y instead." The same mistake doesn't happen twice. / **既知の落とし穴がなくなる**：過去の失敗が「Xではなく、Yにすること」として記録される。同じ失敗は二度と起きない。
- **No more searching for answers you already found**: Information that required investigation is now directly accessible in `knowledge/`. / **すでに見つけた答えを再検索しなくて済む**：調査が必要だった情報が `knowledge/` から直接アクセスできる。
- **Cross-project leverage**: A lesson learned in project A is immediately available in project B, C, D... / **プロジェクト横断の活用**：プロジェクトAでの学びが、即座にプロジェクトB、C、D...で利用可能に。

The first cycle is the slowest. Every subsequent cycle is faster.

最初のサイクルが一番遅い。以降のサイクルは回を重ねるごとに速くなる。

## Knowledge Architecture / 知識のアーキテクチャ

Kaizen-CLI organizes knowledge into three layers, each with a distinct role:

Kaizen-CLIは知識を3つの層に整理する。それぞれ異なる役割を持つ：

| Layer / 層 | Role / 役割 | Mutability / 変更性 | Location / 配置 |
|---|---|---|---|
| **knowledge/** | Reference knowledge — facts, patterns, guidelines | Accumulates over time (reflect-learning writes here) / サイクルごとに蓄積 | Shared via symlink across all projects / symlink経由で全プロジェクト共有 |
| **skills/** | Procedural knowledge — how to perform specific tasks | Static (provided by kaizen-cli or user-created) / 静的 | Symlinked per project / プロジェクトごとにsymlink |
| **commands/** | Operations — user-invoked workflow actions | Static / 静的 | Copied to `~/.claude/commands/` / グローバルにコピー |

The key distinction: **only `knowledge/` accumulates**. Skills and commands are stable tools that operate on the growing knowledge base. This separation keeps the system predictable — you always know what changes (knowledge) and what doesn't (skills, commands).

重要な区別：**蓄積されるのは `knowledge/` のみ**。スキルとコマンドは、成長する知識ベースを操作する安定したツールだ。この分離がシステムを予測可能に保つ — 何が変わるか（knowledge）と何が変わらないか（skills、commands）が常に明確。

### The Symlink Model / Symlinkモデル

```
$KAIZEN_KNOWLEDGE_DIR/          ← shared knowledge (the single source)
  meta/                         ← guidelines, indexes
  projects/                     ← project registry
  (domain-specific dirs)        ← accumulated knowledge

project-A/knowledge/ ──symlink──▶ $KAIZEN_KNOWLEDGE_DIR/
project-B/knowledge/ ──symlink──▶ $KAIZEN_KNOWLEDGE_DIR/
project-C/knowledge/ ──symlink──▶ $KAIZEN_KNOWLEDGE_DIR/
```

All projects share the same physical knowledge directory. A lesson captured in project A is instantly available in projects B and C. No sync, no copy, no merge conflicts.

すべてのプロジェクトが同一の物理的な知識ディレクトリを共有する。プロジェクトAで捉えた学びは、プロジェクトBとCで即座に利用可能。同期不要、コピー不要、マージコンフリクトなし。

## Who Is This For? / 対象ユーザー

### Ideal fit / 最適なユーザー

- **Individuals juggling multiple small projects**: The more projects you switch between, the more value cross-project knowledge provides. / **小規模プロジェクトを多数こなす個人**：プロジェクトを切り替えるほど、横断知識の価値が高まる。
- **Claude Code users frustrated by session amnesia**: You know the feeling — explaining the same constraints for the third time. / **セッションの記憶喪失にフラストレーションを感じているClaude Codeユーザー**：同じ制約を三度目に説明するあの感覚。
- **Practitioners who want improvement without extra process**: If you've tried and abandoned separate "lessons learned" practices, this approach — capturing friction as it happens — may stick where others didn't. / **余計なプロセスなしで改善したい実務者**：「振り返り」を別プロセスとして試して挫折した経験があるなら、引っかかりをその場で捉えるこのアプローチは続くかもしれない。

### Not a fit / 向かない場合

- **Single long-running project with no cross-project needs**: The symlink model's value comes from sharing. A single project can still benefit from session-to-session knowledge persistence, but the ROI is lower. / **プロジェクト横断の必要がない単一の長期プロジェクト**：symlinkモデルの価値は共有にある。セッション間の知識永続化だけでも恩恵はあるが、費用対効果は低い。
- **Teams not using Claude Code**: Kaizen-CLI is built on Claude Code's skills and commands infrastructure. / **Claude Codeを使っていないチーム**：Kaizen-CLIはClaude Codeのskills/commands基盤の上に構築されている。

## Further Reading / 関連ドキュメント

- [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md) — Design principles: SSOT, file size management, auto-invocation patterns / 設計原則：SSOT、ファイルサイズ管理、自動発動パターン
- [QUICKSTART.md](QUICKSTART.md) — Get started in 5 minutes / 5分で始める
- [CUSTOMIZATION.md](CUSTOMIZATION.md) — Adapt for your domain / 自分のドメインに適用する
