#!/usr/bin/env python3
"""
Simple test script for Knowledge Base functionality
"""
import asyncio
import os
from knowledge_base import is_knowledge_base_query, KnowledgeBaseClient
from langchain_aws import ChatBedrock

async def test_kb_detection():
    """Test query detection"""
    test_queries = [
        # Should be detected as KB queries
        ("社内のセキュリティポリシーについて教えて", True),
        ("最新のマニュアルを確認したい", True),
        ("プロジェクトの仕様書はどこにありますか？", True),
        ("会社の規程について知りたい", True),
        ("システムの使い方を教えて", True),
        
        # Should NOT be detected as KB queries  
        ("今日の天気は？", False),
        ("計算して: 100 + 200", False),
        ("こんにちは", False),
    ]
    
    print("=== Knowledge Base Query Detection Test ===")
    for query, expected in test_queries:
        result = is_knowledge_base_query(query)
        status = "✅" if result == expected else "❌"
        print(f"{status} '{query}' -> {result} (expected: {expected})")


async def test_kb_client():
    """Test KB client initialization"""
    print("\n=== Knowledge Base Client Test ===")
    
    if not os.getenv("BEDROCK_KNOWLEDGE_BASE_ID"):
        print("❌ BEDROCK_KNOWLEDGE_BASE_ID not set. Skipping KB client test.")
        return
    
    try:
        kb_client = KnowledgeBaseClient()
        kb_client.initialize()
        print("✅ Knowledge Base client initialized successfully")
        
        # Test retriever
        retriever = kb_client.get_retriever()
        print("✅ Retriever obtained successfully")
        
        # Test a simple query
        test_query = "テスト文書"
        print(f"\nTesting retrieval with query: '{test_query}'")
        results = retriever.invoke(test_query)
        print(f"✅ Retrieved {len(results)} documents")
        
    except Exception as e:
        print(f"❌ Error: {e}")


async def main():
    """Run all tests"""
    await test_kb_detection()
    await test_kb_client()


if __name__ == "__main__":
    asyncio.run(main())