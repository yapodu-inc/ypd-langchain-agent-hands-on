# AWS CLI でBedrock Knowledge Baseを確認する方法

## 1. Knowledge Baseの一覧を取得
```bash
aws bedrock-agent list-knowledge-bases --region us-west-2
```

## 2. 特定のKnowledge Baseの詳細を取得
```bash
# Knowledge Base IDが必要（terraform outputから取得可能）
aws bedrock-agent get-knowledge-base --knowledge-base-id <KNOWLEDGE_BASE_ID> --region us-west-2
```

## 3. Knowledge Baseのデータソース一覧を取得
```bash
aws bedrock-agent list-data-sources --knowledge-base-id <KNOWLEDGE_BASE_ID> --region us-west-2
```

## 4. Terraformから直接IDを取得する方法
```bash
cd terraform/environment/dev-ypd/default
terraform output bedrock_knowledge_base_id
terraform output bedrock_knowledge_base_arn
```

## 5. AWS CLIの設定確認
```bash
# 現在のAWS設定を確認
aws sts get-caller-identity

# 使用中のリージョンを確認
aws configure get region
```

## 6. 必要なIAM権限
Knowledge Baseを確認するには以下の権限が必要です：
- `bedrock:ListKnowledgeBases`
- `bedrock:GetKnowledgeBase`
- `bedrock:ListDataSources`

## 7. 代替確認方法
### AWS Console での確認
- AWS Console > Amazon Bedrock > ナレッジベース
- リージョンが us-west-2 に設定されていることを確認

### CloudFormation/Terraformリソースの確認
```bash
# AWSリソースタグで検索
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Name,Values=ypd-dev-knowledge-base \
  --region us-west-2
```

## トラブルシューティング

### コンソールに表示されない場合の原因
1. **リージョンの不一致**: us-west-2 以外のリージョンを見ている
2. **権限不足**: IAMユーザー/ロールにBedrock権限がない
3. **作成エラー**: Terraformでエラーが発生している可能性
4. **ブラウザキャッシュ**: ページを再読み込みする

### 確認手順
1. AWS Consoleで正しいリージョン（us-west-2）を選択
2. ページを再読み込み（Ctrl+F5 または Cmd+Shift+R）
3. 別のブラウザまたはシークレットモードで確認
