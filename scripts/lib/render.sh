#!/bin/bash
#
# Multi-Agent Framework v2 - テンプレートレンダリング
#
# _base.md + role.md を結合し、{{KEY}} プレースホルダーを置換して
# .claude/agents/<role>.md を生成する
#

# このスクリプトのディレクトリ
RENDER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$RENDER_LIB_DIR/common.sh"

# テンプレートのプレースホルダーを置換
# 使い方: render_template "template_content" "KEY" "VALUE"
replace_placeholder() {
    local content="$1"
    local key="$2"
    local value="$3"
    echo "${content//\{\{${key}\}\}/${value}}"
}

# ロールのsubagent_typeを取得
get_subagent_type() {
    local role="$1"
    case "$role" in
        designer|researcher)
            echo "Explore"
            ;;
        *)
            echo "general-purpose"
            ;;
    esac
}

# ロールのdisallowedToolsを取得
get_disallowed_tools() {
    local role="$1"
    case "$role" in
        designer|researcher)
            echo "Write, Edit, Bash"
            ;;
        *)
            echo ""
            ;;
    esac
}

# YAMLフロントマターを生成
generate_frontmatter() {
    local role="$1"
    local disallowed
    disallowed=$(get_disallowed_tools "$role")

    echo "---"
    echo "name: $role"
    echo "description: Multi-Agent Framework v2 - $role role"

    if [[ -n "$disallowed" ]]; then
        echo "disallowedTools: $disallowed"
    fi

    echo "---"
}

# _base.md + role.md を結合してレンダリング
render_agent_file() {
    local role="$1"
    local project_root="$2"
    local config_file="$project_root/.multi-agent/config.yaml"

    local base_template="$MA_FRAMEWORK_DIR/roles/_base.md"
    local role_template="$MA_FRAMEWORK_DIR/roles/${role}.md"

    if [[ ! -f "$base_template" ]]; then
        log_error "_base.md が見つかりません: $base_template"
        return 1
    fi

    if [[ ! -f "$role_template" ]]; then
        log_error "${role}.md が見つかりません: $role_template"
        return 1
    fi

    # プロジェクト情報を取得
    local project_name
    project_name=$(yaml_value "$config_file" "project.name")
    project_name="${project_name:-$(basename "$project_root")}"

    local team_name
    team_name="${project_name}-team"

    local domain_knowledge_path=".multi-agent/knowledge/domain.md"
    local agent_file_path=".claude/agents/${role}.md"

    # プロジェクト固有ルール
    local project_rules=""
    if [[ -f "$config_file" ]]; then
        project_rules=$(awk '/^project_rules:/{found=1; next} found && /^[a-zA-Z]/{exit} found{sub(/^[[:space:]]*- /, ""); print}' "$config_file" | sed 's/^[[:space:]]*//')
    fi

    # テンプレートを読み込み
    local base_content
    base_content=$(<"$base_template")
    local role_content
    role_content=$(<"$role_template")

    # 結合
    local combined="${base_content}

---

${role_content}"

    # プレースホルダー置換
    combined=$(replace_placeholder "$combined" "ROLE_NAME" "$role")
    combined=$(replace_placeholder "$combined" "TEAM_NAME" "$team_name")
    combined=$(replace_placeholder "$combined" "PROJECT_NAME" "$project_name")
    combined=$(replace_placeholder "$combined" "AGENT_FILE_PATH" "$agent_file_path")
    combined=$(replace_placeholder "$combined" "DOMAIN_KNOWLEDGE_PATH" "$domain_knowledge_path")
    combined=$(replace_placeholder "$combined" "PROJECT_SPECIFIC_RULES" "$project_rules")

    # フロントマター + 本文を出力
    local frontmatter
    frontmatter=$(generate_frontmatter "$role")

    echo "$frontmatter"
    echo ""
    echo "$combined"
}

# リードロール用のプロンプトをレンダリング（フロントマターなし + リード追加指示付き）
# --append-system-prompt に渡す用
render_lead_prompt() {
    local role="$1"
    local project_root="$2"
    local config_file="$project_root/.multi-agent/config.yaml"

    local base_template="$MA_FRAMEWORK_DIR/roles/_base.md"
    local role_template="$MA_FRAMEWORK_DIR/roles/${role}.md"

    if [[ ! -f "$base_template" ]]; then
        log_error "_base.md が見つかりません: $base_template"
        return 1
    fi

    if [[ ! -f "$role_template" ]]; then
        log_error "${role}.md が見つかりません: $role_template"
        return 1
    fi

    # プロジェクト情報を取得
    local project_name
    project_name=$(yaml_value "$config_file" "project.name")
    project_name="${project_name:-$(basename "$project_root")}"

    local team_name="${project_name}-team"
    local domain_knowledge_path=".multi-agent/knowledge/domain.md"
    local agent_file_path=".claude/agents/${role}.md"

    # プロジェクト固有ルール
    local project_rules=""
    if [[ -f "$config_file" ]]; then
        project_rules=$(awk '/^project_rules:/{found=1; next} found && /^[a-zA-Z]/{exit} found{sub(/^[[:space:]]*- /, ""); print}' "$config_file" | sed 's/^[[:space:]]*//')
    fi

    # テンプレートを読み込み
    local base_content
    base_content=$(<"$base_template")
    local role_content
    role_content=$(<"$role_template")

    # リードロール用追加指示
    local lead_preamble
    lead_preamble=$(cat <<'LEAD_EOF'

## リードロールとしての追加指示

あなたはこのセッションの **リードロール（チームリーダー）** です。
ボス（ユーザー）と直接対話し、チームを指揮します。

### 基本フロー
1. ボスから要件を受け取る
2. **TeamCreate** でチームを作成（team_name を指定）
3. **TaskCreate** でタスクを分解
4. **Task** ツールでメンバーをspawn
5. **TaskUpdate** でタスクを割り振り（owner 設定）
6. **SendMessage** でメンバーとコミュニケーション
7. 完了後、ボスに報告

### メンバーのspawn方法

各ロールの指示書は `.claude/agents/<role>.md` にあります。
spawn時は **ファイル内容を読んでpromptに含めて** ください：

```
# 1. ロール指示書を読む
Read: .claude/agents/developer.md

# 2. 読んだ内容をpromptに含めてspawn
Task: subagent_type="general-purpose", team_name="<team>", name="tachikoma-1",
      prompt="<ロール指示書の内容>\n\nタスク: <具体的な作業内容>"
```

### subagent_type マッピング
| ロール | subagent_type |
|--------|---------------|
| developer, tester | general-purpose |
| designer, researcher | Explore（Read-only） |

### 注意事項
- _base.md の「ボスへの直接連絡禁止」はリードロールには適用されない（あなたがボスと話す）
- メンバーからの報告は SendMessage で受け取る
- メンバーの作業完了後は shutdown_request で終了させる
- 全作業完了後は TeamDelete でチームを削除
LEAD_EOF
    )

    # 結合
    local combined="${base_content}

---

${role_content}

---

${lead_preamble}"

    # プレースホルダー置換
    combined=$(replace_placeholder "$combined" "ROLE_NAME" "$role")
    combined=$(replace_placeholder "$combined" "TEAM_NAME" "$team_name")
    combined=$(replace_placeholder "$combined" "PROJECT_NAME" "$project_name")
    combined=$(replace_placeholder "$combined" "AGENT_FILE_PATH" "$agent_file_path")
    combined=$(replace_placeholder "$combined" "DOMAIN_KNOWLEDGE_PATH" "$domain_knowledge_path")
    combined=$(replace_placeholder "$combined" "PROJECT_SPECIFIC_RULES" "$project_rules")

    echo "$combined"
}

# 全ロールのエージェントファイルを生成
render_all_agents() {
    local project_root="$1"
    local config_file="$project_root/.multi-agent/config.yaml"
    local agents_dir="$project_root/.claude/agents"

    mkdir -p "$agents_dir"

    local roles
    roles=$(get_enabled_roles "$config_file")

    for role in $roles; do
        local output_file="$agents_dir/${role}.md"
        log_info "生成中: $output_file"

        if render_agent_file "$role" "$project_root" > "$output_file"; then
            log_success "生成完了: ${role}.md"
        else
            log_error "生成失敗: ${role}.md"
            return 1
        fi
    done
}
