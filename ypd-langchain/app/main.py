from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from langchain_aws import ChatBedrock
from langchain_core.messages import HumanMessage
from langgraph.prebuilt import create_react_agent
import os
import asyncio
import logging
import re
from contextlib import asynccontextmanager

from asana_mcp import AsanaMCPClient, is_asana_related_query
from agent_helper import create_asana_agent, execute_asana_query
from knowledge_base import KnowledgeBaseClient, is_knowledge_base_query, create_knowledge_base_agent, execute_knowledge_base_query

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global variables to store clients
asana_client = None
kb_client = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle - initialize and cleanup resources"""
    global asana_client, kb_client
    
    # Startup
    try:
        # Initialize Asana MCP client if token is available
        if os.getenv("ASANA_ACCESS_TOKEN"):
            asana_client = AsanaMCPClient()
            await asana_client.initialize()
            logger.info("Asana MCP client initialized successfully")
        else:
            logger.warning("ASANA_ACCESS_TOKEN not found. Asana integration disabled.")
    except Exception as e:
        logger.error(f"Failed to initialize Asana MCP client: {e}")
        asana_client = None
    
    # Initialize Knowledge Base client
    try:
        if os.getenv("BEDROCK_KNOWLEDGE_BASE_ID"):
            kb_client = KnowledgeBaseClient()
            kb_client.initialize()
            logger.info("Knowledge Base client initialized successfully")
        else:
            logger.warning("BEDROCK_KNOWLEDGE_BASE_ID not found. Knowledge Base integration disabled.")
    except Exception as e:
        logger.error(f"Failed to initialize Knowledge Base client: {e}")
        kb_client = None
    
    yield
    
    # Shutdown
    if asana_client:
        await asana_client.close()
        logger.info("Asana MCP client closed")

app = FastAPI(lifespan=lifespan)

class Query(BaseModel):
    prompt: str


async def handle_asana_query(query: str, chat_model):
    """Handle Asana-related queries using MCP tools"""
    if not asana_client:
        return "Asana統合が設定されていません。ASANA_ACCESS_TOKENを設定してください。"
    
    try:
        # Get Asana tools
        tools = await asana_client.get_tools()
        
        # Create specialized Asana agent
        agent = create_asana_agent(chat_model, tools)
        
        # Execute the query using helper function
        response = await execute_asana_query(agent, query)
        
        return response
            
    except Exception as e:
        logger.error(f"Error handling Asana query: {e}")
        return f"Asanaクエリの処理中にエラーが発生しました: {str(e)}"


async def handle_knowledge_base_query(query: str, chat_model):
    """Handle knowledge base related queries"""
    if not kb_client:
        return "Knowledge Base統合が設定されていません。BEDROCK_KNOWLEDGE_BASE_IDを設定してください。"
    
    try:
        # Get retriever
        retriever = kb_client.get_retriever()
        
        # Create specialized knowledge base agent
        agent = create_knowledge_base_agent(chat_model, retriever)
        
        # Execute the query
        response = await execute_knowledge_base_query(agent, query)
        
        return response
        
    except Exception as e:
        logger.error(f"Error handling knowledge base query: {e}")
        return f"文書検索中にエラーが発生しました: {str(e)}"


async def handle_general_query(query: str, chat_model):
    """Handle general queries using the base LLM"""
    ai_msg = await chat_model.ainvoke([HumanMessage(content=query)])
    return ai_msg.content


@app.post("/generate")
async def generate(query: Query):
    """
    Generate response based on query type:
    - Asana-related queries: Use Asana MCP tools
    - General queries: Use Nova Pro directly
    """
    try:
        # Initialize chat model
        chat = ChatBedrock(
            model="us.amazon.nova-pro-v1:0",
            region_name=os.getenv("AWS_REGION", "us-west-2"),
            beta_use_converse_api=True
        )
        
        # Determine query type and route accordingly
        if is_asana_related_query(query.prompt):
            logger.info(f"Detected Asana-related query: {query.prompt}")
            response = await handle_asana_query(query.prompt, chat)
        elif is_knowledge_base_query(query.prompt):
            logger.info(f"Detected knowledge base query: {query.prompt}")
            response = await handle_knowledge_base_query(query.prompt, chat)
        else:
            logger.info(f"Handling general query: {query.prompt}")
            response = await handle_general_query(query.prompt, chat)
        
        return {"response": response}
        
    except Exception as e:
        logger.error(f"Error generating response: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    """Health check endpoint"""
    status = {
        "message": "Yapodu LangChain API",
        "asana_integration": "enabled" if asana_client else "disabled",
        "knowledge_base_integration": "enabled" if kb_client else "disabled"
    }
    return status


@app.get("/health")
async def health():
    """Detailed health check"""
    return {
        "status": "healthy",
        "services": {
            "asana_mcp": {
                "enabled": bool(asana_client),
                "connected": bool(asana_client and asana_client.tools)
            },
            "knowledge_base": {
                "enabled": bool(kb_client),
                "connected": bool(kb_client and kb_client.retriever)
            }
        }
    }