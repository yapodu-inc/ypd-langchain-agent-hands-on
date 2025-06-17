"""
AWS Bedrock Knowledge Base integration module
"""
import os
import logging
from typing import Dict, Any, Optional
import boto3
from langchain_aws import AmazonKnowledgeBasesRetriever
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langgraph.prebuilt import create_react_agent
import re

logger = logging.getLogger(__name__)


class KnowledgeBaseClient:
    """Client for AWS Bedrock Knowledge Base operations"""
    
    def __init__(self):
        self.region = os.getenv("AWS_REGION", "us-west-2")
        self.knowledge_base_id = os.getenv("BEDROCK_KNOWLEDGE_BASE_ID")
        self.retriever = None
        
        if not self.knowledge_base_id:
            logger.warning("BEDROCK_KNOWLEDGE_BASE_ID not set. Knowledge Base integration disabled.")
        
    def initialize(self):
        """Initialize the knowledge base retriever"""
        if not self.knowledge_base_id:
            raise ValueError("BEDROCK_KNOWLEDGE_BASE_ID is required")
            
        try:
            # Initialize the retriever
            self.retriever = AmazonKnowledgeBasesRetriever(
                knowledge_base_id=self.knowledge_base_id,
                region_name=self.region,
                retrieval_config={
                    "vectorSearchConfiguration": {
                        "numberOfResults": 5,  # Return top 5 most relevant documents
                        "overrideSearchType": "HYBRID",  # Use hybrid search (semantic + keyword)
                    }
                }
            )
            logger.info(f"Knowledge Base retriever initialized for ID: {self.knowledge_base_id}")
        except Exception as e:
            logger.error(f"Failed to initialize Knowledge Base retriever: {e}")
            raise
    
    def get_retriever(self):
        """Get the configured retriever"""
        if not self.retriever:
            raise RuntimeError("Knowledge Base retriever not initialized. Call initialize() first.")
        return self.retriever


def is_knowledge_base_query(query: str) -> bool:
    """
    Determine if a query is related to internal documents/knowledge base
    
    Args:
        query: User's query string
        
    Returns:
        bool: True if the query is related to knowledge base
    """
    # Keywords that indicate knowledge base queries
    kb_keywords = [
        # Document-related
        "文書", "ドキュメント", "資料", "書類", "文献",
        "マニュアル", "ガイド", "手順書", "説明書",
        "規程", "規則", "ポリシー", "方針",
        "仕様書", "設計書", "報告書", "レポート",
        "レコード", "リスト", 
        
        # Company/internal related
        "社内", "会社", "組織", "部署", "チーム",
        "プロジェクト", "製品", "サービス",
        "システム", "ツール", "アプリケーション",
        
        # Question patterns
        "について教えて", "について説明", "とは何",
        "どのような", "どうやって", "やり方",
        "使い方", "方法", "手順",
        
        # Specific document requests
        "最新の", "現在の", "今の",
        "確認したい", "調べたい", "知りたい",
        "探している", "検索", "参照"
    ]
    
    # Convert query to lowercase for case-insensitive matching
    query_lower = query.lower()
    
    # Check for keywords
    for keyword in kb_keywords:
        if keyword in query_lower:
            logger.debug(f"Knowledge base keyword found: {keyword}")
            return True
    
    # Additional patterns that might indicate KB queries
    # Pattern: asking about specific procedures or policies
    procedure_patterns = [
        r".*の(手順|方法|やり方|使い方)",
        r".*について(教えて|説明|知りたい)",
        r".*マニュアル|.*ガイド|.*ドキュメント",
        r".*規程|.*ポリシー|.*ルール"
    ]
    
    for pattern in procedure_patterns:
        if re.search(pattern, query_lower):
            logger.debug(f"Knowledge base pattern matched: {pattern}")
            return True
    
    return False


def create_knowledge_base_agent(chat_model, retriever):
    """
    Create an agent configured for Knowledge Base operations
    
    Args:
        chat_model: The LLM model to use
        retriever: The knowledge base retriever
        
    Returns:
        Configured agent for knowledge base operations
    """
    
    # System message for the agent
    system_message = SystemMessage(content="""あなたは社内文書検索のアシスタントです。
AWS Bedrock Knowledge Baseから関連する文書を検索し、その内容に基づいて日本語で正確に回答してください。

重要なルール：
1. 常に日本語で応答する
2. Knowledge Baseから取得した情報に基づいて回答する
3. 情報が見つからない場合は、その旨を明確に伝える
4. 複数の関連文書が見つかった場合は、最も関連性の高い情報を優先する
5. 回答には出典（文書名やセクション）を含める
6. 推測や憶測は避け、文書に記載されている内容のみを伝える

回答フォーマット：
- 見つかった情報を簡潔にまとめる
- 必要に応じて箇条書きを使用する
- 出典を明記する（例：「〇〇マニュアルによると...」）
""")
    
    # Create prompt template
    prompt = ChatPromptTemplate.from_messages([
        system_message,
        MessagesPlaceholder(variable_name="messages"),
    ])
    
    # For knowledge base, we'll use the retriever as a tool
    from langchain_core.tools import Tool
    
    retriever_tool = Tool(
        name="search_knowledge_base",
        description="社内文書やマニュアルを検索します。質問に関連する文書を探すときに使用します。",
        func=lambda query: retriever.invoke(query)
    )
    
    # Create agent with the retriever tool
    agent = create_react_agent(
        chat_model,
        [retriever_tool],
        messages_modifier=prompt
    )
    
    return agent


async def execute_knowledge_base_query(agent, query: str) -> str:
    """
    Execute a knowledge base query using the configured agent
    
    Args:
        agent: The configured agent
        query: User's query
        
    Returns:
        Response string in Japanese
    """
    try:
        # Execute the query
        result = await agent.ainvoke({
            "messages": [HumanMessage(content=query)]
        })
        
        # Extract and process the response
        if result.get("messages"):
            # Find the last AI message
            for message in reversed(result["messages"]):
                if hasattr(message, 'content') and message.content:
                    # Skip tool call messages
                    if hasattr(message, 'tool_calls') and message.tool_calls:
                        continue
                    
                    content = message.content
                    
                    # Remove thinking tags if present
                    content = re.sub(r'<thinking>.*?</thinking>', '', content, flags=re.DOTALL).strip()
                    
                    if content:
                        return content
            
            return "申し訳ございません。関連する文書が見つかりませんでした。"
        
        return "申し訳ございません。応答の処理中にエラーが発生しました。"
        
    except Exception as e:
        logger.error(f"Error executing knowledge base query: {e}")
        return f"文書検索中にエラーが発生しました: {str(e)}"