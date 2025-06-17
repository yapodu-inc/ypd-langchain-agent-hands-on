
# buket = 作成したS3バケットの名前を指定してください。
terraform {
  backend "s3" {
    bucket = "yapodu-hands-on-473741442055"
    key    = "terraform/state/yapodu-ai-bot/ypd-dev/default/terraform.tfstate"
    region = "us-west-2"
  }
}