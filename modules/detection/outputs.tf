output "topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "rule_names" {
  value = [for r in aws_cloudwatch_event_rule.this : r.name]
}

output "alarm_names" {
  value = [aws_cloudwatch_metric_alarm.iam_persistence.alarm_name]
}
