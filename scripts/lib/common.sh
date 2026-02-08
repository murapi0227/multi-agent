#!/bin/bash
#
# Multi-Agent Framework v2 - 共有ユーティリティ
#

# フレームワークのルートディレクトリ
MA_FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# YAMLから単純なkey: value を読み取る（軽量パーサー）
# 使い方: yaml_value "config.yaml" "project.name"
# ネストは "." 区切りで1階層のみ対応
yaml_value() {
    local file="$1"
    local key="$2"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # ドット区切りのキーを分解
    local parent=""
    local child=""
    if [[ "$key" == *.* ]]; then
        parent="${key%%.*}"
        child="${key#*.}"
    else
        child="$key"
    fi

    if [[ -n "$parent" ]]; then
        # 親セクション内のキーを検索
        awk -v parent="$parent" -v child="$child" '
            /^[a-zA-Z]/ { section = $0; gsub(/:.*/, "", section); gsub(/^[[:space:]]+/, "", section) }
            section == parent && $0 ~ "^[[:space:]]+" child ":" {
                val = $0
                sub(/^[^:]+:[[:space:]]*/, "", val)
                gsub(/^["'\''"]|["'\''"]$/, "", val)
                print val
                exit
            }
        ' "$file"
    else
        # トップレベルのキーを検索
        awk -v key="$child" '
            $0 ~ "^" key ":" {
                val = $0
                sub(/^[^:]+:[[:space:]]*/, "", val)
                gsub(/^["'\''"]|["'\''"]$/, "", val)
                print val
                exit
            }
        ' "$file"
    fi
}

# プロジェクトルートを検出（.multi-agent/config.yaml があるディレクトリ）
find_project_root() {
    local dir="${1:-$PWD}"
    for i in {1..5}; do
        if [[ -f "$dir/.multi-agent/config.yaml" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# プロジェクトルートを検出して変数にセット（エラーメッセージ付き）
check_project_dir() {
    PROJECT_ROOT="$(find_project_root)"
    if [[ -z "$PROJECT_ROOT" ]]; then
        log_error "マルチエージェントプロジェクトが見つかりません。"
        log_error "'ma init' を実行してプロジェクトを初期化してください。"
        exit 1
    fi
    CONFIG_FILE="$PROJECT_ROOT/.multi-agent/config.yaml"
}

# ロールが有効かチェック
is_role_enabled() {
    local role="$1"
    local config_file="$2"
    local enabled
    enabled=$(awk -v role="$role" '
        /^[[:space:]]*'"$role"':/ { found=1; next }
        found && /enabled:/ { print $2; exit }
        found && /^[[:space:]]*[a-z]/ && !/enabled/ { exit }
    ' "$config_file")
    [[ "$enabled" == "true" ]]
}

# ロールのモデルを取得
get_role_model() {
    local role="$1"
    local config_file="$2"
    local model
    model=$(awk '
        /^[[:space:]]*'"$role"':/ { found=1; next }
        found && /model:/ { print $2; exit }
        found && /^[^ ]/ { exit }
        found && /^  [a-zA-Z]/ { exit }
    ' "$config_file")
    echo "${model:-sonnet}"
}

# ロールのプラグインを取得
get_role_plugins() {
    local role="$1"
    local config_file="$2"
    local plugins
    plugins=$(awk '
        /^[[:space:]]*'"$role"':/ { found=1; next }
        found && /plugins:/ { print $2; exit }
        found && /^[^ ]/ { exit }
        found && /^  [a-zA-Z]/ { exit }
    ' "$config_file")
    echo "$plugins"
}

# 有効なロール一覧を取得
get_enabled_roles() {
    local config_file="$1"
    local roles=("secretary" "manager" "developer" "tester" "designer" "researcher")
    for role in "${roles[@]}"; do
        if is_role_enabled "$role" "$config_file"; then
            echo "$role"
        fi
    done
}
