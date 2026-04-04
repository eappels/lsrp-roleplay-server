# lsrp_jobs

Core employment resource for LSRP.

## Responsibilities

- Stores one active civilian job per player identity.
- Syncs job, grade, duty, and permissions into player state bags.
- Exposes exports for job registration, employment checks, duty changes, and permission checks.
- Pays on-duty employees through `lsrp_economy` using interval-based payroll rules.

## Main Exports

- `registerJobDefinition(definition)`
- `getPublicJobs()`
- `getEmployment(playerSrc)`
- `isEmployedAs(playerSrc, jobId)`
- `isOnDuty(playerSrc, jobId)`
- `hasPermission(playerSrc, permission)`
- `employPlayer(playerSrc, jobId, gradeId)`
- `resignPlayer(playerSrc)`
- `setDuty(playerSrc, shouldBeOnDuty)`

## Notes

- Player employment is persisted in `lsrp_job_employment`.
- Job definitions are registered by gameplay resources such as `lsrp_taxi` and `lsrp_police`.
- Public jobs are consumed by `lsrp_jobcenter`.