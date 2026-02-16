# 分析クイックリファレンス

よく使う分析パターンをコピペ可能な形で提供。背景・理論は [PITFALLS.md](./PITFALLS.md) を参照。

**⚠️ 重要**: プロジェクト横断の汎用ファイル（プロジェクト固有の内容は禁止）

---

## データ前処理

### 欠損値処理

```r
# 欠損率の確認
colSums(is.na(df)) / nrow(df) * 100

# 欠損パターンの確認（どの列の組み合わせで欠損が多いか）
df %>%
  summarise(across(everything(), ~sum(is.na(.)) / n() * 100)) %>%
  pivot_longer(everything(), names_to = "column", values_to = "missing_pct") %>%
  filter(missing_pct > 0) %>%
  arrange(desc(missing_pct))
```

### 外れ値処理

```r
# IQR法による外れ値検出
detect_outliers <- function(x) {
  q1 <- quantile(x, 0.25, na.rm = TRUE)
  q3 <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  x < (q1 - 1.5 * iqr) | x > (q3 + 1.5 * iqr)
}

# 外れ値の割合確認
sum(detect_outliers(df$metric)) / length(df$metric) * 100
```

### フィルタ条件設計

```r
# ゼロ値の割合確認（除外判断の材料）
sum(df$metric == 0, na.rm = TRUE) / nrow(df) * 100

# 基本パターン: 非稼働データの除外
df %>% filter(metric > 0)

# 複合条件
df %>% filter(metric > 0 & status == "active")
```

> 詳細: [PITFALLS.md § 1.1](./PITFALLS.md#11-ゼロ値データの混入)

### 期間設定

```r
# 特定期間
df %>% filter(date >= as.Date("2025-01-01"), date < as.Date("2026-01-01"))

# 平日のみ（月-金）
df %>% filter(wday(date) %in% 2:6)

# 月次フィルタ
df %>% filter(month(date) %in% c(4, 5, 6))
```

```sql
-- SQL版
WHERE date >= DATE '2025-01-01' AND date < DATE '2026-01-01'
  AND EXTRACT(DOW FROM date) BETWEEN 1 AND 5
```

### データ型確認

```r
# 構造確認（文字列か数値か）
str(df)

# Excel読み込み: 全列を文字列として読み込み後変換
df <- read_excel("file.xlsx", col_types = "text")
df <- df %>%
  mutate(
    date_col = as.Date(as.numeric(date_col), origin = "1899-12-30"),
    num_col = as.numeric(num_col)
  )
```

> 詳細: [PITFALLS.md § 1.3](./PITFALLS.md#13-データ型の事前確認)

---

## 統計チェック

### データ分布確認

```r
summary(df$metric)                              # 分布統計
sum(df$metric == 0, na.rm = TRUE) / nrow(df)    # 0の割合
table(df$metric[df$metric < 0])                 # 負の値確認
```

### ベースライン安定性

```r
# CV（変動係数）で安定性確認
baseline_cv <- function(data, value_col) {
  vals <- data[[value_col]]
  cv <- sd(vals, na.rm = TRUE) / mean(vals, na.rm = TRUE) * 100
  list(
    cv = round(cv, 1),
    recommendation = case_when(
      cv < 15 ~ "日次評価可",
      cv < 30 ~ "週次評価推奨",
      TRUE ~ "月次評価推奨"
    )
  )
}

baseline_check <- baseline_cv(data, "daily_metric")
if(baseline_check$cv > 20) {
  warning("ベースライン不安定 (CV=", baseline_check$cv, "%). 期間再検討推奨")
}
```

> 詳細: [PITFALLS.md § 3.2](./PITFALLS.md#32-ベースラインの安定性検証)

### 相関分析チェック

```r
# 高相関ペア検出
cor_matrix <- cor(data[, numeric_cols], use = "complete.obs")
high_cor <- which(abs(cor_matrix) > 0.9 & cor_matrix != 1, arr.ind = TRUE)

if(nrow(high_cor) > 0) {
  warning("高相関ペア検出:")
  print(data.frame(
    var1 = rownames(cor_matrix)[high_cor[,1]],
    var2 = colnames(cor_matrix)[high_cor[,2]],
    cor = cor_matrix[high_cor]
  ))
}

# 多重共線性チェック（VIF）
# library(car)
# vif(model)  # 5以上で注意、10以上で除外検討
```

> 詳細: [PITFALLS.md § 2.1](./PITFALLS.md#21-相関分析の落とし穴)

---

## 分析パターン

### セグメント別分析

```r
# セグメント別指標の計算（分子・分母の整合性に注意）
segment_summary <- data %>%
  group_by(segment) %>%
  summarise(
    total = n_distinct(id),
    target = n_distinct(id[condition]),
    rate = target / total * 100,
    .groups = "drop"
  )
```

> 詳細: [PITFALLS.md § 3.1](./PITFALLS.md#31-セグメント別指標の分子分母の整合性)

### 残差分析

```r
model <- lm(outcome ~ predictor1 + predictor2, data = df)

df <- df %>%
  mutate(
    predicted = predict(model, .),
    residual = outcome - predicted,
    performance = case_when(
      residual > 0 ~ "期待超え",
      residual < 0 ~ "期待未達",
      TRUE ~ "期待通り"
    )
  )

# 残差でランキング
df %>% arrange(desc(residual))
```

> 詳細: [PITFALLS.md § 2.2](./PITFALLS.md#22-残差分析の重要性)

### 時系列集計レベル判定

```r
# セグメント別の推奨集計レベル
segment_cv <- data %>%
  group_by(segment, date) %>%
  summarise(daily_value = sum(metric), .groups = "drop") %>%
  group_by(segment) %>%
  summarise(
    cv = sd(daily_value) / mean(daily_value) * 100,
    recommendation = case_when(
      cv < 15 ~ "日次分析可",
      cv < 30 ~ "週次分析推奨",
      TRUE ~ "月次分析推奨"
    ),
    .groups = "drop"
  )
```

> 詳細: [PITFALLS.md § 3.3](./PITFALLS.md#33-サンプルサイズと評価期間)

---

## カスタマイズのヒント

このファイルはサンプルです。自分のドメインに合わせて以下を追加してください:

- ドメイン固有の前処理コード（例: 営業時間外除外、返品処理、異常値の業務ルール）
- よく使う集計パターン（例: ROI計算、コホート分析、ファネル分析）
- データソース別のアクセスコード（例: Athena/BigQuery接続、API取得）
- テンプレート逆引き（プロジェクト初期化で生成するテンプレート一覧）
