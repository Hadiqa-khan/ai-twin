data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

# How detection works
#
# 1. CloudTrail metric filters + alarms. These read the CloudTrail log group,
#    which receives events from every region and from global services such as
#    IAM. IAM events only reach EventBridge in us-east-1, so an EventBridge rule
#    in ap-southeast-2 would never see them. This path covers IAM, S3,
#    flow-log and trail changes anywhere, plus tampering with this module's
#    EventBridge rules and alert topics.
#
# 2. EventBridge rules in this region. These cover GuardDuty and Access
#    Analyzer findings, plus tampering with the metric-filter path (the log
#    group, its metric filters and the alarms), the trail, the topics, the
#    detector and the analyzer.
#
# Each path watches the other, so neither can be quietly switched off.
#
# Alerts about tampering go to two topics, each with its own email
# subscription. Deleting or unsubscribing one topic still alerts through the
# other.

locals {
  p          = var.project
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  topics = {
    primary = "${local.p}-alerts"
    backup  = "${local.p}-alerts-backup"
  }

  # Matches both topics and their subscriptions ("<topic arn>:<id>").
  topic_arn_prefix = "arn:${local.partition}:sns:${local.region}:${local.account_id}:${local.p}-alerts"

  calls = {
    trail = ["StopLogging", "DeleteTrail", "UpdateTrail", "PutEventSelectors"]
    iam = [
      "CreateUser",
      "CreateAccessKey",
      "CreateLoginProfile",
      "AttachUserPolicy",
      "PutUserPolicy",
      "AddUserToGroup",
      "CreateRole",
      "UpdateAssumeRolePolicy",
      "AttachRolePolicy",
      "PutRolePolicy",
    ]
    s3 = [
      "PutBucketPolicy",
      "DeleteBucketPolicy",
      "PutBucketAcl",
      "PutBucketPublicAccessBlock",
      "DeleteBucketPublicAccessBlock",
      "PutAccountPublicAccessBlock",
      "DeleteAccountPublicAccessBlock",
    ]
    rule = ["DeleteRule", "DisableRule", "PutRule", "RemoveTargets", "PutTargets"]
    topic = [
      "DeleteTopic",
      "SetTopicAttributes",
      "AddPermission",
      "RemovePermission",
      "Unsubscribe",
      "SetSubscriptionAttributes",
      "PutDataProtectionPolicy",
    ]
    log_group = ["DeleteLogGroup", "DeleteMetricFilter", "PutMetricFilter"]
    detector = [
      "DeleteDetector",
      "UpdateDetector",
      "CreateFilter",
      "UpdateFilter",
      "CreateIPSet",
      "UpdateIPSet",
      "DeletePublishingDestination",
      "DisassociateFromAdministratorAccount",
      "DisassociateFromMasterAccount",
    ]
    analyzer = ["DeleteAnalyzer", "UpdateAnalyzer", "CreateArchiveRule", "UpdateArchiveRule", "ApplyArchiveRule"]
  }

  # "($.eventName = "A") || ($.eventName = "B") || ..." for each list above.
  any_call = {
    for key, names in local.calls :
    key => join(" || ", [for name in names : "($.eventName = \"${name}\")"])
  }

  # -------------------------------------------------------------------------
  # Path 1: metric filters on the CloudTrail log group. tamper = true also
  # sends the alarm to the backup topic.
  # -------------------------------------------------------------------------
  metric_alarms = {
    "trail-changes" = {
      tamper      = true
      description = "CloudTrail logging stopped, or a trail deleted, updated or given new event selectors (any region)."
      pattern     = "{ ($.eventSource = \"cloudtrail.amazonaws.com\") && (${local.any_call.trail}) }"
    }
    "iam-changes" = {
      tamper      = false
      description = "IAM user, access key or login profile created; a policy attached to or put on a user; a user added to a group; or a role created, its trust policy changed, or a policy attached to or put on it."
      pattern     = "{ ($.eventSource = \"iam.amazonaws.com\") && (${local.any_call.iam}) }"
    }
    "flow-logs-deleted" = {
      tamper      = false
      description = "VPC flow logs deleted (any region)."
      pattern     = "{ ($.eventSource = \"ec2.amazonaws.com\") && ($.eventName = \"DeleteFlowLogs\") }"
    }
    "s3-public-access-changes" = {
      tamper      = false
      description = "An S3 bucket policy or ACL changed or deleted, or a bucket's or the account's public access block changed or removed (any region)."
      pattern     = "{ ${local.any_call.s3} }"
    }
    "rule-tampering" = {
      tamper      = true
      description = "One of this module's EventBridge rules or targets was changed, disabled or deleted."
      pattern     = "{ ($.eventSource = \"events.amazonaws.com\") && (${local.any_call.rule}) && (($.requestParameters.name = \"${local.p}-*\") || ($.requestParameters.rule = \"${local.p}-*\")) }"
    }
    "topic-tampering" = {
      tamper      = true
      description = "An alert topic, its access policy or its subscription was changed or removed."
      pattern     = "{ ($.eventSource = \"sns.amazonaws.com\") && (${local.any_call.topic}) && (($.requestParameters.topicArn = \"${local.topic_arn_prefix}*\") || ($.requestParameters.subscriptionArn = \"${local.topic_arn_prefix}*\") || ($.requestParameters.resourceArn = \"${local.topic_arn_prefix}*\")) }"
    }
  }

  # -------------------------------------------------------------------------
  # Path 2: EventBridge rules in this region.
  # -------------------------------------------------------------------------
  api_call = "AWS API Call via CloudTrail"

  event_rules = {
    "guardduty-findings" = {
      tamper      = false
      description = "Any GuardDuty finding."
      pattern = {
        source        = ["aws.guardduty"]
        "detail-type" = ["GuardDuty Finding"]
      }
    }
    "access-analyzer-findings" = {
      tamper      = false
      description = "Any IAM Access Analyzer finding."
      pattern = {
        source        = ["aws.access-analyzer"]
        "detail-type" = ["Access Analyzer Finding"]
      }
    }
    "trail-tampering" = {
      tamper      = true
      description = "CloudTrail logging stopped, or a trail deleted, updated or given new event selectors in this region. This keeps working if the trail stops delivering to CloudWatch Logs."
      pattern = {
        "detail-type" = [local.api_call]
        detail = {
          eventSource = ["cloudtrail.amazonaws.com"]
          eventName   = local.calls.trail
        }
      }
    }
    "log-group-tampering" = {
      tamper      = true
      description = "The CloudTrail log group was deleted, or its metric filters were changed or deleted."
      pattern = {
        "detail-type" = [local.api_call]
        detail = {
          eventSource       = ["logs.amazonaws.com"]
          eventName         = local.calls.log_group
          requestParameters = { logGroupName = [var.cloudtrail_log_group_name] }
        }
      }
    }
    "alarm-tampering" = {
      tamper      = true
      description = "One of this module's CloudWatch alarms was changed, had its actions disabled, or was deleted."
      pattern = {
        "detail-type" = [local.api_call]
        detail = {
          eventSource = ["monitoring.amazonaws.com"]
          "$or" = [
            {
              eventName         = ["DeleteAlarms", "DisableAlarmActions"]
              requestParameters = { alarmNames = [{ prefix = "${local.p}-" }] }
            },
            {
              eventName         = ["PutMetricAlarm"]
              requestParameters = { alarmName = [{ prefix = "${local.p}-" }] }
            },
          ]
        }
      }
    }
    "topic-tampering" = {
      tamper      = true
      description = "An alert topic, its access policy or its subscription was changed or removed."
      pattern = {
        "detail-type" = [local.api_call]
        detail = {
          eventSource = ["sns.amazonaws.com"]
          eventName   = local.calls.topic
          "$or" = [
            { requestParameters = { topicArn = [{ prefix = local.topic_arn_prefix }] } },
            { requestParameters = { subscriptionArn = [{ prefix = local.topic_arn_prefix }] } },
            { requestParameters = { resourceArn = [{ prefix = local.topic_arn_prefix }] } },
          ]
        }
      }
    }
    "detector-tampering" = {
      tamper      = true
      description = "The GuardDuty detector was disabled, changed or deleted, or findings were suppressed (filters or trusted IP lists)."
      pattern = {
        "detail-type" = [local.api_call]
        detail = {
          eventSource = ["guardduty.amazonaws.com"]
          eventName   = local.calls.detector
        }
      }
    }
    "analyzer-tampering" = {
      tamper      = true
      description = "The IAM Access Analyzer was changed or deleted, or findings were archived by rule."
      pattern = {
        "detail-type" = [local.api_call]
        detail = {
          eventSource = ["access-analyzer.amazonaws.com"]
          eventName   = local.calls.analyzer
        }
      }
    }
  }

  # Normal alerts go to the primary topic. Tamper alerts go to both topics.
  event_targets = merge([
    for rule_key, rule in local.event_rules : {
      for topic_key in(rule.tamper ? ["primary", "backup"] : ["primary"]) :
      "${rule_key}-${topic_key}" => { rule = rule_key, topic = topic_key }
    }
  ]...)
}

# ---------------------------------------------------------------------------
# Alert topics and email subscriptions
# ---------------------------------------------------------------------------

# No KMS key: EventBridge and CloudWatch alarms cannot publish to a topic
# encrypted with the AWS-managed aws/sns key, and customer-managed keys are paid.
resource "aws_sns_topic" "this" {
  for_each = local.topics

  name = each.value
}

resource "aws_sns_topic_subscription" "email" {
  for_each = local.topics

  topic_arn = aws_sns_topic.this[each.key].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------------------------------------------------------------------------
# Path 1: CloudTrail metric filters and alarms
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "this" {
  for_each = local.metric_alarms

  name           = "${local.p}-${each.key}"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name      = "${local.p}-${each.key}"
    namespace = "${local.p}-security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.metric_alarms

  alarm_name          = "${local.p}-${each.key}"
  alarm_description   = each.value.description
  namespace           = "${local.p}-security"
  metric_name         = aws_cloudwatch_log_metric_filter.this[each.key].metric_transformation[0].name
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  actions_enabled     = true

  alarm_actions = each.value.tamper ? [
    aws_sns_topic.this["primary"].arn,
    aws_sns_topic.this["backup"].arn,
  ] : [aws_sns_topic.this["primary"].arn]
}

# ---------------------------------------------------------------------------
# Path 2: EventBridge rules
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "this" {
  for_each = local.event_rules

  name          = "${local.p}-${each.key}"
  description   = each.value.description
  event_pattern = jsonencode(each.value.pattern)
  state         = "ENABLED"
}

resource "aws_cloudwatch_event_target" "this" {
  for_each = local.event_targets

  rule      = aws_cloudwatch_event_rule.this[each.value.rule].name
  target_id = "${local.p}-alerts-${each.value.topic}"
  arn       = aws_sns_topic.this[each.value.topic].arn
}

# ---------------------------------------------------------------------------
# Topic access policies: each topic accepts messages only from the exact
# rules and alarms in this module that send to it.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "topic" {
  for_each = local.topics

  statement {
    sid       = "AllowThisModulesEventBridgeRules"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [
        for key, rule in local.event_rules :
        aws_cloudwatch_event_rule.this[key].arn
        if each.key == "primary" || rule.tamper
      ]
    }
  }

  statement {
    sid       = "AllowThisModulesCloudWatchAlarms"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [
        for key, alarm in local.metric_alarms :
        aws_cloudwatch_metric_alarm.this[key].arn
        if each.key == "primary" || alarm.tamper
      ]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this[each.key].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  for_each = local.topics

  arn    = aws_sns_topic.this[each.key].arn
  policy = data.aws_iam_policy_document.topic[each.key].json
}
