# Bug triage

Every issue arrives labelled `triage` through the issue templates. Once a week, or before any build goes to testers, go through the `triage` list.

| Severity | Meaning | Response |
|---|---|---|
| S1 | Crash, lost save, cannot finish a mission | Fix before the next build goes out |
| S2 | A feature is broken but there is a workaround | Schedule into the current phase |
| S3 | Minor, cosmetic or wording | Batch into a polish pass |

For each issue:

1. Reproduce it on the reported build. If it cannot be reproduced, ask for the log and label `needs-info`.
2. Set the severity label (`S1`, `S2`, `S3`) and remove `triage`.
3. Link the checklist item it belongs to, or add a new item if none fits.
4. A fix lands with a headless test that fails before the fix, unless the bug is purely visual, in which case attach before and after screenshots from the screenshots artefact.

Playtest feedback issues are read in full, summarised into the checklist or the design document, and closed with a link to where the feedback went.
