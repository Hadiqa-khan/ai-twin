output "ci_plan_role_arn" {
  value = module.iam.ci_plan_role_arn
}
output "auditor_role_arn" {
  value = module.iam.auditor_role_arn
}
output "vpc_id" {
  value = module.network.vpc_id
}
output "trail_arn" {
  value = module.foundation.trail_arn
}
output "guardduty_detector_id" {
  value = module.foundation.guardduty_detector_id
}
output "alerts_topic_arn" {
  # one() returns null when detection is off (count = 0) but still errors on a typo, unlike try()
  value = one(module.detection[*].topic_arn)
}
