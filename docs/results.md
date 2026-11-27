## AI twin: terraform validate (first answer, 2026-11-27)

| Module | Valid | Errors | Unsupported or invented types/arguments |
| --- | --- | --- | --- |
| secure-bucket | yes | 0 | - |
| network | yes | 0 | - |
| iam | yes | 0 | - |
| foundation | yes | 0 | - |
| detection | yes | 0 | - |

All five modules were valid on the first answer, so I didn't use the one allowed repair.

## AI twin: intent review against the specs (2026-11-27)

Scanners check settings. Here I checked intent instead: would the twin actually send an alert, and are its policies as tight as the spec asks? Line numbers point to `ai-twin/modules/<module>/main.tf`.

### detection

**Is every required event covered, with the exact strings?** Yes.

| Spec item | Caught by | Strings |
| --- | --- | --- |
| GuardDuty finding | EventBridge `guardduty-findings` (L138-145) | `aws.guardduty` / `GuardDuty Finding` |
| Access Analyzer finding | EventBridge `access-analyzer-findings` (L146-153) | `aws.access-analyzer` / `Access Analyzer Finding` |
| CloudTrail stopped, deleted, updated, selectors changed | metric filter `trail-changes` (L100-104) and EventBridge `trail-tampering` (L154-164) | `StopLogging`, `DeleteTrail`, `UpdateTrail`, `PutEventSelectors` |
| IAM users, keys, login profiles, policies, groups, roles | metric filter `iam-changes` (L105-109) | all 10 event names (L43-54) |
| VPC flow logs deleted | metric filter `flow-logs-deleted` (L110-114) | `DeleteFlowLogs` |
| S3 bucket policy, ACL, public access block (bucket and account) | metric filter `s3-public-access-changes` (L115-119) | 7 event names (L55-63). There's no `DeleteBucketAcl` API, so `PutBucketAcl` covers ACLs |
| Someone silencing the alerts | metric filters `rule-tampering`, `topic-tampering`; EventBridge `log-group-tampering`, `alarm-tampering`, `topic-tampering`, `detector-tampering`, `analyzer-tampering` | event sources and `AWS API Call via CloudTrail` (L135) all match |

The design is better than I expected. The two detection paths watch each other: the metric filters watch the EventBridge rules and the topics, and the EventBridge rules watch the log group, the metric filters and the alarms. Tamper alerts go to a second topic, so deleting one topic still gets an email out through the other. My baseline uses a single topic.

**Can EventBridge publish to the topic?** Yes. The policy allows `events.amazonaws.com` (L334-360) and `cloudwatch.amazonaws.com` for the alarms (L362-388), attached with `aws_sns_topic_policy` (L409-414). The "rule matches, no email" failure doesn't happen here.

**Is the topic policy limited to this project?** Yes. Every statement has `aws:SourceAccount` plus `ArnEquals aws:SourceArn` with the exact rule and alarm ARNs the module creates. The backup topic only accepts the tamper rules (L357, L385).

**Anything hard-coded?** No. Account, region and partition come from data sources (L1-5, L28-31). The email is `var.alert_email`, marked sensitive.

**Does IAM detection work in ap-southeast-2?** Yes. The twin notes in a comment (L9-14) that IAM events only reach EventBridge in us-east-1, and uses metric filters on the CloudTrail log group instead. That depends on the foundation trail staying multi-region, including global service events and delivering to CloudWatch Logs (foundation L87-88, L92). Turn any of those off and IAM alerting stops without a sound.

**Weaknesses I found (no scanner flags these):**

- **An alarm already in ALARM sends no second email.** CloudWatch only notifies on a state change. If one IAM change trips the alarm, a second change in the same or next 5-minute window sends nothing. An attacker could make a harmless change first and hide a malicious one behind it. This is the biggest gap, and **my own baseline has it too**: my `iam-persistence` alarm works the same way. Fix options: treat every alarm email as "check CloudTrail for the whole window", or catch IAM with EventBridge in us-east-1.
- **Delay.** CloudTrail to CloudWatch Logs takes roughly 5-15 minutes, plus the 300 s alarm period. IAM, S3 and flow-log alerts aren't real-time.
- **Two subscriptions to confirm.** Both `<project>-alerts` and `<project>-alerts-backup` need their email confirmed. If the backup one is never confirmed, tamper alerts have no second route and nothing tells you.
- **Small coverage gaps outside the spec's must-list:** archiving GuardDuty findings (`ArchiveFindings`), Access Analyzer `UpdateFindings`, and CloudWatch `SetAlarmState` aren't watched. The `topic_arn_prefix` (L39) also matches any other `<project>-alerts*` topic. That causes extra alerts, not missed ones.
- **To check in the live test:** whether unsubscribing through the email link creates an `Unsubscribe` CloudTrail event that `topic-tampering` catches.
- **Scanner finding I expect:** the topics aren't KMS-encrypted (L250-256). The spec bans paid keys, and EventBridge can't publish to a topic encrypted with `aws/sns`, so this is a known trade-off, not a defect. My baseline skips the same check with a documented exception.

### iam

- **CI trust (L42-57):** `StringEquals` on `aud` and on `sub`, with exactly `repo:<repo>:pull_request` and `repo:<repo>:ref:refs/heads/main`. No `StringLike`, no `*`, so other branches, tags and repos are refused. One catch: if a workflow ever uses a GitHub `environment:`, the `sub` changes to `repo:<repo>:environment:<name>` and the role stops working. It fails closed, which is the safe direction.
- **Auditor trust (L314-339):** exact `admin_user_arn` principal, MFA required and MFA age under 3600 s. A request without the age key is refused.
- **Wildcards:** no bare `"*"` action. It uses read-only prefixes like `iam:Get*`, `guardduty:Get*` and `logs:Describe*` on all resources. These also read data, not just configuration (`guardduty:GetFindings`, `cloudtrail:GetQueryResults`, `iam:GetCredentialReport`). The spec says "read configuration", so this is a nit; exact action lists would match it better.
- **Lock-file write (L11, L147-155):** `<prefix>*.tflock`. In IAM resource ARNs `*` also matches `/`, so CI could write `envs/dev/x/y.tflock`. Still lock files only, so acceptable, but broader than "the state lock file". My baseline uses the same pattern.
- **Boundary denies (L160-288):** a few silencing actions aren't in the deny list: `events:PutRule`/`PutTargets`, `sns:SetTopicAttributes`, `logs:PutMetricFilter`, `cloudwatch:PutMetricAlarm`, `access-analyzer:UpdateAnalyzer`, `iam:CreatePolicy`, `iam:Detach*Policy`. The role is still safe because the boundary only allows read actions. These denies are a second layer, and the gaps only matter if someone widens the Allow later.
- Both roles have 3600 s sessions, the auditor's boundary is SecurityAudit, and no keys are stored. Every spec item is met.

### secure-bucket

- **TLS only:** yes. `DenyInsecureTransport` (L96-115) and `DenyOutdatedTls` for TLS below 1.2 (L117-136), on the bucket and its objects, for every principal.
- **Versioning:** enabled (L29-35). Old versions expire after `retention_days`, and incomplete uploads are aborted after 7 days (L56-88).
- Also present: public access block, `BucketOwnerEnforced`, SSE-S3 only with a deny on KMS uploads, and outputs that wait for the policy (`depends_on`, outputs.tf L5-13). A caller's `policy_docs` can't override the module's own statement IDs. Nothing missing.

### Summary

Apart from the expected SNS encryption finding, the scanners pass all three modules, and the intent holds up too. The twin's detection is in some ways more thorough than mine: it has a backup topic and the two detection paths watch each other. The one real silent failure is the alarm that stays in ALARM and doesn't email again, and my baseline shares it. The rest are nits, or things that must stay in place: the multi-region trail with global events, and both email subscriptions confirmed.