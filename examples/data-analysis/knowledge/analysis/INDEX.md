# データ分析ガイド - 逆引きリファレンス

分析ナレッジの入口。「やりたいこと」から参照先を引くタスクディスパッチャー。

**⚠️ 重要**: プロジェクト横断の汎用ファイル（プロジェクト固有の内容は禁止）

---

## やりたいことから探す

### クイックスタート

| やりたいこと | 参照先 |
|------------|-------|
| **すぐに使えるコードが欲しい** | **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** |
| **よくある失敗を避けたい** | **[PITFALLS.md](./PITFALLS.md)** |
| 分析計画を立てたい | [planning-analysis skill](../../.claude/skills/planning-analysis/SKILL.md) |

### データ前処理

| やりたいこと | 参照先 |
|------------|-------|
| 欠損値・外れ値を処理したい | [QUICK_REFERENCE.md § データ前処理](./QUICK_REFERENCE.md#データ前処理) |
| フィルタ条件を設計したい | [QUICK_REFERENCE.md § フィルタ条件](./QUICK_REFERENCE.md#フィルタ条件設計) |
| ゼロ値データの除外判断をしたい | [PITFALLS.md § 1.1](./PITFALLS.md#11-ゼロ値データの混入) |
| カラムの意味を取り違えたくない | [PITFALLS.md § 1.2](./PITFALLS.md#12-データカラムの正確な理解) |
| データ型の問題を避けたい | [PITFALLS.md § 1.3](./PITFALLS.md#13-データ型の事前確認) |

### 分析実行

| やりたいこと | 参照先 |
|------------|-------|
| 相関分析のコードが欲しい | [QUICK_REFERENCE.md § 相関分析](./QUICK_REFERENCE.md#相関分析チェック) |
| セグメント別に比較したい | [QUICK_REFERENCE.md § セグメント別分析](./QUICK_REFERENCE.md#セグメント別分析) |
| 相関分析で失敗したくない | [PITFALLS.md § 2.1](./PITFALLS.md#21-相関分析の落とし穴) |
| 残差分析で隠れた洞察を得たい | [PITFALLS.md § 2.2](./PITFALLS.md#22-残差分析の重要性) |
| YoY分析の期間効果を避けたい | [PITFALLS.md § 2.3](./PITFALLS.md#23-分析期間の左端効果yoy分析) |
| 分子・分母の整合性を確認したい | [PITFALLS.md § 3.1](./PITFALLS.md#31-セグメント別指標の分子分母の整合性) |

### 統計チェック

| やりたいこと | 参照先 |
|------------|-------|
| ベースラインの安定性を検証したい | [PITFALLS.md § 3.2](./PITFALLS.md#32-ベースラインの安定性検証) |
| サンプルサイズと評価期間を決めたい | [PITFALLS.md § 3.3](./PITFALLS.md#33-サンプルサイズと評価期間) |
| 基礎統計量を確認したい | [QUICK_REFERENCE.md § 統計チェック](./QUICK_REFERENCE.md#統計チェック) |

### 可視化

| やりたいこと | 参照先 |
|------------|-------|
| グラフ種類を選びたい | [PITFALLS.md § 4.1](./PITFALLS.md#41-グラフ種類の選択) |
| 箱ひげ図が適切か判断したい | [PITFALLS.md § 4.2](./PITFALLS.md#42-箱ひげ図が不適切なケース) |

### 計画立案・仮説設計

| やりたいこと | 参照先 |
|------------|-------|
| 分析計画を立てたい | [planning-analysis skill](../../.claude/skills/planning-analysis/SKILL.md) |
| 仮説を構造化したい | [planning-analysis skill](../../.claude/skills/planning-analysis/SKILL.md) |
| 反証仮説を設定したい | [planning-analysis skill](../../.claude/skills/planning-analysis/SKILL.md) |

---

## 場面別チェックリスト

| タイミング | 確認項目 | 参照先 |
|----------|---------|--------|
| **計画立案時** | 仮説設計・反証仮説・成功基準定義 | [planning-analysis skill](../../.claude/skills/planning-analysis/SKILL.md) |
| **データ取得後** | ゼロ値割合、カラム意味、データ型確認 | [PITFALLS.md § 1](./PITFALLS.md#1-データ前処理の落とし穴) |
| **分析実行中** | 相関0.9以上で多重共線性確認 | [PITFALLS.md § 2.1](./PITFALLS.md#21-相関分析の落とし穴) |
| | セグメント別分析の分子・分母整合性 | [PITFALLS.md § 3.1](./PITFALLS.md#31-セグメント別指標の分子分母の整合性) |
| | ベースライン安定性（CV確認） | [PITFALLS.md § 3.2](./PITFALLS.md#32-ベースラインの安定性検証) |
| **結論導出前** | 反証仮説の検討、不確実性の明示 | [planning-analysis skill](../../.claude/skills/planning-analysis/SKILL.md) |

---

## ファイル一覧

| ファイル | 概要 | 行数 |
|---------|-----|-----|
| **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** | **データ前処理・統計チェック・分析パターンのコード集** | ~200行 |
| [PITFALLS.md](./PITFALLS.md) | データ前処理・統計分析の落とし穴と対策 | ~170行 |

### 関連スキル

| スキル | 概要 |
|-------|-----|
| [planning-analysis](../../.claude/skills/planning-analysis/SKILL.md) | 分析計画立案・仮説設計の構造化 |

---

## カスタマイズのヒント

このファイルはサンプルです。自分のドメインに合わせて以下を追加してください:

- ドメイン固有の前処理パターン（例: 営業時間外データ除外、返品処理）
- 業務特有の分析パターン（例: ROI計算、キャンペーン効果測定）
- よく使うデータソースへのアクセス方法
- ドメイン固有のチェックリスト項目
