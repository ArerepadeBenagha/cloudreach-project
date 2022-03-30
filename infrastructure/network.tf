resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = "true"

  tags = merge(local.common_tags, { Name = "cloudreach", Company = "cloudreach" })
}

////subnet - public
resource "aws_subnet" "main-public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = local.common_tags
}

resource "aws_subnet" "main-public-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = local.common_tags
}
////subnet - private
resource "aws_subnet" "main-private-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags              = local.common_tags
}

resource "aws_subnet" "main-private-2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"
  tags              = local.common_tags
}

///igw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

////route table
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = local.common_tags
}

///subnet association
resource "aws_route_table_association" "rtb-public" {
  subnet_id      = aws_subnet.main-public.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rtb-public-1" {
  subnet_id      = aws_subnet.main-public-1.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rtb-private-1" {
  subnet_id      = aws_subnet.main-private-1.id
  route_table_id = aws_route_table.rtb.id
}

resource "aws_route_table_association" "rtb-private-2" {
  subnet_id      = aws_subnet.main-private-2.id
  route_table_id = aws_route_table.rtb.id
}

/////sg
resource "aws_security_group" "server-sg" {
  vpc_id      = aws_vpc.main.id
  name        = "server-sg"
  description = "security group that allows ssh and all egress traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

    ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

    ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  tags = {
    Name = "server-sg"
  }
}

resource "aws_security_group" "bastion" {
  vpc_id      = aws_vpc.main.id
  name        = "bastion"
  description = "security group that allows bastion traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

resource "aws_security_group" "alb" {
  vpc_id      = aws_vpc.main.id
  name        = "alb"
  description = "security group that allows alb traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "alb-sg"
  }
}