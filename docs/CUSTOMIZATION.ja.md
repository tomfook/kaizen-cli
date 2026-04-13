# カスタマイズガイド

Kaizen-CLI を自分のドメインに適用するためのガイド。

---

## 複数レジストリの管理

レジストリを使うと、異なる文脈（例: 職場と個人）で独立したナレッジベースを維持できます。

### 新しいレジストリの作成

最も簡単な方法は、`/kaizen-init-project` のレジストリ選択で存在しない名前を入力することです（推奨）:

```
利用可能なレジストリ: default
レジストリ [default]: work    ← まだ存在しない名前を入力
```

確認後、必要なテンプレートファイルとともに新しいレジストリが作成されます。

`setup.sh` 実行時に作成することもできます:

```
Registry name [default]: work
```

または手動で作成:

```bash
mkdir -p $KAIZEN_KNOWLEDGE_DIR/work
bash setup.sh   # テンプレートが新しいレジストリに展開される
```

### プロジェクトごとのレジストリ選択

`/kaizen-init-project` を実行すると、使用するレジストリの選択を求められます:

```
利用可能なレジストリ: default, work
レジストリ [default]: work
```

`knowledge/` のシンボリックリンクは選択したレジストリを指します。`/kaizen-reflect-learning` で蓄積される知識はすべてそのレジストリに入ります。

### ユースケース

| シナリオ | レジストリ構成 |
|---------|--------------|
| 個人の副業プロジェクト | `default` レジストリ |
| 企業開発 | `work` レジストリ（社内ナレッジベースから移行可能） |
| NDA付きクライアント業務 | クライアントごとに `client-x` レジストリ |
| ドメイン分離 | `data-analysis`、`web-dev` など |

### テンプレート言語

各レジストリにはテンプレート言語（`en` または `ja`）が `$REGISTRY_DIR/.lang` に保存されています。これにより、生成されるファイル（CLAUDE.md、PROJECT_SUMMARY.md、knowledgeテンプレート）の言語が決まります。

- 言語はレジストリ作成時に選択（デフォルト: `en`）
- `.lang` がない既存レジストリは `en` がデフォルト
- 言語は新規生成ファイルにのみ適用 — 展開済みのテンプレートは上書きされない

**言語を後から変更する場合**:

`.lang` ファイルを手動で編集できます:

```bash
echo "ja" > $KAIZEN_KNOWLEDGE_DIR/default/.lang
```

これは今後の `/kaizen-init-project` 実行時に生成されるファイル（CLAUDE.md、PROJECT_SUMMARY.md）にのみ影響します。レジストリ内の既存ファイル（knowledgeテンプレート、プロジェクトファイル）は変更・翻訳されません。

### 重要な注意点

- 各レジストリは完全に独立（meta/、projects/、ドメインファイル、言語設定が個別）
- プロジェクトは1つのレジストリにのみ属する（knowledge/ のsymlink先で決まる）
- レジストリは `$KAIZEN_KNOWLEDGE_DIR` のサブディレクトリにすぎない — 設定ファイルは不要
- プロジェクトがどのレジストリを使っているか確認するには: `ls -la knowledge/`

---

## 知識の3層構造

Kaizen-CLI はスコープに応じて情報を3層に整理します。層の詳細・具体例・教訓のライフサイクルについては [CONCEPT.ja.md § 知識の3つの層](./CONCEPT.ja.md#知識の3つの層) を参照してください。

**情報の振り分け基準**:

- 他のプロジェクトでも役立つか？ → `knowledge/`（`/kaizen-reflect-learning` で反映）
- このプロジェクト固有の教訓（失敗、制約、落とし穴）か？ → `docs/LEARNINGS.md`（`/kaizen-update-docs` で反映）
- プロジェクトの事実情報（設計、設定、計画）か？ → `CLAUDE.md` または `docs/`

---

## ドメイン知識の追加

Kaizen-CLI の価値の大部分は knowledge/ に蓄積される知識です。reflect-learning による自動蓄積に加えて、既に持っている知識を手動で追加することもできます。

### サブディレクトリの設計

knowledge/ にドメイン別のサブディレクトリを作成します。

```
$KAIZEN_KNOWLEDGE_DIR/default/
├── meta/                  ← Kaizen-CLI が提供（運用ガイドライン）
├── projects/              ← Kaizen-CLI が提供（プロジェクトレジストリ）
├── aws/                   ← 例: AWS関連の知識
│   ├── INDEX.md
│   ├── LAMBDA.md
│   └── S3.md
├── python/                ← 例: Python関連の知識
│   ├── INDEX.md
│   └── PATTERNS.md
└── data-analysis/         ← 例: データ分析の知識
    ├── INDEX.md
    └── QUICK_REFERENCE.md
```

**ポイント**:
- ディレクトリ名は英語小文字・ハイフン区切り
- 各ディレクトリに INDEX.md を配置（→ [DESIGN_PRINCIPLES.ja.md § INDEX逆引きパターン](./DESIGN_PRINCIPLES.ja.md#index-逆引きパターン)）
- `meta/` と `projects/` は Kaizen-CLI が使用するため、別の用途で上書きしない
- ドメインサブディレクトリはレジストリ内に作成する（例: `default/aws/`）。`$KAIZEN_KNOWLEDGE_DIR` 直下ではない

### ファイルの書き方

1. **プロジェクト固有情報を含めない**: knowledge/ は全プロジェクトで共有される。プロジェクト名、具体的なファイルパス、特定の数値目標は書かない
2. **一般化する**: 「プロジェクトXで学んだこと」ではなく「この技術/パターンの注意点」として記述
3. **SSOT を守る**: 同じ情報を複数ファイルに書かない。参照リンクで誘導する
4. **800行以内**: 超えそうなら精査 → 分割の順で対応

> 詳細ルール: `knowledge/meta/DOCUMENTATION_GUIDELINES.md`

### examples/ を参考にする

`kaizen-cli/examples/` にドメイン別のサンプルが用意されています。

| サンプル | 内容 |
|---------|------|
| `data-analysis/` | データ分析向けの knowledge/ と skills/ |
| `web-development/` | Web開発向けの knowledge/ と skills/ |

自分のドメインに合わせてカスタマイズするための参考資料として活用してください。

---

## スキル・コマンド拡張時の注意点

独自のスキルやコマンドを追加する際、Kaizen-CLI との共存で気をつけること:

- **Kaizen-CLI のファイルを直接編集しない**: `.claude/skills/` と `.claude/commands/` の kaizen- ファイルはシンボリックリンク。編集すると `$KAIZEN_CLI_DIR` 配下の配布元を汚染する。カスタマイズしたい場合はシンボリックリンクを解除してコピーを配置する
- **kaizen- プレフィックスを避ける**: 独自のスキル・コマンドには別のプレフィックスを使い、名前衝突を防ぐ
- **knowledge/ を参照する場合**: プロジェクトルート相対パス（`knowledge/path/to/FILE.md`）を使う。`../../../` のような相対パスはシンボリックリンク環境で壊れる
- **詳細知識はスキル内に書かない**: knowledge/ に置き、スキルからは参照リンクで誘導する（SSOT）

---

## 関連ドキュメント

- Kaizen-CLI の思想を理解する → [CONCEPT.ja.md](./CONCEPT.ja.md)
- 設計原則を知る → [DESIGN_PRINCIPLES.ja.md](./DESIGN_PRINCIPLES.ja.md)
- 実際に使い始める → [QUICKSTART.ja.md](./QUICKSTART.ja.md)
