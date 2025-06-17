data "aws_caller_identity" "current" {}

resource "aws_iam_role" "bedrock" {
  name = local.bedrock_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.bedrock.name
  policy_arn = aws_iam_policy.bedrock.arn
}

resource "aws_iam_policy" "bedrock" {
  name = local.bedrock_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Bedrock モデル一覧取得権限
      {
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:ListCustomModels"
        ]
        Resource = "*"
      },
      # Bedrock モデルの権限を "*" から具体的な埋め込みモデル ARN に変更
      # Knowledge Base で使用する埋め込みモデルへの InvokeModel 権限
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${local.default_region}::foundation-model/amazon.titan-embed-text-v2:0",
          "arn:aws:bedrock:${local.default_region}::foundation-model/cohere.embed-english-v3",
          "arn:aws:bedrock:${local.default_region}::foundation-model/cohere.embed-multilingual-v3"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.knowledgebase.arn,
          "${aws_s3_bucket.knowledgebase.arn}/*"
        ]
      },
      # Aurora PostgreSQL 用の RDS Data API 権限を追加
      # Aurora クラスター情報の取得権限
      {
        Sid    = "RdsDescribeStatementID"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBClusters"
        ]
        Resource = [
          "arn:aws:rds:${local.default_region}:${data.aws_caller_identity.current.account_id}:cluster:${local.main_db_aurora_cluster_identifier}"
        ]
      },
      # RDS Data API 経由でのデータベース操作権限（ベクターデータの読み書き用）
      {
        Sid    = "DataAPIStatementID"
        Effect = "Allow"
        Action = [
          "rds-data:BatchExecuteStatement",
          "rds-data:ExecuteStatement"
        ]
        Resource = [
          "arn:aws:rds:${local.default_region}:${data.aws_caller_identity.current.account_id}:cluster:${local.main_db_aurora_cluster_identifier}"
        ]
      },
      # Secrets Manager アクセス権限（Aurora の認証情報取得用）
      {
        Sid    = "SecretsManagerStatementID"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${local.default_region}:${data.aws_caller_identity.current.account_id}:secret:rds!cluster-*"
        ]
      }

    ]
  })
}
