locals {
  default_region = "us-west-2"
  ecr_repositories = [
    "ypd-langchain-bot",
  ]
}


provider "aws" {
  region = local.default_region
  default_tags {
    tags = {
      Environment = "dev"
      Managed     = "terraform"
    }
  }
}

terraform {
  required_version = "~> 1.12.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.3.0"
    }
  }
}

locals {
  # Main Prefix
  prefix = "ypd"

  # Environment
  env = "dev"

  # VPC  
  main_vpc_name = "${local.prefix}-${local.env}-vpc"
  main_vpc_az1  = "us-west-2a"
  main_vpc_az2  = "us-west-2b"
  main_vpc_az3  = "us-west-2c"
  private_isolated_subnets = [
    aws_subnet.main_vpc_sbn_pri_isl1.id,
    aws_subnet.main_vpc_sbn_pri_isl2.id,
    aws_subnet.main_vpc_sbn_pri_isl3.id,
  ]

  ## OpenSearch Serverless
  #  ossl_collection_name = "${local.prefix}-${local.env}-collection"
  #  ossl_enctyption_security_policy_name = "${local.prefix}-${local.env}-encryption-policy"
  #  ossl_network_security_policy_name = "${local.prefix}-${local.env}-network-policy"
  #  ossl_vpc_ep_name = "${local.prefix}-${local.env}-vpc-endpoint"

  # Aurora IAM Role
  rds_monitoring_role_name = "${local.prefix}-${local.env}-rds-monitoring-role"

  # Aurora main_db
  main_db_aurora_name_with_env   = "${local.prefix}-${local.env}-aurora-main"
  main_db_rdsproxy_name_with_env = "${local.prefix}-${local.env}-rdsproxy-main"
  main_db_rdsproxy_name_dev_user = "${local.prefix}-${local.env}-rdsproxy-dev-user"

  # Aurora cluster main_db
  main_db_aurora_cluster_parameter_group_name           = "${local.prefix}-${local.env}-aurora-main-cluster-parameter-group"
  main_db_aurora_cluster_identifier                     = "${local.prefix}-${local.env}-aurora-main-cluster"
  main_db_aurora_cluster_engine_version                 = "16.8"
  main_db_aurora_cluster_availability_zones             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  main_db_aurora_cluster_database_name                  = "main_db"
  main_db_aurora_cluster_master_username                = "ypodu_pdadmin"
  main_db_aurora_cluster_enable_http_endpoint           = true # Knowledge Base での利用時は true にする
  main_db_aurora_cluster_backup_retention_period        = 7
  main_db_aurora_cluster_preferred_backup_window        = "15:58-16:28"
  main_db_aurora_cluster_prmaint_window                 = "thu:18:00-thu:18:30"
  main_db_01_aurora_instance_identifier                 = "${local.prefix}-${local.env}-aurora-main"
  main_db_01_aurora_instance_instance_class             = "db.serverless" # NOTE: tg4 系では RDS DATA API は利用不可のた serverless を指定
  main_db_01_aurora_instance_auto_minor_version_upgrade = true
  main_db_01_aurora_instance_prmaint_window             = "wed:18:00-wed:18:30"
  main_db_02_aurora_instance_identifier                 = "${local.prefix}-${local.env}-aurora-main-ap-northeast-1c"
  main_db_02_aurora_instance_instance_class             = "db.serverless"

  # S3
  knowledgebase_bucket_name = "${local.prefix}-${local.env}-knowledgebase-bucket"

  # Bedrock IAM Role
  bedrock_role_name   = "${local.prefix}-${local.env}-knowledgebase-role"
  bedrock_policy_name = "${local.prefix}-${local.env}-knowledgebase-policy"

  # Bedrock Knowledge Base
  bedrock_knowledge_base_name         = "${local.prefix}-${local.env}-knowledge-base"
  bedrock_knowledge_base_description  = "Knowledge Base for ${local.prefix} ${local.env} environment using Aurora PostgreSQL"
  bedrock_knowledge_base_table_name   = "bedrock_knowledge_base"
  bedrock_knowledge_base_dsource_name = "${local.prefix}-${local.env}-kb-src-s3"

  # ECR
  # 
  add_envfile_bucket_name   = "add-envfile-${data.aws_caller_identity.current.account_id}"
  ypd_aws_github_repository = "yapodu-inc/ypd-langchain-assistant"
  add_github_repositories = [
    "yapodu-inc/ypd-langchain-app",
  ]


  # ECS
  # ypd_langchain
  ypd_langchain_app_name              = "${local.prefix}-${local.env}-add-langchain"
  ypd_langchain_default_image_tag     = "latest" # NOTE: ハンズオン環境では latest を利用
  ypd_langchain_allow_cidrs           = ["0.0.0.0/0"]
  ypd_langchain_task_cpu_size         = 512  # NOTE: 0.5 vCPU
  ypd_langchain_task_memory_size      = 1024 # NOTE: 1 GiB
  ypd_langchain_container_memory_size = 512  # NOTE: 512 Mi
  ypd_langchain_desired_count         = 1
}

# Healthcheck Cidrs
locals {
  # uptime robot healthcheck cidrs
  healthcheck_cidrs = ["0.0.0.0/0"]
}