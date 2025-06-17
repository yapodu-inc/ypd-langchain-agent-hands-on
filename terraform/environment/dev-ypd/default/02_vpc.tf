# ================================================================
# VCP
# ================================================================

resource "aws_vpc" "main_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = local.main_vpc_name
  }
}

# ================================================================
# ECS Subnet
# ================================================================

resource "aws_subnet" "main_vpc_sbn_pub_ecs1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = local.main_vpc_az1

  tags = {
    Name = "${local.main_vpc_name}-sbn-pub-ecs1"
  }
}

resource "aws_subnet" "main_vpc_sbn_pub_ecs2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.2.0/24"
  availability_zone = local.main_vpc_az2

  tags = {
    Name = "${local.main_vpc_name}-sbn-pub-ecs2"
  }
}

resource "aws_subnet" "main_vpc_sbn_pub_ecs3" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.3.0/24"
  availability_zone = local.main_vpc_az3

  tags = {
    Name = "${local.main_vpc_name}-sbn-pub-ecs3"
  }
}

resource "aws_subnet" "main_vpc_sbn_pri_ecs1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.11.0/24"
  availability_zone = local.main_vpc_az1

  tags = {
    Name = "${local.main_vpc_name}-sbn-pri-ecs1"
  }
}

resource "aws_subnet" "main_vpc_sbn_pri_ecs2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.12.0/24"
  availability_zone = local.main_vpc_az2

  tags = {
    Name = "${local.main_vpc_name}-sbn-pri-ecs2"
  }
}

resource "aws_subnet" "main_vpc_sbn_pri_ecs3" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.13.0/24"
  availability_zone = local.main_vpc_az3

  tags = {
    Name = "${local.main_vpc_name}-sbn-pri-ecs3"
  }
}

# ================================================================
# Isolated Subnet
# ================================================================

resource "aws_subnet" "main_vpc_sbn_pri_isl1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.21.0/24"
  availability_zone = local.main_vpc_az1

  tags = {
    Name = "${local.main_vpc_name}-sbn-pri-isl1"
  }
}

resource "aws_subnet" "main_vpc_sbn_pri_isl2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.22.0/24"
  availability_zone = local.main_vpc_az2

  tags = {
    Name = "${local.main_vpc_name}-sbn-pri-isl2"
  }
}

resource "aws_subnet" "main_vpc_sbn_pri_isl3" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.16.23.0/24"
  availability_zone = local.main_vpc_az3

  tags = {
    Name = "${local.main_vpc_name}-sbn-pri-isl3"
  }
}

# ================================================================
# Route Table
# ================================================================

resource "aws_route_table" "main_vpc_rt_pub" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_vpc_igw.id
  }

  tags = {
    Name = "${local.main_vpc_name}-rt-pub"
  }
}


resource "aws_route_table" "main_vpc_rt_pri" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_vpc_ngw.id
  }

  tags = {
    Name = "${local.main_vpc_name}-rt-pri"
  }
}

resource "aws_route_table" "main_vpc_rt_pri2" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_vpc_ngw2.id
  }

  tags = {
    Name = "${local.main_vpc_name}-rt-pri2"
  }
}

resource "aws_route_table_association" "main_vpc_rta_pub_ecs1" {
  subnet_id      = aws_subnet.main_vpc_sbn_pub_ecs1.id
  route_table_id = aws_route_table.main_vpc_rt_pub.id
}

resource "aws_route_table_association" "main_vpc_sbn_pub_ecs2" {
  subnet_id      = aws_subnet.main_vpc_sbn_pub_ecs2.id
  route_table_id = aws_route_table.main_vpc_rt_pub.id
}

resource "aws_route_table_association" "main_vpc_sbn_pub_ecs3" {
  subnet_id      = aws_subnet.main_vpc_sbn_pub_ecs3.id
  route_table_id = aws_route_table.main_vpc_rt_pub.id
}

resource "aws_route_table_association" "main_vpc_rta_pri_ecs1" {
  subnet_id      = aws_subnet.main_vpc_sbn_pri_ecs1.id
  route_table_id = aws_route_table.main_vpc_rt_pri.id
}

resource "aws_route_table_association" "main_vpc_rta_pri_ecs2" {
  subnet_id      = aws_subnet.main_vpc_sbn_pri_ecs2.id
  route_table_id = aws_route_table.main_vpc_rt_pri2.id
}

resource "aws_route_table_association" "main_vpc_rta_pri_ecs3" {
  subnet_id      = aws_subnet.main_vpc_sbn_pri_ecs3.id
  route_table_id = aws_route_table.main_vpc_rt_pri.id
}

# ================================================================
# Internet Gateway and NAT Gateway
# ================================================================
resource "aws_internet_gateway" "main_vpc_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${local.main_vpc_name}-igw"
  }

}

resource "aws_eip" "main_vpc_nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main_vpc_ngw" {
  allocation_id = aws_eip.main_vpc_nat.id
  subnet_id     = aws_subnet.main_vpc_sbn_pub_ecs1.id

  tags = {
    Name = "${local.main_vpc_name}-ngw"
  }
}

resource "aws_eip" "main_vpc_nat2" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main_vpc_ngw2" {
  allocation_id = aws_eip.main_vpc_nat2.id
  subnet_id     = aws_subnet.main_vpc_sbn_pub_ecs2.id

  tags = {
    Name = "${local.main_vpc_name}-ngw2"
  }
}