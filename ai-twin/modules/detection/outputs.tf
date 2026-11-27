output "topic_arn" {
  description = "ARN of the primary alert topic. It is only available once its access policy and email subscription are in place. Tamper alerts also go to the <project>-alerts-backup topic."
  value       = aws_sns_topic.this["primary"].arn

  depends_on = [
    aws_sns_topic_policy.this,
    aws_sns_topic_subscription.email,
  ]
}

output "rule_names" {
  description = "Names of the EventBridge rules this module creates."
  value       = [for rule in aws_cloudwatch_event_rule.this : rule.name]

  depends_on = [aws_cloudwatch_event_target.this]
}

output "alarm_names" {
  description = "Names of the CloudWatch alarms this module creates."
  value       = [for alarm in aws_cloudwatch_metric_alarm.this : alarm.alarm_name]
}
