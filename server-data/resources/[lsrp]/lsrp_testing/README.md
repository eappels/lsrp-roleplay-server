# LSRP Testing

## Overview

`lsrp_testing` is a sandbox and behavior test resource.

Its current implementation focuses on spawning a hostile guard NPC that patrols a configured zone and reacts to players entering it.

## Main Files

- `client/client.lua`: guard spawn logic, patrol behavior, combat engagement, and zone watching.
- `shared/config.lua`: test zone configuration.

## Command

- `/lsrptest_reloadzones`: reload zone configuration for the test setup.

## Integrations

- Uses `polyzone` for zone detection.

## Notes

- This resource is for experimentation and QA, not core gameplay.
- Keep test logic isolated here rather than mixing it into production resources.