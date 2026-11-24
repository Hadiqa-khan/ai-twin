data "aws_caller_identity" "me" {}
data "aws_region" "current" {}

locals {
  api = "AWS API Call via CloudTrail"
  rules = {
    guardduty-findings = {
      source        = ["aws.guardduty"]
      "detail-type" = ["GuardDuty Finding"]
    }
    access-analyzer-findings = {
      source        = ["aws.access-analyzer"]
      "detail-type" = ["Access Analyzer Finding"]
    }
    cloudtrail-tampering = {
      source        = ["aws.cloudtrail"]
      "detail-type" = [local.api]
      detail = {
        eventSource = ["cloudtrail.amazonaws.com"]
        eventName   = ["StopLogging", "DeleteTrail", "UpdateTrail", "PutEventSelectors"]
      }
    }
    flowlog-tampering = {
      source        = ["aws.ec2"]
      "detail-type" = [local.api]
      detail = {
        eventSource = ["ec2.amazonaws.com"]
        eventName   = ["DeleteFlowLogs"]
      }
    }
    s3-policy-change = {
      source        = ["aws.s3"]
      "detail-type" = [local.api]
      detail = {
        eventSource = ["s3.amazonaws.com"]
        eventName = ["PutBucketPolicy", "DeleteBucketPolicy", "PutBucketAcl",
          "PutBucketPublicAccessBlock", "DeleteBucketPublicAccessBlock",
        "PutAccountPublicAccessBlock", "DeleteAccountPublicAccessBlock"]
      }
    }
    detection-tampering = {
      source        = ["aws.events", "aws.guardduty", "aws.sns", "aws.logs", "aws.monitoring"]
      "detail-type" = [local.api]
      detail = {
        eventName = [
          "DeleteRule", "DisableRule", "RemoveTargets",
          "DeleteDetector", "UpdateDetector",
          "Unsubscribe", "DeleteTopic",
          "DeleteLogGroup", "DeleteMetricFilter",
          "DeleteAlarms", "DisableAlarmActions"
        ]
      }
    }
  }
}
#trivy:ignore:AWS-0095  (EventBridge and CloudWatch alarms can't publish to a topic using the AWS-managed SNS key; CMK is on the roadmap)
resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:EventBridge cannot publish to a topic encrypted with the AWS-managed SNS key; CMK is on the roadmap
  name = "${var.project}-security-alerts"
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "AllowEventBridgeRulesFromThisProject"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:events:${data.aws_region.current.region}:${data.aws_caller_identity.me.account_id}:rule/${var.project}-*"]
    }
  }
  statement {
    sid       = "AllowCloudWatchAlarmsFromThisProject"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.me.account_id}:alarm:${var.project}-*"
      ]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "this" {
  for_each      = local.rules
  name          = "${var.project}-${each.key}"
  description   = "Detection: ${each.key}"
  event_pattern = jsonencode(each.value)
  state         = "ENABLED"
}

resource "aws_cloudwatch_event_target" "sns" {
  for_each  = aws_cloudwatch_event_rule.this
  rule      = each.value.name
  target_id = "sns-email"
  arn       = aws_sns_topic.alerts.arn
}

# IAM delivers its events to EventBridge only in us-east-1, so outside that region an EventBridge
# rule for IAM never fires. Instead: the trail's copy in CloudWatch Logs -> metric filter -> alarm -> same topic.

resource "aws_cloudwatch_log_metric_filter" "iam_persistence" {
  name           = "${var.project}-iam-persistence"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{ ($.eventSource = \"iam.amazonaws.com\") && (($.eventName = \"CreateUser\") || ($.eventName = \"CreateAccessKey\") || ($.eventName = \"CreateLoginProfile\") || ($.eventName = \"AttachUserPolicy\") || ($.eventName = \"PutUserPolicy\") || ($.eventName = \"AddUserToGroup\") || ($.eventName = \"CreateRole\") || ($.eventName = \"UpdateAssumeRolePolicy\") || ($.eventName = \"AttachRolePolicy\")) }"

  metric_transformation {
    name      = "IamPersistenceEvents"
    namespace = "${var.project}/Detection"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "iam_persistence" {
  alarm_name          = "${var.project}-iam-persistence"
  alarm_description   = "Detection: IAM User, Access Key, Login profile created or Policy attached to a user"
  namespace           = "${var.project}/Detection"
  metric_name         = "IamPersistenceEvents"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
