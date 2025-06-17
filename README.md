# このレポジトリについて
株式会社ヤポドゥの LangChain アプリケーションのハンズオン用のレポジトリです。

## LangChain アプリケーション構成
```
1. ALB (Application Load Balancer) でユーザーのリクエストを受け取る
       │
       ▼
2. ALB 経由でユーザーの質問を LangChain が受け取る
       │
       ▼
3. 質問内容をLangChain（エージェント）が解析
   - 質問の意図（intent）を識別
   - LangGraphのcreate_react_agentを使用してツール実行を管理
       │
       ├──【タスクに関する質問】─────→ Asana MCP ServerのAPIを呼び出し
       │　　　　　　　　　　　　　　 　├── Asanaからの応答を受信
       │　　　　　　　　　　　　　　 　└── 応答を加工し、ユーザーに返却
       │
       └──【社内文書に関する質問】───→ Amazon Bedrock Knowledge Bases (RAG)
         　　　　　　　　　　　　　　 　├── 類似文書をAurora PostgreSQL(pgvector)から取得
         　　　　　　　　　　　　　　 　├── LLMを使って応答を生成
         　　　　　　　　　　　　　　 　└── 応答をユーザーに返却
```


# 概要

1. Bedrock Knowledge Base 前段階 apply
2. Model 有効化
3. Bedrock Knowledge Base の作成
4. ローカル環境での LangChain アプリケーションの動作確認
5. ECR の作成と コンテナ push


## 1. Bedrock Knowledge Base 前段階 apply
1. Terraform を使用して、Bedrock Knowledge Base の前段階のリソースを作成
- S3 バケットの作成
- Aurora Serverless v2 の作成
    - 今回は Serverless v2 で構築しているため問題ないが,RDS Data API は tg4 では使用不可, db.r8g.large であれば使用可能。
- IAM ロールの作成

2. Aurora Serverless v2 の作成後、以下の設定を行う
- pgvector 拡張の有効化とテーブル作成


## 2. Model 有効化
使用する Foundation Model を アカウント単位で有効化

### 埋め込みモデルの選択
**Embedding Model**  
S3上のPDF、Markdown、Excel、Wordファイルなどを利用する場合、ドキュメントをベクトル化するための埋め込みモデル（Embedding Model）の選択する

様々なモデルを使用できるが、本ドキュメントでは以下のモデルを使用する。
- Amazon Titan Text Embeddings V2
    - 日本語を含む多言語に対応
    - 出力ベクトルの次元が選択可能 (256, 512, 1024)
        - ベクトルサイズが大きくなると、より詳細な応答が作成されるが、計算により長い時間がかかる
        - ベクトルが短くなるほど詳細度は低くなるが、応答時間は短縮される。
        - AWS 公式の説明では 512 次元でも 1024 次元との大きな違いはないとのこと
            - https://aws.amazon.com/jp/blogs/news/amazon-titan-text-v2-now-available-in-amazon-bedrock-optimized-for-improving-rag/
        - 今回は手順として実績のある 1024 次元を使用する

英語&日本語等の検索を行う際は Cohere Embed (Multilingual) がいいらしい。

### 生成用 FM（回答生成・クエリ解析）
Knowledge Base の確認の際に使用する LLM（Language Model）を選択する
生成時の LLM を選択することで、Knowledge Base のクエリ解析や回答生成を行うことができる。
Claude での利用が多いが、今回は Amazon Nova Pro を使用する。

## 3. Bedrock Knowledge Base の作成
Bedrock Knowledge Base の作成とデータソースの同期を行う。
コンソール画面より、Knowledge Base での RAG 検索の動作確認を行う。

## 4. ローカル環境での LangChain アプリケーションの動作確認
ローカル環境で LangChain アプリケーション用コンテナを起動し、LangChain アプリケーションの動作確認を行う。
※ NOTE: 5/27 asana , bedrock の組み込みは未実施 田村


# 手順
1. Bedrock Knowledge Base 前段階 deploy
    1. `terraform/environment/dev-ypd/default` ディレクトリに移動
    2. `terraform apply` を実行して Aurora Serverless v2 を作成
    3. `doc/1.3.aurora_postgres_bedrock_setup.md` を参照し pgvector 拡張の有効化とテーブル作成


2. Model 有効化
    1. AWS コンソールにログイン
    2. Amazon Bedrock -> モデルアクセス
    3. [ 特定のモデルを有効にする ] or [ モデルアクセスを変更 ]をクリックする
    4. [ Amazon ] を選択
    6. [ 送信 ] をクリック
    7. [ モデルアクセス ] ページで、Titan Text Embeddings V2 が有効になっていることを確認
        - 有効になっていない場合は、10分ほど待つ


3. Bedrock Knowledge Base の作成
    1. `terraform/environment/dev-ypd/default` ディレクトリに移動
    2. `03_bedrock_knowledgebase.tf.bk` を `03_bedrock_knowledgebase.tf` にリネーム
    3. `terraform apply` を実行して Bedrock Knowledge Base を作成
    4. apply 完了時に出力される `bedrock_knowledge_base_id = "NNIDIDIDID"` を控える
    5. コンソール画面よりデータソースに同期実行
    6. [ ナレッジベースをテスト ]をクリックし、Knowledge Base の RAG 検索の動作確認
        - [ モデルを選択 ] で Amazon Nova Pro を選択
        - [ 質問を入力 ] に質問を入力
             - 質問例: 「レコードのリストはありますか?」など
        - 応答が返ってくることを確認

4. ローカル環境での LangChain アプリケーションの動作確認
    1. `ypd-langchain/docker` ディレクトリに移動
    2. 3.4 で取得した `bedrock_knowledge_base_id` を `ypd-langchain/.env` ファイルに設定
        - `BEDROCK_KNOWLEDGE_BASE_ID=NNIDIDIDID`
    3. `docker compose build` でイメージをビルド
    4. `env | grep AWS` で AWS 認証情報が設定されていない場合は、以下のコマンドで設定
        - export AWS_ACCESS_KEY_ID=<AWS_ACCESS_KEY_ID>
        - export AWS_SECRET_ACCESS_KEY=<AWS_SECRET_ACCESS_KEY>
        - export AWS_REGION=us-west-2
    5. `docker compose up` でコンテナを起動
    6. `doc/4.6.agent-test.md` を参照し、ローカル環境での LangChain アプリケーションの動作確認

