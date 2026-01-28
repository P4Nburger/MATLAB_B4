# MATLAB_B4

音波駆動型拡張メタマテリアル構造の解析コードリポジトリ

## 概要

snap-through snap-back buckling を利用した周期ユニット構造の設計・解析を行うための MATLAB コード群です。初期たわみ条件の計算と拡張可能条件の判定を行います。

---

## フォルダ構成

### 📂 `syokitawami/`
**初期たわみ条件を求めるコード群**

初期たわみ量とスナップスルー境界条件の関係を解析します。

- **`current/`**: 最新版コード（実行推奨）
- **`archive/`**: 過去バージョン・実験的コード

#### 主要スクリプト（current/）
| ファイル名 | 説明 |
|-----------|------|
| `kotei_LikoruS_danmen.m` | 固定リコルス断面の初期たわみ計算コード |

---

### 📂 `kakutyoukanoujouken/`
**拡張可能条件を判定するコード群**

スナップスルー可能な設計空間を探索・可視化します。

- **`current/`**: 最新版コード（実行推奨）
  - **`グラフ作り/`**: 結果可視化用スクリプト
- **`archive/`**: 過去バージョン・実験的コード

#### 基本解析スクリプト（current/）
| ファイル名 | 説明 |
|-----------|------|
| `gouseihenkou.m` | 基本のコード(必要最低限の機能) |
#### 機能追加版解析スクリプト（current/グラフ作り/）
| ファイル名 | 説明 |
|-----------|------|
| `scan.m` | gouseihenkou.mの最適化版（⭐️こっちをめちゃくちゃ推奨，早いし正確） |
| `untitled_optimized.m` | スナップスルー可能な押し込み量の自動探索 |
| `untitled.m` | 上記のプロトタイプ版，基本はoptimizedを推奨|


---

## 使い方

### 1. 初期たわみ条件の計算
```matlab
cd syokitawami/current/
kotei_LikoruS_danmen  % 実行
```

### 2. 拡張可能条件の探索
```matlab
cd kakutyoukanoujouken/current/
scan  % 基本解析実行
```

### 3. 拡張可能な初期たわみ量の詳細な探索
```matlab
cd kakutyoukanoujouken/current/グラフ作り/
untitled_optimized  % 推奨（高速）

```

---

## 環境

- **MATLAB**: R2025bを推奨(筆者の環境)
- **必須 Toolbox**: 
  - Optimization Toolbox
- **推奨 Toolbox**:
  - Parallel Computing Toolbox（並列計算によりコードが爆速になります，必須級，てかこれないと遅い)

---

## 注意事項

- `current/` フォルダ内が最新版です。`archive/` は参考・バックアップ用です。
- 基本的には並列計算環境の利用を推奨します。

---

## 更新履歴

- **2026/1/1**: 初期バージョン作成
- **2026/1/29**: コード追加　ファイル整理、README 修正

---

## Author

P4Nburger  
Meiji University - Meterial System Lab
