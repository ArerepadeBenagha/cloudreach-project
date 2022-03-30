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

resource "aws_lb_listener" "cloureach_443" {
  load_balancer_arn = aws_lb.cloudreachwork_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cloudreach_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloudreachwork_8080.arn
  }
}

resource "aws_lb_listener" "cloureach_8080_rd" {
  load_balancer_arn = aws_lb.cloudreachwork_lb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#####------ Certificate -----------####
resource "aws_acm_certificate" "cloudreach_cert" {
  domain_name       = "*.elitelabtools.com"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(local.common_tags,
    { Name = "cloudreachserver.elitelabtools.com"
  Cert = "cloureach" })
}

###------- Cert Validation -------###
###-------------------------------###
data "aws_route53_zone" "primary" {
  name = "elitelabtools.com"
}
resource "aws_route53_record" "cloudreach_record" {
  for_each = {
    for dvo in aws_acm_certificate.cloudreach_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "cloudreach_cert" {
  certificate_arn         = aws_acm_certificate.cloudreach_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudreach_record : record.fqdn]
}

# ##------- ALB Alias record ----------##
###-----------------------------------###
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "cloudreachserver.elitelabtools.com"
  type    = "A"

  alias {
    name                   = aws_lb.cloudreachwork_lb.dns_name
    zone_id                = aws_lb.cloudreachwork_lb.zone_id
    evaluate_target_health = true
  }
}