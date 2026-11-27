# Attack predictions

Written 27 Nov 2026, before running any attack.

Setup: us-east-1, Free plan account, so no GuardDuty. Both variants catch IAM with
metric filters. My guess for timing: EventBridge alerts land in a few minutes, alarms
take longer because CloudTrail has to deliver to CloudWatch Logs first (5-15 min),
plus the alarm period (60 s on mine, 300 s on the twin).

| # | Technique | Mine: first alert | Mine TTD | Twin: first alert | Twin TTD | Why |
| --- | --- | --- | --- | --- | --- | --- |
| A | s3-backdoor-bucket-policy | s3-policy-change rule | 1-5 min | s3-public-access-changes alarm, or Access Analyzer | 10-30 min | I used EventBridge for S3, the twin used a metric filter |
| B | cloudtrail-stop | cloudtrail-tampering rule | 1-5 min | trail-tampering rule | 1-5 min | Same approach on both, so I expect a tie |
| C | iam-create-admin-user | iam-persistence alarm | 5-15 min | iam-changes alarm | 10-20 min | Both alarms, but the twin's period is 5x longer |
| D | vpc-remove-flow-logs | flowlog-tampering rule | 1-5 min | flow-logs-deleted alarm | 10-20 min | EventBridge vs metric filter again |

Backup signals:
- A should also show up as an Access Analyzer finding on both runs, probably
  within half an hour.
- B would normally get a GuardDuty finding too (CloudTrailLoggingDisabled), but
  GuardDuty isn't available on this account, so there's no backup for B.
- C and D have no backup at all. If the main alert fails, they go unnoticed.

What I think could go wrong:
- The alarm gap. If C runs twice while the alarm is still in ALARM, the second one
  won't send an email. More likely on the twin because of the 300 s period.
- Stratus warm-ups create buckets, trails and a VPC. Anything that arrives before
  the detonation time is noise and doesn't count.
- Deploying the twin creates rules and alarms, which may trip its own tampering
  alerts. I'll ignore anything that arrives during the apply.
- The twin has two topics. If I forget to confirm one of the emails, some of its
  alerts go nowhere.
- The guardduty-findings rule exists on both sides but will never fire here.
  Not a miss, just nothing to watch.

My overall bet: no attack goes completely undetected on either side. The difference
will be speed. Mine should win on A and D, tie on B and be a bit faster on C.