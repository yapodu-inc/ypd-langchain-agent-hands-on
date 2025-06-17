"""
Asana MCP Client configuration and initialization
"""
import os
from typing import List, Optional
from langchain_mcp_adapters.client import MultiServerMCPClient
from langchain_core.tools import BaseTool
import logging

logger = logging.getLogger(__name__)


class AsanaMCPClient:
    """Asana MCP Client wrapper for managing Asana operations"""
    
    def __init__(self, access_token: Optional[str] = None):
        self.access_token = access_token or os.getenv("ASANA_ACCESS_TOKEN")
        if not self.access_token:
            raise ValueError("ASANA_ACCESS_TOKEN is required")
        
        self.client = None
        self.tools = None
    
    async def initialize(self):
        """Initialize the MCP client and get available tools"""
        try:
            # Configure MCP client with Asana server
            self.client = MultiServerMCPClient({
                "asana": {
                    "command": "npx",
                    "args": ["-y", "@roychri/mcp-server-asana"],
                    "transport": "stdio",
                    "env": {
                        "ASANA_ACCESS_TOKEN": self.access_token
                    }
                }
            })
            
            # Get available tools from the MCP server
            self.tools = await self.client.get_tools()
            logger.info(f"Initialized Asana MCP client with {len(self.tools)} tools")
            # Log tool names for debugging
            tool_names = [tool.name for tool in self.tools]
            logger.info(f"Available Asana tools: {tool_names}")
            return self.tools
            
        except Exception as e:
            logger.error(f"Failed to initialize Asana MCP client: {e}")
            raise
    
    async def get_tools(self) -> List[BaseTool]:
        """Get available Asana tools"""
        if not self.tools:
            await self.initialize()
        return self.tools
    
    async def close(self):
        """Close the MCP client connection"""
        if self.client:
            await self.client.__aexit__(None, None, None)


def is_asana_related_query(query: str) -> bool:
    """
    Simple intent detection to determine if a query is related to Asana tasks
    
    Args:
        query: User's input query
        
    Returns:
        bool: True if query is related to Asana tasks
    """
    asana_keywords = [
        "タスク", "task", "tasks",
        "プロジェクト", "project", 
        "アサナ", "asana", "Asana",
        "期限", "deadline", "due",
        "担当", "assignee", "assigned",
        "進捗", "progress", "status",
        "コメント", "comment",
        "完了", "complete", "done",
        "作成", "create", "new",
        "更新", "update", "modify"
    ]
    
    query_lower = query.lower()
    return any(keyword.lower() in query_lower for keyword in asana_keywords)