# lsrp_mdt

Minimal MDT resource for LSRP with persistent profile intel, tags, and a live police duty roster.

## Features

- Duty-gated `/mdt` access for configured service jobs, with admin overrides for ACE admins and persisted `lsrp_dev` dev admins.
- Player lookup by name or exact state ID, merging live online players with stored MDT profiles.
- Persistent MDT profile storage keyed by `state_id` with cached name data and last-seen timestamps.
- Persistent intel note timeline and tag list on each selected profile.
- Police-only edit permissions for tags and intel while on duty.
- Live roster showing which police officers are currently on duty.
- `/mdt_close` to close the terminal.
- `/mdt_preview` to open the UI without job checks for layout testing.

## Current Scope

- Access is limited to configured jobs in `shared/config.lua`, unless the player has the configured admin ACE override or is listed as a dev admin in `lsrp_dev`.
- Police and EMS can open the MDT in this pass.
- Only on-duty police can add intel notes or manage profile tags.
- The roster intentionally shows police units only.
- BOLOs, incidents, warrants, citations, and dispatch workflows are still out of scope for this pass.

## Persistence

The resource bootstraps its own database tables through `oxmysql` on startup:

- `lsrp_mdt_profiles`: cached profile header data by `state_id`
- `lsrp_mdt_notes`: intel note history
- `lsrp_mdt_tags`: profile tags

Profiles are automatically created or refreshed when online players appear in searches, profile views, or the police duty roster.

## Main Files

- `shared/config.lua`: access rules, command names, and default notices.
- `server/server.lua`: schema bootstrap, access validation, lookup logic, persistent profile actions, and payload building.
- `client/client.lua`: NUI open and close flow plus NUI callback registration.
- `html/`: minimal search, profile, and roster interface.

## Commands

- `/mdt`: open the MDT if your job has access and you meet duty requirements, or if your admin ACE/dev admin status grants override access.
- `/mdt_close`: close the MDT.
- `/mdt_preview`: open the MDT starter shell without access gating.

## Notes

- The resource depends on `lsrp_framework` and `oxmysql`.
- Admin override ACE defaults to `lsrp.mdt.admin` and is granted to `group.admin` in `server.cfg`.
- Persisted `lsrp_dev` dev admins in the `dev_admins` table also bypass the job and duty gate.