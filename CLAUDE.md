# Repository
- terraform/ IaC のコードを管理
- ypd-langchain/ LangChain アプリケーションのコードを管理

# Conversation Guidelines
日本語で会話を行う

## MCP Servers

以下の MCP Server がインストール済

```bash
$ claude mcp list
awslabs.aws-documentation-mcp-server: /home/${USER}/.local/bin/uvx awslabs.aws-documentation-mcp-server@latest
terraform: docker run -i --rm hashicorp/terraform-mcp-server
```

- Terraform の コードに関するタスクを行う際は、必ず `aws-documentation-mcp-server` と `terraform` を使用する
- MCP Server と接続が不可の際はタスクを停止し、作業依頼者へ MCP Server との疎通が不可であることを報告する
