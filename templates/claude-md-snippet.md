
## Multi-Agent Framework v2

このプロジェクトはマルチエージェントフレームワーク v2 を使用しています。

### ロール一覧

| ロール | 担当 | subagent_type |
|--------|------|---------------|
| Secretary | ボスIF、要件定義、ドキュメント作成 | general-purpose |
| Manager | タスク分解・管理、進捗管理 | general-purpose |
| Developer | コード実装、PR作成 | general-purpose |
| Tester | テスト実行、バグ報告、品質保証 | general-purpose |
| Designer | UI/UXレビュー（Read-only） | Explore |
| Researcher | 調査・分析（Read-only） | Explore |

### エージェント起動

チームで作業する場合:
1. `TeamCreate` でチームを作成
2. 各ロールのエージェントファイル（`.claude/agents/*.md`）を読んでpromptに含める
3. `Task` ツールで各エージェントをspawn

### ドメイン知識

- `.multi-agent/knowledge/domain.md` - プロジェクト固有のドメイン知識
- `.multi-agent/knowledge/learnings.md` - 蓄積された学習

### Compaction復旧

コンテキスト圧縮時は `.claude/hooks/compact-recovery.sh` が自動実行されます。
環境変数 `MULTI_AGENT_ROLE` でロールを識別します。
