# LSRP Resource Template

## Purpose

`lsrp_resource_template` is the standard scaffold for new LSRP resources.

It is not intended to be started directly in production. Copy it, rename the folder, and then replace the example logic with your actual feature code.

## What It Includes

- `fxmanifest.lua` with `lsrp_framework` as the default dependency.
- `shared/config.lua` with common starter config values.
- `server/server.lua` with built-in helpers for:
  - `getPlayerContext`
  - `notify`
  - `canAfford`
  - `addMoney`
  - `removeMoney`
  - `hasItem`
  - `addItem`
  - `removeItem`
- `client/client.lua` with built-in framework notify usage and a simple world interaction example.

## How To Use It

1. Copy the folder.
2. Rename it to your new resource name, for example `lsrp_businesses`.
3. Update `fxmanifest.lua` metadata.
4. Replace the example events in `client/client.lua` and `server/server.lua` with your real feature logic.
5. Update `shared/config.lua` with resource-specific config.
6. Add your new resource to the `[lsrp]` README index and `server.cfg` only when it is ready to run.

## Naming Pattern

- Server events: `<resourceName>:server:*`
- Client events: `<resourceName>:client:*`
- Config table: `Config`
- Framework entrypoint: `exports['lsrp_framework']`

The template uses `GetCurrentResourceName()` when building example event names so the copied resource keeps working after it is renamed.

## Conventions

- Read player state through `lsrp_framework` instead of direct cross-resource calls.
- Use `lsrp_framework:notify` for player-facing messages.
- Keep DB schema private to the resource.
- Add only the smallest public surface needed for other resources.

## Example Command

The template registers an in-game command:

- `/<resourceName>_debug`

After renaming the resource folder, the command name updates automatically because it is based on `GetCurrentResourceName()`.