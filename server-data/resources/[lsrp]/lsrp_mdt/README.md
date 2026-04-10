# lsrp_mdt

Starter MDT resource with a basic duty-gated NUI for LSRP.

## Features

- Duty-gated `/mdt` access for configured service jobs.
- Basic NUI shell with unit profile, status cards, shortcuts, notices, and starter lookup inputs.
- `/mdt_close` to close the terminal.
- `/mdt_preview` to open the UI shell without job checks for layout testing.
- Refresh action wired through the NUI so the shell can pull a fresh payload from the server.

## Current Scope

- Access is limited to configured jobs in `shared/config.lua`.
- This first pass is a shell only: person lookup, plate lookup, BOLOs, warrants, and report persistence are still placeholders.
- The resource is designed to be extended rather than treated as a finished MDT.

## Main Files

- `shared/config.lua`: access rules, command names, default notices, and starter shortcuts.
- `server/server.lua`: access validation, command handlers, and MDT payload building.
- `client/client.lua`: NUI open and close flow plus NUI callback registration.
- `html/`: basic MDT interface.

## Commands

- `/mdt`: open the MDT if your job has access and you meet duty requirements.
- `/mdt_close`: close the MDT.
- `/mdt_preview`: open the MDT starter shell without access gating.

## Notes

- The resource depends on `lsrp_framework`.
- The current UI is intentionally basic and static beyond the unit payload so the next implementation pass can focus on real record systems.