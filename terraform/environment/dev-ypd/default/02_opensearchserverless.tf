# 今回は未使用
# Aurora Postgres pgvector ではなく OpenSearch を使用する際はコメント解除

## https://aws.amazon.com/jp/blogs/big-data/deploy-amazon-opensearch-serverless-with-terraform/
#
## Creates an encryption security policy
#resource "aws_opensearchserverless_security_policy" "encryption_policy" {
#  name = local.ossl_enctyption_security_policy_name
#  description = "Encryption policy for OpenSearch Serverless"
#  type = "encryption"
#  policy = jsonencode({
#    Rules = [
#      {
#        Resource = [
#          "collection/${local.ossl_collection_name}"
#        ],
#        ResourceType = "collection"
#      }
#    ],
#    AWSOwnedKey = true
#  })
#}
#
## Creates a collection
#resource "aws_opensearchserverless_collection" "collection" {
#  name             = local.ossl_collection_name
#  type             = "VECTORSEARCH"
#  standby_replicas = "DISABLED"
#
#  depends_on = [aws_opensearchserverless_security_policy.encryption_policy]
#}
#
## Creates a network security policy
#resource "aws_opensearchserverless_security_policy" "network_policy" {
#    name = local.ossl_network_security_policy_name
#    description = "Network policy for OpenSearch Serverless"
#    type = "network"
#  policy = jsonencode([
#    {
#      Description = "VPC access for collection endpoint",
#      Rules = [
#        {
#          ResourceType = "collection",
#          Resource = [
#            "collection/${local.ossl_collection_name}"
#          ]
#        }
#      ],
#      AllowFromPublic = false,
#      SourceVPCEs = [
#        aws_opensearchserverless_vpc_endpoint.vpc_endpoint.id
#      ]
#    },
#    {
#      Description = "Public access for dashboards",
#      Rules = [
#        {
#          ResourceType = "dashboard"
#          Resource = [
#            "collection/${local.ossl_collection_name}"
#          ]
#        }
#      ],
#      AllowFromPublic = true
#    }
#  ])
#}
#
## Creates a VPC endpoint for OpenSearch Serverless
#resource "aws_opensearchserverless_vpc_endpoint" "vpc_endpoint" {
#  name               = local.ossl_vpc_ep_name
#  vpc_id             = aws_vpc.main_vpc.id
#  subnet_ids         = [aws_subnet.main_vpc_sbn_pri_ecs1.id, aws_subnet.main_vpc_sbn_pri_ecs2.id, aws_subnet.main_vpc_sbn_pri_ecs3.id]
#  security_group_ids = [aws_security_group.ecs_ossl_ep_sg.id]
#}
#
#data "aws_caller_identity" "current" {}
#
## Creates a data access policy
#resource "aws_opensearchserverless_access_policy" "data_access_policy" {
#  name        = "example-data-access-policy"
#  type        = "data"
#  description = "allow index and collection access"
#  policy = jsonencode([
#    {
#      Rules = [
#        {
#          ResourceType = "index",
#          Resource = [
#            "index/${local.ossl_collection_name}/*"
#          ],
#          Permission = [
#            "aoss:*"
#          ]
#        },
#        {
#          ResourceType = "collection",
#          Resource = [
#            "collection/${local.ossl_collection_name}"
#          ],
#          Permission = [
#            "aoss:*"
#          ]
#        }
#      ],
#      Principal = [
#        data.aws_caller_identity.current.arn
#      ]
#    }
#  ])
#}