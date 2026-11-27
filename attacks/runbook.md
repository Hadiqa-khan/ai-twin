# Attack runbook

TTD (time to detect) = first alert time minus detonation time, both in UTC.
Take the alert time from the "time" field in the alert email's JSON, not from your inbox.

| Run | Technique | Variant | Detonated (UTC) | First alert (UTC) | Alert source | TTD (min) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | aws.defense-evasion.cloudtrail-stop | human |  |  |  |  |
| 2 | aws.defense-evasion.cloudtrail-stop | twin |  |  |  |  |
| 3 | aws.persistence.iam-create-admin-user | human |  |  |  |  |
| 4 | aws.persistence.iam-create-admin-user | twin |  |  |  |  |
| 5 | aws.exfiltration.s3-backdoor-bucket-policy | human |  |  |  |  |
| 6 | aws.exfiltration.s3-backdoor-bucket-policy | twin |  |  |  |  |
| 7 | aws.defense-evasion.vpc-remove-flow-logs | human |  |  |  |  |
| 8 | aws.defense-evasion.vpc-remove-flow-logs | twin |  |  |  |  |

## Notes per run
