output "trail_arn" {
  value = aws_cloudtrail.main.arn
}
output "guardduty_detector_id" {
  value = one(aws_guardduty_detector.this[*].id)
}
output "cloudtrail_log_group_name" {
  value = aws_cloudwatch_log_group.trail.name
}
