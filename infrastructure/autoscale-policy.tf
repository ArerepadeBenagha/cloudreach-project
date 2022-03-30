# scale up alarm

resource "aws_autoscaling_policy" "cloudreach-cpu-policy" {
  name                   = "cloudreach-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.cloudreach-autoscaling.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cloudreach-cpu-alarm" {
  alarm_name          = "cloudreach-cpu-alarm"
  alarm_description   = "cloudreach-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.cloudreach-autoscaling.name
  }

  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.cloudreach-cpu-policy.arn]
}

# scale down alarm
resource "aws_autoscaling_policy" "cloudreach-cpu-policy-scaledown" {
  name                   = "cloudreach-cpu-policy-scaledown"
  autoscaling_group_name = aws_autoscaling_group.cloudreach-autoscaling.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cloudreach-cpu-alarm-scaledown" {
  alarm_name          = "cloudreach-cpu-alarm-scaledown"
  alarm_description   = "cloudreach-cpu-alarm-scaledown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5"

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.cloudreach-autoscaling.name
  }

  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.cloudreach-cpu-policy-scaledown.arn]
}

resource "aws_sns_topic" "cloudreach-sns" {
  name         = "sg-sns"
  display_name = "cloudreach ASG SNS topic"
} # email subscription is currently unsupported in terraform and can be done using the AWS Web Console

resource "aws_autoscaling_notification" "cloudreach-notify" {
  group_names = ["${aws_autoscaling_group.cloudreach-autoscaling.name}"]
  topic_arn   = aws_sns_topic.cloudreach-sns.arn
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
  ]
}