resource "aws_db_subnet_group" "cloudreachqlsubnet" {
  name = join("-", [local.network.Environment, "cloudreachsubnet"])

  subnet_ids = [aws_subnet.main-private-1.id, aws_subnet.main-private-2.id]

  tags = merge(local.common_tags, { Name = "cloudreachsubnet", Company = "cloudreach" })
}

resource "random_id" "db" {
  byte_length = 8
}

resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_+=[]<>:?"
}

resource "aws_db_parameter_group" "cloudreachsubnet_param" {
  name   = join("-", [local.network.Environment, "cloudreachsubnet-param"])
  family = "mysql5.7"

  #   parameter {
  #       name = "character_set_client"
  #       value = "utf8mb4"
  #   }
}

resource "aws_db_instance" "cloudreachdb" {
  allocated_storage       = 10 #100 GB of storage, gives us more IOPS than a lower number
  engine                  = "mysql"
  engine_version          = "5.7"
  instance_class          = "db.t3.micro" #use micro if you want to use the free tier
  identifier              = "cloudreach"
  name                    = "cloudreachadmin"
  username                = "cloudreachadminuser" #username
  password                = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.cloudreachqlsubnet.name
  parameter_group_name    = aws_db_parameter_group.cloudreachsubnet_param.name
  multi_az                = false #set to true to have high availability: 2 instances synchronized with each other
  vpc_security_group_ids  = [aws_security_group.server-sg.id]
  storage_type            = "gp2"
  backup_retention_period = 30                                          #how long you’re going to keep your backups
  availability_zone       = aws_subnet.main-private-1.availability_zone # prefered AZ
  skip_final_snapshot     = true
  publicly_accessible     = false #skip final snapshot when doing terraform destroy
  tags                    = merge(local.common_tags, { Name = "cloudreachdb", Company = "cloudreach" })
}