# lsrp_jobcenter

Player-facing employment browser for civilian jobs.

## Features

- Job center kiosk interaction with map blip and marker.
- NUI job browser listing public jobs through `lsrp_framework`.
- Job application flow with grade selection.
- Resign action for the current job.

## Dependencies

- `lsrp_framework`

## Notes

- The job center does not define jobs itself; it only consumes public registrations through the framework facade.
- Initial kiosk location is configured in `shared/config.lua`.