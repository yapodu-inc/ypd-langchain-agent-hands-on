# ================================================================
# SecurityGroup / RDS
# ================================================================

# NOTE: RDS 本体と に付与する
resource "aws_security_group" "main_db" {
  name        = local.main_db_aurora_name_with_env
  description = "Managed by Terraform."
  vpc_id      = aws_vpc.main_vpc.id
  tags = {
    Name = local.main_db_aurora_name_with_env
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "all"
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_ossl_ep_sg.id]
  }
}

# ================================================================
# IAM / RDS Monitoring
# ================================================================

data "aws_iam_policy" "rds_monitoring" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_iam_policy_document" "rds_monitoring" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = local.rds_monitoring_role_name
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = data.aws_iam_policy.rds_monitoring.arn
}

# ================================================================
# RDS Aurora
# ================================================================

resource "aws_db_subnet_group" "main_vpc_aurora_subnet_group" {
  name       = "${local.main_vpc_name}-rds-subnet-group"
  subnet_ids = local.private_isolated_subnets
}

resource "aws_rds_cluster_parameter_group" "main_db" {
  name        = local.main_db_aurora_cluster_parameter_group_name
  family      = "aurora-postgresql16"
  description = "Managed by Terraform."

  parameter {
    name  = "log_statement"
    value = "ddl" # ログにDDLを記録
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "5000" # 5秒以上かかるクエリをログに記録
  }

}

resource "aws_rds_cluster" "main_db" {
  deletion_protection = false # 本番環境では true にすること
  cluster_identifier  = local.main_db_aurora_cluster_identifier
  engine              = "aurora-postgresql"
  engine_version      = local.main_db_aurora_cluster_engine_version
  engine_mode         = "provisioned" # serverlessv2
  serverlessv2_scaling_configuration {
    min_capacity = 0.5 # ACU
    max_capacity = 4
  }
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main_db.name
  availability_zones              = local.main_db_aurora_cluster_availability_zones
  vpc_security_group_ids          = [aws_security_group.main_db.id]
  db_subnet_group_name            = aws_db_subnet_group.main_vpc_aurora_subnet_group.name
  enable_http_endpoint            = local.main_db_aurora_cluster_enable_http_endpoint
  database_name                   = local.main_db_aurora_cluster_database_name
  master_username                 = local.main_db_aurora_cluster_master_username
  #master_password = local.main_db_aurora_cluster_master_password
  manage_master_user_password     = true # マスターユーザーパスワードをSecrets Managerに管理させて定期的にパスワードをローテーション 自動的にSecret名を生成し、ユーザーが直接制御することはできない
  storage_encrypted               = true
  backup_retention_period         = local.main_db_aurora_cluster_backup_retention_period
  preferred_backup_window         = local.main_db_aurora_cluster_preferred_backup_window
  skip_final_snapshot             = true # 検証環境のため取得なし
  copy_tags_to_snapshot           = true
  enable_global_write_forwarding  = false
  enabled_cloudwatch_logs_exports = ["postgresql"]
  preferred_maintenance_window    = local.main_db_aurora_cluster_prmaint_window


}
resource "aws_rds_cluster_instance" "main_db_01" {
  identifier                            = local.main_db_01_aurora_instance_identifier
  cluster_identifier                    = aws_rds_cluster.main_db.id
  instance_class                        = local.main_db_01_aurora_instance_instance_class
  engine                                = aws_rds_cluster.main_db.engine
  engine_version                        = aws_rds_cluster.main_db.engine_version
  auto_minor_version_upgrade            = local.main_db_01_aurora_instance_auto_minor_version_upgrade # 自動バージョンアップ
  promotion_tier                        = 1
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  preferred_maintenance_window          = local.main_db_01_aurora_instance_prmaint_window
}
### Dev 環境の Cluster は 1 台で構成する
#resource "aws_rds_cluster_instance" "main_db_02" {
#  identifier                            = local.main_db_02_aurora_instance_identifier
#  cluster_identifier                    = aws_rds_cluster.main_db.id
#  instance_class                        = local.main_db_02_aurora_instance_instance_class
#  engine                                = aws_rds_cluster.main_db.engine
#  engine_version                        = aws_rds_cluster.main_db.engine_version
#  auto_minor_version_upgrade            = false
#  promotion_tier                        = 1
#  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
#  monitoring_interval                   = 60
#  performance_insights_enabled          = true
#  performance_insights_retention_period = 7
#}