# LSRP Framework TODO

This file turns the top-level framework prerequisites into concrete work inside `lsrp_framework`.

## Current Baseline

- [x] Expose one framework entrypoint resource.
- [x] Normalize core read paths for identity, character, money, jobs, inventory, and player context.
- [x] Normalize core write paths for money, inventory, duty, job registration, and employment.
- [x] Provide a shared notify path on server and client.

## Callbacks And Request-Response

- [x] Add a server callback registry with request id, timeout, and one response envelope.
- [x] Add a client callback registry with the same request and response contract.
- [x] Add framework helpers for NUI callbacks so resources stop rolling their own request flow.
- [x] Standardize success and error response payloads for callback results.
- [x] Document the official callback API with examples for client, server, and NUI usage.

## Stable Contracts

- [x] Freeze the payload shapes for `getPlayerContext`, `getIdentity`, `getCharacter`, `getMoney`, `getJob`, and `getInventory`.
- [x] Standardize framework error codes across reads, writes, and callbacks.
- [x] Add an explicit contract version policy for future payload changes.
- [x] Document which fields are guaranteed, optional, or nullable in each export response.
- [x] Add small validation helpers so contracts stay normalized before data leaves the facade.

## Suggested Implementation Order

Use this order when framework work resumes:

1. Interaction registry
2. Ownership and identity helpers
3. Phone-app registry
4. Usable-item registry
5. Conventions and template finalization

## Registries

- [x] Job registration entrypoint exists through `registerJobDefinition`.
- [ ] Add a usable-item registry API instead of requiring direct inventory integration.
- [ ] Add an interaction registry API for world prompts, zones, or action entries.
- [ ] Add a phone-app registry API so the phone resource can consume registered apps through the framework.
- [ ] Document lifecycle rules for registering and unregistering framework extensions.

## Conventions

- [ ] Publish the official naming pattern for framework events, callbacks, exports, and state keys.
- [x] Define one standard response envelope for framework actions that can fail.
- [x] Define one standard notification level list and message contract.
- [ ] Update `lsrp_resource_template` to consume the final callback and registry APIs.
- [ ] Add a short conventions section to the framework API docs so new resources follow one pattern by default.

## Ownership And Identity Helpers

- [ ] Add a normalized owner identity shape for cross-resource use, centered on `stateId` with compatibility fallbacks.
- [ ] Add helper exports for resolving owner identity from `playerSrc` and other common entry points.
- [ ] Add vehicle ownership helper contracts needed by parking, vehicle shop, and vehicle behaviour.
- [ ] Add housing ownership helper contracts needed by housing and related UI flows.
- [ ] Add phone ownership and app-access helper contracts needed by phones and inventory-gated UI features.

## Port Readiness

- [x] Port `lsrp_vehicleparking` onto framework identity, money, and notification helpers while keeping parking ownership logic in the resource.
- [x] Port `lsrp_vehicleshop` onto framework identity, player money, account money, and notification helpers while keeping parking as the ownership backend.
- [x] Port `lsrp_phones` core identity, balance, and callback flows onto the framework; taxi and parking app integrations remain direct until app registries and ownership helpers exist.
- [x] Port `lsrp_housing` onto framework identity, owner lookup, player lookup, money, and notification helpers while keeping apartment stash access direct to inventory.
- [x] Port `lsrp_towing` server-side job and notification flows onto the framework while keeping the legacy client employment-updated event listener for cleanup compatibility.
- [x] Port `lsrp_vehiclebehaviour` onto framework identity and notification helpers while keeping vehicleparking as the ownership source of truth.
- [x] Port `lsrp_hunger` onto framework identity and notification helpers while keeping persistence and HUD sync local to the resource.
- [x] Port `lsrp_thirst` onto framework identity and notification helpers while keeping persistence and HUD sync local to the resource.
- [x] Port `lsrp_hud` onto the framework dependency path while keeping shared HUD config sourced from `lsrp_core` until config ownership is centralized.
- [x] Port `lsrp_pededitor` onto framework identity and callback helpers while keeping shared editor config sourced from `lsrp_core` until config ownership is centralized.
- [x] Port `lsrp_fuel` onto framework money and callback helpers while keeping local fuel sync and vehicle-state ownership in the resource.
- [x] Port `lsrp_hacking` onto framework cash, inventory, and notification helpers while keeping ATM cooldowns, placement, and puzzle flow local to the resource.
- [x] Port `lsrp_zones` onto the framework dependency path while keeping local event dispatch until the framework interaction registry is implemented.
- [x] Port `lsrp_vehicleeditor` onto framework identity and callback helpers while keeping shared editor config sourced from `lsrp_core` until config ownership is centralized.
- [x] Port `lsrp_loadscreen` prejoin auth onto framework callbacks while keeping spawn handoff owned by `lsrp_spawner`.
- [x] Port `lsrp_dev` onto framework identity and migration-audit helpers while keeping dev/admin action flow local to the resource.
- [x] Port `lsrp_jobcenter` after the standardized write and callback patterns are locked.
- [x] Port `lsrp_shops` after the standardized write and callback patterns are locked.