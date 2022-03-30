resource "aws_key_pair" "mykeypair" {
  key_name   = "mykeypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDKO9Sk/+ne0YxuZmXPZiuOvgAMjwhQ3dFUZsmPOo45ft06++U4nKwY0qPwehANkbfnHoBjkiU6wZwuJY73cxV/iLI1wpbWtBcWw1T2nB8HaI9Kg01XkIakQnZFikfa9Bpm9dH9cPKuoENH3IkmYSGD2Z8otG3xfw29ylvdZVKeIQu9qkbtzNIyU3d2UNfeVHGtadXxzbs9RtKTyv4FlL+7wFmoz/R4zTNGVQ3HPd9zt5m9pcTdVQoBr7pf/CAYvHQpgs4IyxagC/X7rxoFbbUy7r9bb0i6M5kTPsrQ59mTbd/lG/lYL0HKzpvysJPyJLu3+RTegK0arPNilRIaM9D/XAwG7eAam9kLZZ0RLT6hOudrTOlNTzUYvhqNMVrFbrauOPMPMb2YehXXpXXNGPwx84iIJXF0l3ughNd36bM1SHPtZoqzMpXiJxDEmxYKc6fh/jAs/JJCeQd5gePfrPav1CsGvOAF7FlSiNZ761EQ8zLLo9Hm8qtXEqu1D3fmgRk= lbena@LAPTOP-QB0DU4OG"
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_launch_configuration" "cloudreach-launchconfig" {
  name_prefix     = "cloudreach-launchconfig"
  image_id        = var.AMIS[var.AWS_REGION]
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.mykeypair.key_name
  security_groups = [aws_security_group.server-sg.id]

  root_block_device {
    volume_size = 155
    volume_type = "gp2"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "cloudreach-autoscaling" {
  name                      = "cloudreach-autoscaling"
  vpc_zone_identifier       = [aws_subnet.main-private-1.id, aws_subnet.main-private-2.id]
  launch_configuration      = aws_launch_configuration.cloudreach-launchconfig.name
  target_group_arns         = [aws_lb_target_group.cloudreachwork_8080.arn]
  min_size                  = 1
  max_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true


  tag {
    key                 = "Name"
    value               = "cloudreach-instance"
    propagate_at_launch = true
  }
}

################################################
# Load Balancing
################################################
resource "aws_lb" "cloudreachwork_lb" {
  name               = "cloudreachwork-${var.app_tier}"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.server-sg.id,
    aws_security_group.alb.id
  ]

  subnets = [aws_subnet.main-public.id, aws_subnet.main-public-1.id]
  tags    = merge({ Name = "cloudreachwork-${var.app_tier}" }, local.common_tags)
}

resource "aws_lb_target_group" "cloudreachwork_8080" {
  name     = "cloudreachwork-8080-${var.app_tier}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/_health_check"
    protocol            = "HTTPS"
    matcher             = 200
    healthy_threshold   = 5
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
  }

  tags = merge(
    { Name = "cloudreachwork-8080-${var.app_tier}" },
    { Description = "ALB Target Group for web application HTTPS traffic" },
    local.common_tags
  )
}