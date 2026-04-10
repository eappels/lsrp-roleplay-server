# LSRP TODO

## In Testing

- MDT (starter resource)
- Radio (partly implemented)

## Completed

- EMS
- Taxi
- Towing
- Vehicle shop
- Clothing shop
- Thirst and hunger
- Police
- Phone
- Housing
- Vehicle parking
- Job center
- ATM hacking
- Fuel
- Economy

## Framework Prerequisites

Build these framework pieces before or alongside the first major resource ports:

1. Official callbacks and request-response layer for NUI, client-server, and server-client flows.
2. Stable normalized contracts for player, identity, money, inventory, jobs, permissions, and notifications.
3. Registry APIs for jobs, items, interactions, and phone apps.
4. Standard conventions for event names, payload shapes, exports, state bags, and config layout.
5. Shared ownership and identity helpers for vehicle, housing, and phone systems.

## Framework Continuation Order

When framework work resumes, continue in this order:

1. Framework baseline is complete; extend it only when a repeated cross-resource pattern deserves a facade API.

## Resource Port Priority

All currently planned LSRP resources in this repo have been ported to `lsrp_framework`.

## Framework goal
Turn LSRP into a small, opinionated platform, not a compatibility layer.

## Framework principles

1. One public API layer: new resources should depend on `lsrp_framework`, not directly on multiple internal services.
2. Stable contracts: freeze normalized payloads for player, identity, money, inventory, jobs, notifications, callbacks, and permissions.
3. Registries over hardcoding: jobs, items, interactions, phone apps, and usable actions should register themselves.
4. Convention over improvisation: keep exports, events, callbacks, state bags, and config layout consistent across all resources.
5. Templates and docs: every new LSRP resource should start from a standard scaffold and follow the same structure.

## Framework shape

The framework should center on these developer-facing concepts:

1. Player: read-only normalized player context.
2. Identity: stable cross-system identity lookup.
3. Economy: add, remove, transfer, format, and query balances.
4. Inventory: query items, mutate items, and register usable items.
5. Jobs: register jobs, employ players, resign players, set duty, and check permissions.
6. UI and callbacks: one official request-response path for NUI, client-server, and server-client flows.

## Guardrails

1. Do not expose database schema as framework API.
2. Do not allow direct cross-resource table access.
3. Do not add undocumented or ad hoc event payloads.
4. Do not duplicate identity, notify, or permission helper logic in each resource.
5. Do not grow a giant mutable player object.

## Practical roadmap

1. Keep `lsrp_framework` as the facade over the existing service resources.
2. Move shared helper patterns into the facade first: player lookup, identity, notifications, and callbacks.
3. Standardize money, inventory, and job APIs behind that layer.
4. Add registry APIs for items, jobs, interactions, and phone apps.
5. Use the resource template as the required starting point for all new LSRP resources.
6. Gradually refactor older resources to consume the facade instead of each other directly.

The target state is a clean internal SDK: small public surface, strict conventions, modular services, and easy resource scaffolding.