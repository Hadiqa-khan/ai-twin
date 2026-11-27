output "trail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.this.arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector in this region."
  value       = aws_guardduty_detector.this.id
}

output "cloudtrail_log_group_name" {
  description = "Name of the CloudWatch Logs group that receives the trail. It is only available once the trail is delivering to it."
  value       = aws_cloudwatch_log_group.cloudtrail.name

  depends_on = [aws_cloudtrail.this]
}
