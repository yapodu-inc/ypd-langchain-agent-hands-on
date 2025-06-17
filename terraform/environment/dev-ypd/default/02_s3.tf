resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "knowledgebase" {
  bucket = "${local.knowledgebase_bucket_name}-${random_id.bucket_suffix.hex}"
  # 開発環境ではバケットの削除を許可
  force_destroy = local.env == "dev" ? true : false

  tags = {
    Name = "${local.knowledgebase_bucket_name}-${random_id.bucket_suffix.hex}"
    Env  = local.env
  }
}

resource "aws_s3_bucket_cors_configuration" "knowledgebase" {
  bucket = aws_s3_bucket.knowledgebase.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = [
      "GET",
      "PUT",
      "POST",
      "DELETE"
    ]
    allowed_origins = ["*"]
  }
}