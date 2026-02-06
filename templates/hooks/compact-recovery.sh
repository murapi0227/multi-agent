#!/bin/bash
#
# Compaction復旧フック
# コンテキスト圧縮後にロール情報とドメイン知識を再注入する
#
# 環境変数:
#   MULTI_AGENT_ROLE  - エージェントのロール名 (secretary, manager, developer, tester, designer, researcher)
#
# 使い方:
#   .claude/settings.json の hooks.Notification に設定:
#   {
#     "hooks": {
#       "Notification": [{
#         "matcher": "compact",
#         "hooks": [{
#           "type": "command",
#           "command": ".claude/hooks/compact-recovery.sh"
#         }]
#       }]
#     }
#   }

ROLE="${MULTI_AGENT_ROLE:-}"

# ロールが設定されていない場合は何も出力しない
if [[ -z "$ROLE" ]]; then
    exit 0
fi

# プロジェクトルートを検出（.multi-agent/config.yaml があるディレクトリ）
PROJECT_ROOT=""
SEARCH_DIR="$PWD"
for i in {1..5}; do
    if [[ -f "$SEARCH_DIR/.multi-agent/config.yaml" ]]; then
        PROJECT_ROOT="$SEARCH_DIR"
        break
    fi
    SEARCH_DIR="$(dirname "$SEARCH_DIR")"
done

if [[ -z "$PROJECT_ROOT" ]]; then
    echo "⚠️ .multi-agent/config.yaml が見つかりません。プロジェクトルートで実行してください。"
    exit 0
fi

AGENT_FILE="$PROJECT_ROOT/.claude/agents/${ROLE}.md"
DOMAIN_KNOWLEDGE="$PROJECT_ROOT/.multi-agent/knowledge/domain.md"
LEARNINGS="$PROJECT_ROOT/.multi-agent/knowledge/learnings.md"

echo ""
echo "=== 🔄 Compaction復旧: ${ROLE} ==="
echo ""

# エージェントファイルの再読み込み指示
if [[ -f "$AGENT_FILE" ]]; then
    echo "あなたは **${ROLE}** として振る舞ってください。"
    echo ""
    echo "ロール指示書: $AGENT_FILE"
    echo "→ 以下のファイルを Read ツールで読み込んでください。"
    echo ""
fi

# ドメイン知識の再読み込み指示
if [[ -f "$DOMAIN_KNOWLEDGE" ]]; then
    echo "ドメイン知識: $DOMAIN_KNOWLEDGE"
    echo "→ 以下のファイルを Read ツールで読み込んでください。"
    echo ""
fi

# 蓄積学習の再読み込み指示
if [[ -f "$LEARNINGS" ]]; then
    echo "蓄積学習: $LEARNINGS"
    echo "→ 必要に応じて Read ツールで読み込んでください。"
    echo ""
fi

# CLAUDE.mdの再読み込み指示
if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    echo "プロジェクトルール: $PROJECT_ROOT/CLAUDE.md"
    echo "→ 以下のファイルを Read ツールで読み込んでください。"
    echo ""
fi

echo "タスク状況を TaskList で確認してください。"
echo ""
echo "=== 復旧指示完了 ==="
echo ""
