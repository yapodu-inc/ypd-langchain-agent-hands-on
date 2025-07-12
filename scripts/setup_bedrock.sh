#!/bin/bash

# ヤポドゥハンズオン Aurora PostgreSQL Bedrock Knowledge Base セットアップスクリプト
# このスクリプトは docs/1.3.aurora_postgres_bedrock_setup.md の手順を自動化します

set -euo pipefail

# デフォルト値
DEFAULT_REGION="us-west-2"
DEFAULT_DATABASE="main_db"

# 色付きの出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ出力関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 使用方法表示
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Aurora PostgreSQL Bedrock Knowledge Base セットアップスクリプト

OPTIONS:
    -c, --cluster-name CLUSTER_NAME    Aurora クラスター名（必須）
    -r, --region REGION                AWSリージョン（デフォルト: $DEFAULT_REGION）
    -d, --database DATABASE            データベース名（デフォルト: $DEFAULT_DATABASE）
    --dry-run                          実際の変更を行わず、実行予定のコマンドのみ表示
    -h, --help                         このヘルプメッセージを表示

例:
    $0 -c my-aurora-cluster
    $0 -c my-aurora-cluster -r us-east-1 -d my_database
    $0 -c my-aurora-cluster --dry-run

EOF
}

# 引数解析
parse_args() {
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -d|--database)
                DATABASE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                usage
                exit 1
                ;;
        esac
    done

    # 必須パラメータのチェック
    if [[ -z "${CLUSTER_NAME:-}" ]]; then
        log_error "クラスター名が指定されていません"
        usage
        exit 1
    fi

    # デフォルト値の設定
    REGION="${REGION:-$DEFAULT_REGION}"
    DATABASE="${DATABASE:-$DEFAULT_DATABASE}"
}

# AWS CLI の存在確認
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI がインストールされていません"
        exit 1
    fi

    log_info "AWS CLI の認証情報を確認中..."
    
    # DRY RUN モードの場合は認証情報チェックをスキップ
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] AWS CLI の認証情報チェックをスキップします"
        return 0
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI の認証情報が設定されていません"
        exit 1
    fi
}

# Aurora クラスター情報の取得
get_cluster_info() {
    log_info "Aurora クラスター情報を取得中..."
    
    # DRY RUN モードの場合はダミーの値を設定
    if [[ "$DRY_RUN" == "true" ]]; then
        CLUSTER_ARN="arn:aws:rds:${REGION}:123456789012:cluster:${CLUSTER_NAME}"
        log_info "[DRY-RUN] クラスター ARN: $CLUSTER_ARN"
        return 0
    fi
    
    CLUSTER_INFO=$(aws rds describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_NAME" \
        --region "$REGION" \
        --query 'DBClusters[0].{ClusterArn:DBClusterArn,DatabaseName:DatabaseName,MasterUsername:MasterUsername,HttpEndpointEnabled:HttpEndpointEnabled}' \
        --output json 2>/dev/null || echo "null")
    
    if [[ "$CLUSTER_INFO" == "null" ]]; then
        log_error "クラスター '$CLUSTER_NAME' が見つかりません"
        exit 1
    fi

    CLUSTER_ARN=$(echo "$CLUSTER_INFO" | jq -r '.ClusterArn')
    HTTP_ENDPOINT_ENABLED=$(echo "$CLUSTER_INFO" | jq -r '.HttpEndpointEnabled')
    
    if [[ "$HTTP_ENDPOINT_ENABLED" != "true" ]]; then
        log_error "HTTP エンドポイントが有効になっていません。enable_http_endpoint = true を設定してください"
        exit 1
    fi
    
    log_success "クラスター情報を取得しました: $CLUSTER_ARN"
}

# Secrets Manager の認証情報ARN取得
get_secret_arn() {
    log_info "Secrets Manager の認証情報ARNを取得中..."
    
    # DRY RUN モードの場合はダミーの値を設定
    if [[ "$DRY_RUN" == "true" ]]; then
        SECRET_ARN="arn:aws:secretsmanager:${REGION}:123456789012:secret:rds!cluster-dummy-secret-AbCdEf"
        log_info "[DRY-RUN] Secret ARN: $SECRET_ARN"
        return 0
    fi
    
    # クラスターIDを含む名前で検索
    SECRET_ARN=$(aws secretsmanager list-secrets \
        --region "$REGION" \
        --query "SecretList[?contains(Name, 'rds') && contains(Name, 'cluster')].ARN" \
        --output text 2>/dev/null | head -1)
    
    # 見つからない場合は、より広範囲で検索
    if [[ -z "$SECRET_ARN" ]]; then
        log_info "より広範囲で Secrets Manager エントリを検索中..."
        SECRET_ARN=$(aws secretsmanager list-secrets \
            --region "$REGION" \
            --query "SecretList[?contains(Name, 'rds')].ARN" \
            --output text 2>/dev/null | head -1)
    fi
    
    if [[ -z "$SECRET_ARN" ]]; then
        log_error "RDS クラスター用の Secrets Manager エントリが見つかりません"
        log_error "利用可能なシークレットを確認してください:"
        aws secretsmanager list-secrets \
            --region "$REGION" \
            --query "SecretList[].Name" \
            --output table 2>/dev/null || true
        exit 1
    fi
    
    log_success "Secret ARN を取得しました: $SECRET_ARN"
}

# RDS Data API でSQL実行
execute_sql() {
    local sql="$1"
    local description="$2"
    
    log_info "$description を実行中..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 実行予定のSQL:"
        echo "$sql" | sed 's/^/    /'
        return 0
    fi
    
    local result
    result=$(aws rds-data execute-statement \
        --resource-arn "$CLUSTER_ARN" \
        --secret-arn "$SECRET_ARN" \
        --database "$DATABASE" \
        --sql "$sql" \
        --region "$REGION" 2>&1)
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "$description でエラーが発生しました:"
        echo "$result" | sed 's/^/    /' # インデントを追加
        return 1
    fi
    
    log_success "$description が完了しました"
    return 0
}

# pgvector 拡張の有効化
enable_pgvector() {
    execute_sql "CREATE EXTENSION IF NOT EXISTS vector;" "pgvector 拡張の有効化"
}

# Bedrock Knowledge Base 用テーブルの作成
create_bedrock_table() {
    local sql="CREATE TABLE IF NOT EXISTS bedrock_knowledge_base (
        id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        embedding vector(1024),
        chunks    TEXT NOT NULL,
        metadata  JSONB
    );"
    
    execute_sql "$sql" "Bedrock Knowledge Base 用テーブルの作成"
}

# テキスト検索用 GIN インデックスの作成
create_gin_index() {
    local sql="CREATE INDEX IF NOT EXISTS bedrock_knowledge_base_chunks_idx 
        ON bedrock_knowledge_base USING gin 
        (to_tsvector('simple', chunks));"
    
    execute_sql "$sql" "テキスト検索用 GIN インデックスの作成"
}

# ベクター検索用 HNSW インデックスの作成
create_hnsw_index() {
    local sql="CREATE INDEX IF NOT EXISTS bedrock_knowledge_base_embedding_idx 
        ON bedrock_knowledge_base USING hnsw 
        (embedding vector_cosine_ops);"
    
    execute_sql "$sql" "ベクター検索用 HNSW インデックスの作成"
}

# 設定確認
verify_setup() {
    log_info "設定確認を実行中..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 設定確認をスキップします"
        return 0
    fi
    
    # テーブルの存在確認
    local table_check_sql="SELECT table_name FROM information_schema.tables WHERE table_name = 'bedrock_knowledge_base';"
    local table_result
    table_result=$(aws rds-data execute-statement \
        --resource-arn "$CLUSTER_ARN" \
        --secret-arn "$SECRET_ARN" \
        --database "$DATABASE" \
        --sql "$table_check_sql" \
        --region "$REGION" \
        --output json 2>/dev/null)
    
    if [[ $(echo "$table_result" | jq '.records | length') -eq 0 ]]; then
        log_error "テーブル 'bedrock_knowledge_base' が見つかりません"
        return 1
    fi
    
    log_success "テーブル 'bedrock_knowledge_base' が存在します"
    
    # インデックスの確認
    local index_check_sql="SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'bedrock_knowledge_base';"
    local index_result
    index_result=$(aws rds-data execute-statement \
        --resource-arn "$CLUSTER_ARN" \
        --secret-arn "$SECRET_ARN" \
        --database "$DATABASE" \
        --sql "$index_check_sql" \
        --region "$REGION" \
        --output json 2>/dev/null)
    
    local index_count
    index_count=$(echo "$index_result" | jq '.records | length')
    
    if [[ $index_count -lt 3 ]]; then
        log_warning "期待されるインデックス数（3つ）より少ないです（$index_count）"
    else
        log_success "インデックスが正常に作成されています（$index_count個）"
    fi
    
    # インデックス詳細の表示
    echo "$index_result" | jq -r '.records[] | "  - " + .[0].stringValue + ": " + .[1].stringValue'
}

# メイン処理
main() {
    log_info "Aurora PostgreSQL Bedrock Knowledge Base セットアップを開始します"
    
    # 引数解析
    parse_args "$@"
    
    # 設定値の表示
    log_info "設定値:"
    log_info "  クラスター名: $CLUSTER_NAME"
    log_info "  リージョン: $REGION"
    log_info "  データベース: $DATABASE"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "  モード: DRY RUN（実際の変更は行いません）"
    fi
    
    # 前提条件の確認
    check_aws_cli
    get_cluster_info
    get_secret_arn
    
    # セットアップ処理
    enable_pgvector
    create_bedrock_table
    create_gin_index
    create_hnsw_index
    
    # 設定確認
    verify_setup
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "DRY RUN が完了しました！"
        log_info "実際に実行するには --dry-run オプションを外してください"
    else
        log_success "すべての設定が完了しました！"
        log_info "次のステップ: terraform apply で Bedrock Knowledge Base を作成してください"
    fi
}

# jq の存在確認
if ! command -v jq &> /dev/null; then
    log_error "jq がインストールされていません。JSON処理に必要です"
    exit 1
fi

# スクリプト実行
main "$@"