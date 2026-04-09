# LSRP Server

LSRP Server is a FiveM roleplay server monorepo built around a custom `lsrp_framework` facade and a set of modular `lsrp_*` gameplay resources.

This repository contains the local FXServer layout, the active server configuration, and the custom LSRP resources that run on top of the Cfx.re/FiveM server runtime.

## Repo Layout

```text
.
|- server/        # FXServer binaries/runtime
|- server-data/   # server config, startup script, resources, cache
|  |- StartServer.bat
|  |- server.cfg
|  \- resources/
|     \- [lsrp]/
|        |- README.md
|        |- TODO.md
|        |- BUGS.md
|        \- lsrp_*/
```

## Main Components

- `lsrp_framework`: stable facade for identity, money, inventory, jobs, callbacks, interactions, phone apps, and usable items.
- `lsrp_core`: identity, character, and shared core state.
- `lsrp_inventory`: slot-based inventory with runtime usable-item registration.
- `lsrp_jobs`, `lsrp_economy`, `lsrp_housing`, `lsrp_vehicleparking`, `lsrp_phones`: core gameplay backends.
- `lsrp_pededitor`, `lsrp_vehicleeditor`, `lsrp_vehicleshop`, `lsrp_zones`: player-facing interaction and UI flows.

The resource index and per-resource documentation live in `server-data/resources/[lsrp]/README.md`.

## Requirements

Before you can run the server locally, you need:

- a current FXServer artifact in `server/`
- a valid Cfx.re server license key
- a MySQL/MariaDB instance for the LSRP resources
- the configured third-party resources included by `server.cfg`

## Configuration

Main server configuration lives in:

- `server-data/server.cfg` for the live local config
- `server-data/server.cfg.example` for the committed public template
- `server-data/server_internal.cfg` for local-only secrets and machine-specific overrides
- `server-data/server_internal.cfg.example` for the committed private-config template
- `server-data/StartServer.bat`

Review these before running or publishing the repo:

- `sv_licenseKey`
- MySQL connection string
- ACE permissions and owner identifiers
- hostname, locale, and project metadata

If this repository is public, do not commit live credentials or private identifiers.

Recommended local setup:

```bat
copy server-data\server.cfg.example server-data\server.cfg
copy server-data\server_internal.cfg.example server-data\server_internal.cfg
```

## Running The Server

From the repo root:

```bat
cd server-data
..\server\FXServer.exe +exec server.cfg
```

Or use:

```bat
server-data\StartServer.bat
```

## Documentation

- Resource index: `server-data/resources/[lsrp]/README.md`
- Backlog: `server-data/resources/[lsrp]/TODO.md`
- Known issues: `server-data/resources/[lsrp]/BUGS.md`
- Framework API: `server-data/resources/[lsrp]/lsrp_framework/API.md`
- Resource template: `server-data/resources/[lsrp]/lsrp_resource_template/README.md`

## Status

The framework baseline is in place and the resource set has been ported onto `lsrp_framework`.

Current planned feature work is tracked in `server-data/resources/[lsrp]/TODO.md`.

## Notes

- This repo tracks the active server layout, not just the custom resources.
- Cache and local editor state should stay out of source control.
- If you want to split the custom resources into a separate repository later, `server-data/resources/[lsrp]` is the natural boundary.