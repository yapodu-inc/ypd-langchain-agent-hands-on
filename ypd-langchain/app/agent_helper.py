"""
Helper module for creating and configuring LangChain agents with Asana MCP tools
"""
from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.prebuilt import create_react_agent
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from typing import List, Any
import logging

logger = logging.getLogger(__name__)


def create_asana_agent(chat_model, tools: List[Any]):
    """
    Create a ReAct agent specifically configured for Asana operations
    
    Args:
        chat_model: The LLM model to use
        tools: List of Asana MCP tools
        
    Returns:
        Configured agent for Asana operations
    """
    
    # System message for the agent
    system_message = SystemMessage(content="""あなたはAsanaタスク管理のアシスタントです。
ユーザーの質問に対して、利用可能なAsanaツールを使用して情報を取得し、日本語で応答してください。

重要なルール：
1. 常に日本語で応答する
2. プロジェクト一覧を取得する場合、まずワークスペース一覧を取得してから、各ワークスペースのプロジェクトを検索する
3. エラーが発生した場合は、わかりやすく日本語で説明する
4. 思考過程（<thinking>タグ）は最終出力に含めない
5. ツールの実行結果を元に、簡潔でわかりやすい応答を生成する

利用可能なツール:
- asana_list_workspaces: ワークスペース一覧を取得
- asana_search_projects: 特定のワークスペース内のプロジェクトを検索
- asana_search_tasks: タスクを検索
- その他多数のAsana操作ツール
""")
    
    # Create prompt template with system message
    prompt = ChatPromptTemplate.from_messages([
        system_message,
        MessagesPlaceholder(variable_name="messages"),
    ])
    
    # Create agent with prompt template
    agent = create_react_agent(
        chat_model,
        tools,
        messages_modifier=prompt
    )
    
    return agent


async def execute_asana_query(agent, query: str) -> str:
    """
    Execute an Asana-related query using the configured agent
    
    Args:
        agent: The configured agent
        query: User's query in Japanese
        
    Returns:
        Response string in Japanese
    """
    try:
        # Add instruction to the query
        enhanced_query = f"""{query}

注意: 
- プロジェクト一覧を取得する場合は、まずasana_list_workspacesでワークスペースを取得してください
- その後、各ワークスペースに対してasana_search_projectsを使用してプロジェクトを検索してください
- 最終的な応答は日本語で、ユーザーにわかりやすく整形してください"""
        
        # Execute the query
        result = await agent.ainvoke({
            "messages": [HumanMessage(content=enhanced_query)]
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
                    import re
                    content = re.sub(r'<thinking>.*?</thinking>', '', content, flags=re.DOTALL).strip()
                    
                    # If content is empty after removing thinking tags, continue to next message
                    if not content:
                        continue
                        
                    return content
            
            # If no suitable message found, return error
            return "申し訳ございません。Asanaからの情報を取得できませんでした。"
        
        return "申し訳ございません。応答の処理中にエラーが発生しました。"
        
    except Exception as e:
        logger.error(f"Error executing Asana query: {e}")
        return f"エラーが発生しました: {str(e)}"