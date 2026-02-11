# Phase 0: 機密情報スキャンレポート

**スキャン日**: 2026-02-11
**対象リポジトリ**: 00_dsci_common (社内版)
**スキャン対象**: 全119ファイル

---

## 即時対応が必要な項目

### CRITICAL: APIキーの平文露出

`ai-skills/troubleshooting-lambda/INVESTIGATION.md` の158行目・162行目に**実際のAPIキー値**が平文で記載されている。

```
# 出力例: Dz9TfuvMpf1e1Van8lzZnaF7oaczoaFS3SfoAzoF
-H "x-api-key: Dz9TfuvMpf1e1Van8lzZnaF7oaczoaFS3SfoAzoF"
```

**対応**: OSS公開とは無関係に、このキーを即座にローテーションすること。

---

## サマリー

| リスクレベル | 件数 | 説明 |
|-------------|------|------|
| **CRITICAL** | 2 | APIキー平文露出 |
| **HIGH** | 38 | AWSアカウントID、個人S3パス、メールアドレス、内部IPアドレス、API Gatewayエンドポイント |
| **MEDIUM** | 52 | `$USJ_DSCI_COMMON_DIR`環境変数、内部バケット名、CodeCommit参照、`usj-utils`レイヤー名 |
| **LOW** | 28 | `/usj-`コマンド接頭辞、`init-usj`スキル名、社内チーム名 |
| **合計** | **120** | 62ファイルに発見（57ファイルは問題なし） |

---

## 完全除外すべきファイル（OSS不可）

| ファイル | 理由 | 行数 |
|---------|------|------|
| `ai-context/context/meta/WORKPLACE_CONTEXT.md` | 組織構造・ビジネス用語の固まり | 534 |
| `ai-context/context/foundation/AWS_RESOURCES.md` | 実AWSリソースカタログ（アカウントID含む） | 343 |
| `ai-context/context/foundation/DATA_ARCHITECTURE.md` | 実データアーキテクチャ（S3パス含む） | 565 |
| `ai-projects/` ディレクトリ全体（~30ファイル） | APIキー、IP、メール、エンドポイント等 | ~3000+ |

---

## そのまま公開可能なファイル（変更不要）

57ファイルは機密情報を含まず、そのまま利用可能:

- `ai-context/context/analysis/ANALYTICAL_THINKING.md` (473行)
- `ai-context/context/analysis/PITFALLS.md` (479行)
- `ai-context/context/analysis/QUICK_REFERENCE.md` (352行)
- `ai-context/context/analysis/INDEX.md` (128行)
- `ai-context/context/analysis/templates/` (全6ファイル)
- `ai-context/context/aws_services/BEDROCK.md` (359行)
- `ai-context/context/aws_services/IAM_GUIDE.md` (243行)
- `ai-context/context/aws_services/S3_TABLES_GUIDE.md` (464行)
- `ai-context/context/aws_services/lambda_development/ARCHITECTURE.md` (413行)
- `ai-context/context/external_services/SEC_EDGAR.md` (63行)
- `ai-context/context/m365/POWER_AUTOMATE.md` (197行)
- `ai-skills/writing-analysis-report/` (全7ファイル)
- `ai-template/` (13ファイル中12ファイル)
- `development_policy.md` (26行)

---

## 系統的置換が必要な項目（頻度順）

| 検索文字列 | 置換先 | 出現数 | 対象ファイル数 |
|-----------|--------|--------|-------------|
| `$USJ_DSCI_COMMON_DIR` | `$KAIZEN_SHARED_DIR` | ~50 | 20+ |
| `849332783732` (AWSアカウントID) | `123456789012` | ~30 | ARN含むファイル群 |
| `/usj-` コマンド接頭辞 | 接頭辞除去 | ~25 | 全コマンドファイル |
| `init-usj` | `init-project` | ~8 | スキル・コマンド参照 |
| `lake-general`, `lake-teams-ai` 等 | `my-bucket`, `example-bucket` | ~15 | 例示・テストデータ |
| `00_dsci_common` | 汎用リポジトリ参照 | ~12 | リンクコマンド、スキル |
| `usj-utils` | `shared-utils` | ~8 | Lambda関連ドキュメント |
| `CodeCommit` 参照 | 汎用git参照 | ~12 | リンクコマンド、Getting Started |
| `opd-analyst` | `default-profile` | ~2 | テンプレート |
| `データサイエンスチーム` | 汎用チーム名 | ~4 | フッター |
| `street.se_count_merged` | `mydb.example_table` | ~5 | DATA_QUALITY.md |

---

## ファイル別詳細

### ai-commands/

#### usj-context-push-s3.md / usj-context-pull-s3.md
- **HIGH**: `s3://opd-analyst-freeuse/fukumoto/ai-context/` — 個人名+内部S3パス (各3箇所)
- **対応**: 完全書き換えまたはOSSでは除外（S3バックアップは汎用フレームワークの範囲外）

#### usj-commands-link.md / usj-context-link.md / usj-skills-link.md
- **MEDIUM**: `$USJ_DSCI_COMMON_DIR`、`codecommit::ap-northeast-1://00_dsci_common` (各複数箇所)
- **対応**: 環境変数名とgit参照を汎用化

#### usj-shared-commit.md / usj-shared-pull.md
- **MEDIUM**: `$USJ_DSCI_COMMON_DIR`、`CodeCommit`参照
- **対応**: 環境変数名とgit参照を汎用化

#### usj-reflect-learning.md
- **LOW**: タイトルに`USJ`、本文に`$USJ_DSCI_COMMON_DIR`
- **対応**: 系統的置換で対応可能

#### usj-update-docs.md
- **MEDIUM**: `$USJ_DSCI_COMMON_DIR/ai-projects/` 参照 (複数箇所)
- **対応**: ai-projects連携を汎用化

#### usj-suggest-next.md
- **LOW**: `/usj-`接頭辞のコマンド参照 (複数箇所)
- **対応**: 接頭辞除去

### ai-context/context/meta/

#### INDEX.md
- **MEDIUM**: WORKPLACE_CONTEXT.md（除外ファイル）への参照
- **対応**: 除外ファイルへの参照を削除

#### GETTING_STARTED.md
- **MEDIUM**: CodeCommit参照、`$USJ_DSCI_COMMON_DIR`、FDMD業務用語
- **対応**: テンプレート化して汎用版に書き換え

#### DOCUMENTATION_GUIDELINES.md
- **LOW**: `/usj-update-docs`、CodeCommit参照
- **対応**: 軽微な置換で対応可能

#### PROJECT_REGISTRY.md
- **MEDIUM**: `$USJ_DSCI_COMMON_DIR` (6箇所)、`init-usj`
- **対応**: 系統的置換で対応可能

#### SLASH_COMMANDS_DESIGN.md
- **LOW**: `/usj-`コマンド名、`init-usj`、`データサイエンスチーム`
- **対応**: 系統的置換で対応可能

### ai-context/context/analysis/

#### CAMPAIGN.md
- **LOW**: "Power Up Band" ビジネス用語 (5箇所)
- **対応**: 汎用的なキャンペーン例に置換

#### PROJECT_SETTINGS.md
- **MEDIUM**: `s3://aws-athena-query-results-usjopp/ai_use/` (5箇所)、`opd-analyst`プロファイル
- **対応**: プレースホルダに置換

### ai-context/context/aws_services/

#### DATA_QUALITY.md
- **MEDIUM**: `street.se_count_merged` 内部テーブル名 (10+箇所)、内部カラム名
- **対応**: 汎用テーブル・カラム名に置換

#### GLUE_CATALOG_GUIDE.md
- **LOW**: `bm_analyst, opd_analyst` IAMグループ名、`データサイエンスチーム`
- **対応**: 汎用名に置換

#### lambda_development/INDEX.md
- **MEDIUM**: `usj-utils Layer` (2箇所)
- **対応**: `shared-utils`に置換

#### lambda_development/PROJECT_STRUCTURE.md
- **MEDIUM**: `$USJ_DSCI_COMMON_DIR`、`init-usj lambda`、`fdmdflash-daily` Lambda名
- **対応**: 系統的置換+Lambda名を汎用化

#### lambda_development/CODING.md
- **HIGH**: `849332783732` AWSアカウントID (4箇所)、`lake-general`バケット名
- **対応**: プレースホルダに置換

#### lambda_development/ENVIRONMENT_VARIABLES.md
- **HIGH**: `849332783732` (2箇所)、内部バケット名 (2箇所)
- **対応**: プレースホルダに置換

#### lambda_development/LAYER_DEVELOPMENT.md
- **MEDIUM**: `usj-utils` (~20箇所)
- **対応**: 一括置換で対応可能

### ai-skills/

#### init-usj/ (全ファイル)
- **MEDIUM**: `init-usj`名、`$USJ_DSCI_COMMON_DIR` (scripts/common.sh だけで15箇所)
- **対応**: スキル名変更+環境変数の系統的置換

#### committing-project/SKILL.md
- **MEDIUM**: `00_dsci_common`参照、`/usj-shared-commit` (5箇所)
- **対応**: 系統的置換で対応可能

#### editing-context/FILE_OPERATIONS.md
- **MEDIUM**: `00_dsci_common/ai-context`パス、`/usj-shared-commit`
- **対応**: 汎用パスに置換

#### testing-lambda/assets/env.json
- **HIGH**: `849332783732` AWSアカウントID、`lake-teams-ai`バケット名
- **対応**: プレースホルダに置換

#### deploying-lambda/ (複数ファイル)
- **MEDIUM**: `$USJ_DSCI_COMMON_DIR` (6箇所)
- **HIGH**: `849332783732` (s3_notification.json)
- **対応**: 系統的置換

#### designing-lambda/references/
- **HIGH**: `849332783732` (3箇所)、`lake-general`バケット名
- **対応**: プレースホルダに置換

#### troubleshooting-lambda/INVESTIGATION.md
- **CRITICAL**: 実APIキー平文 (2箇所)
- **HIGH**: `849332783732`
- **対応**: APIキーローテーション必須。プレースホルダに置換

#### troubleshooting-lambda/SNS_CONTROL.md
- **HIGH**: `849332783732` (2箇所)
- **対応**: プレースホルダに置換

#### planning-analysis/SKILL.md
- **LOW**: `init-usj analysis` (2箇所)
- **対応**: スキル名置換

### ai-template/

#### analysis/PROJECT_SUMMARY.md.template
- **LOW**: `opd-analyst` プロファイル名 (1箇所)
- **対応**: 汎用プロファイル名に置換

### ai-projects/ (ディレクトリ全体)

**完全除外**。主な検出内容:
- `tomoya_fukumoto@usjc.co.jp` (個人メール)
- Power Automateウェブフック URL（署名パラメータ付き）
- API Gatewayエンドポイント（複数）
- `849332783732` AWSアカウントID（多数）
- 内部IPアドレス `10.0.142.240`
- VPC ID、サブネットID、セキュリティグループID

---

## 推奨アプローチ

**コピー＆墨消しではなく、選択的抽出＆書き換え**を推奨。

| Tier | 割合 | 説明 | 対応 |
|------|------|------|------|
| **A: そのまま利用可** | ~40% | 汎用的な方法論ファイル | コピーするだけ |
| **B: 系統的置換** | ~45% | 価値あるコンテンツに識別子が散在 | 上記の置換テーブルを適用 |
| **C: 完全除外** | ~15% | 機密ファイル（サニタイズ不可） | OSS対象外 |
