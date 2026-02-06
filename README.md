# Multi-Agent Framework v2

複数のClaude Codeインスタンスを協調させて開発を行うフレームワーク。
Claude Agent Teams（TeamCreate/SendMessage/TaskTools）と統合し、どのプロジェクトでも `ma init` 一発で使える。

## キャラクター（攻殻機動隊 S.A.C テーマ）

| ロール | キャラクター | 担当 | subagent_type |
|--------|------------|------|---------------|
| Manager | バトー | 要件整理、タスク分解・管理、進捗管理、スキル化 | general-purpose |
| Developer | タチコマ | コード実装、PR作成 | general-purpose |
| Tester | タチコマ（慎重型） | テスト実行、バグ報告、品質保証 | general-purpose |
| Designer | タチコマ（美意識型） | UI/UXレビュー（Read-only） | Explore |
| Researcher | タチコマ（分析型） | 調査・分析（Read-only） | Explore |

> Secretary（少佐）も定義されていますが、デフォルトでは無効。Manager が要件整理・ドキュメント化も担当します。

## クイックスタート

### 1. インストール

```bash
# PATHにmaコマンドを追加
export PATH="$HOME/dev/multi-agent/scripts:$PATH"
```

### 2. プロジェクト初期化

```bash
ma init ~/dev/my-project
```

これで以下が自動生成されます：

```
my-project/
├── .claude/
│   ├── agents/           # ロール別エージェントファイル
│   │   ├── manager.md
│   │   ├── developer.md
│   │   ├── tester.md
│   │   └── designer.md
│   └── hooks/
│       └── compact-recovery.sh
├── .multi-agent/
│   ├── config.yaml       # プロジェクト設定
│   └── knowledge/
│       ├── domain.md     # ドメイン知識
│       └── learnings.md  # 蓄積学習
└── CLAUDE.md             # マルチエージェントセクション追記
```

### 3. 設定カスタマイズ

```bash
# ロールの有効/無効化、キャラ設定のカスタマイズ
vim my-project/.multi-agent/config.yaml

# プロジェクトのドメイン知識を記載
vim my-project/.multi-agent/knowledge/domain.md
```

### 4. セッション開始

```bash
ma session ~/dev/my-project
```

tmux セッションが起動し、バトー（Manager）がリードロールとして Claude Code で立ち上がります。

## CLI コマンド

| コマンド | 説明 |
|---------|------|
| `ma init [dir]` | プロジェクトにマルチエージェント環境を構築 |
| `ma session [dir]` | tmuxセッションを開始（リードロール付き） |
| `ma roles` | 利用可能なロール一覧 |
| `ma status` | プロジェクトの状態確認 |
| `ma help` | ヘルプ表示 |

## ディレクトリ構造

```
multi-agent/                      # フレームワーク本体
├── roles/                        # ロールテンプレート（汎用）
│   ├── _base.md                  #   共通プリアンブル
│   ├── secretary.md              #   秘書（デフォルト無効）
│   ├── manager.md                #   マネージャー
│   ├── developer.md              #   開発
│   ├── tester.md                 #   テスター
│   ├── designer.md               #   デザイナー
│   └── researcher.md             #   リサーチャー
├── templates/                    # 初期化テンプレート
│   ├── project-config.yaml       #   config.yaml テンプレート
│   ├── hooks/
│   │   └── compact-recovery.sh   #   compaction復旧フック
│   └── claude-md-snippet.md      #   CLAUDE.md追記用スニペット
├── scripts/                      # CLIスクリプト
│   ├── ma                        #   メインディスパッチャ
│   ├── ma-init                   #   プロジェクト初期化
│   ├── ma-session                #   セッション開始
│   ├── ma-roles                  #   ロール一覧
│   └── lib/
│       ├── common.sh             #   共有ユーティリティ
│       └── render.sh             #   テンプレートレンダリング
└── docs/                         # 運用ドキュメント
    ├── best-practices.md         #   ベストプラクティス
    └── pr-checklist.md           #   PRチェックリスト
```

## アーキテクチャ（Aパターン）

```
roles/*.md（テンプレートDB）
    ↓ ma init（render.sh でレンダリング）
.claude/agents/*.md（YAMLフロントマター + _base.md + role.md）
    ↓ Team Lead が spawn 時に Read → prompt に埋め込み
Task tool（subagent_type に応じた agent を起動）
```

- `roles/*.md` は `{{PLACEHOLDER}}` を含む汎用テンプレート
- `ma init` で `_base.md + role.md` を結合し `.claude/agents/<role>.md` を生成
- Team leadがspawn時にファイルを読んでpromptに埋め込む
- ツール制限はYAMLフロントマター（disallowedTools）+ subagent_type使い分け

## ワークフロー

```
1. ユーザー（少佐） + Manager（バトー）: 要件定義・設計
   └─> バトーが要件を整理・タスク分解

2. Manager: タスク分解・割り振り
   └─> TaskCreate / TaskUpdate

3. Developer（タチコマ）: 実装
   └─> TaskUpdate で進捗報告 + SendMessage

4. Tester（タチコマ慎重型）: テスト
   └─> バグ報告は SendMessage

5. Manager → ユーザー: 完了報告
```

## 成長ループ

プロジェクトごとにナレッジとスキルが蓄積され、チームが成長します。

```
セッション開始
  └─> learnings.md を確認（前回の学び・パターン）
  └─> 作業実施
  └─> セッション終了時
       ├─> learnings.md に学びを記録
       ├─> 2回以上繰り返したパターン → スキル化候補
       └─> 承認されたら .claude/skills/ にスキル作成
```

## カスタマイズ

### ロールの有効/無効化

`.multi-agent/config.yaml` で設定：

```yaml
roles:
  manager:
    enabled: true
  developer:
    enabled: true
    instances: 2  # dev1, dev2
  tester:
    enabled: true
  designer:
    enabled: false  # 不要なら無効化
```

### リードロールの変更

```yaml
lead_role: manager  # secretary に変更可能
```

### キャラクターのカスタマイズ

デフォルトは攻殻機動隊S.A.Cテーマ。`config.yaml` でオーバーライド可能。
