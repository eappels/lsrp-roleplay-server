# LSRP Framework

## Overview

`lsrp_framework` is the public API facade for the LSRP platform.

It does not replace the existing service resources. Instead, it exposes a stable, easier-to-use contract over them so new resources can depend on one framework entrypoint.

## Current Scope

Version `1.6.0` keeps the facade intentionally small, but now adds a usable-item registry on top of the contract, callback, interaction, ownership, and phone-app layers.

It currently wraps:

- Identity via `lsrp_core`
- Prejoin auth and characters via `lsrp_core`
- Economy via `lsrp_economy`
- Jobs and permissions via `lsrp_jobs`
- Inventory lookups and item mutation via `lsrp_inventory`
- Client-server and server-client callback requests with a shared response envelope
- NUI callback registration helpers on the client
- Client-side interaction registration and invocation for zone/action entry points
- Usable item registration and runtime inventory-use callbacks
- Phone app registration and generic phone app callback routing
- Shared framework error codes and notification levels
- A published contract version for stable read-model payloads

## Public Exports

Server exports:

- `getApiVersion()`
- `getContractVersion()`
- `getIdentity(playerSrc)`
- `getIdentityByLicense(license)`
- `getIdentityByStateId(stateId)`
- `normalizeOwnerIdentity(ownerIdentity)`
- `getOwnerIdentity(playerSrc)`
- `getOwnerIdentityByLicense(license)`
- `getOwnerIdentityByStateId(stateId)`
- `resolveOwnerIdentity(value)`
- `ownerIdentitiesMatch(left, right)`
- `buildOwnerKey(value)`
- `getMigrationStatus()`
- `getSourceByStateId(stateId)`
- `getSourceByLicense(license)`
- `getOwnedVehicles(ownerIdentity, options)`
- `getOwnedVehicle(ownerIdentity, ownedVehicleId)`
- `getOwnedApartments(ownerIdentity)`
- `registerUsableItem(itemName, definition)`
- `unregisterUsableItem(itemName)`
- `getUsableItem(itemName)`
- `getUsableItems()`
- `invokeUsableItem(playerSrc, itemName, payload)`
- `registerPhoneApp(appId, definition)`
- `unregisterPhoneApp(appId)`
- `getPhoneApp(appId)`
- `getPhoneApps(options)`
- `invokePhoneApp(playerSrc, appId, payload)`
- `hasPhoneAccess(ownerIdentity)`
- `canAccessPhoneApp(ownerIdentity, appName)`
- `isAuthenticated(playerSrc)`
- `getCharacter(playerSrc)`
- `hasCharacter(playerSrc)`
- `createCharacter(playerSrc, payload)`
- `registerPrejoinAccount(playerSrc, payload)`
- `loginPrejoinAccount(playerSrc, payload)`
- `getMoney(playerSrc)`
- `getCash(playerSrc)`
- `getAccountIdByLicense(license)`
- `getJob(playerSrc)`
- `isEmployedAs(playerSrc, jobId)`
- `isOnDuty(playerSrc, jobId)`
- `setDuty(playerSrc, shouldBeOnDuty)`
- `registerJobDefinition(definition)`
- `employPlayer(playerSrc, jobId, gradeId)`
- `getPublicJobs()`
- `resignPlayer(playerSrc)`
- `getInventory(playerSrc)`
- `getPlayerContext(playerSrc)`
- `notify(playerSrc, message, level)`
- `notifyAll(message, level)`
- `formatCurrency(amount)`
- `canAfford(playerSrc, amount)`
- `addMoney(playerSrc, amount, reason, metadata)`
- `removeMoney(playerSrc, amount, reason, metadata)`
- `addCash(playerSrc, amount, reason, metadata)`
- `removeCash(playerSrc, amount, reason, metadata)`
- `addMoneyByAccountId(accountId, amount, reason, metadata)`
- `removeMoneyByAccountId(accountId, amount, reason, metadata)`
- `hasPermission(playerSrc, permission)`
- `hasItem(playerSrc, itemName, amount)`
- `addItem(playerSrc, itemName, amount, metadata)`
- `removeItem(playerSrc, itemName, amount)`
- `registerServerCallback(callbackName, handler)`
- `unregisterServerCallback(callbackName)`
- `triggerClientCallback(playerSrc, callbackName, payload, timeoutMs)`

Client exports:

- `notify(message, level)`
- `registerClientCallback(callbackName, handler)`
- `unregisterClientCallback(callbackName)`
- `triggerServerCallback(callbackName, payload, timeoutMs)`
- `registerNuiCallback(callbackName, handler)`
- `registerInteraction(interactionName, handler, options)`
- `unregisterInteraction(interactionName)`
- `getInteraction(interactionName)`
- `invokeInteraction(interactionName, payload)`

## Design Notes

- The facade returns normalized payloads and hides internal storage details.
- New LSRP resources should prefer `lsrp_framework` over calling multiple service resources directly.
- The callback layer uses one response envelope with `ok`, `data`, `error`, and `meta` fields.
- Read-model contracts are versioned separately through `getContractVersion()` and the documented field guarantees in `API.md`.
- Framework-facing failures should use documented framework error codes instead of leaking ad hoc service strings when possible.
- Callback registrations accept either local functions or event-name strings; use event names for cross-resource registrations.
- Interaction registrations accept either local functions or event-name strings; zone resources should invoke registered interaction ids instead of firing local target events directly.
- Owner-identity helpers normalize cross-resource ownership around `stateId` first, with `license` retained only as a compatibility fallback.
- Usable items register runtime inventory use behavior through the framework so resources do not need to patch `lsrp_inventory` item definitions directly.
- Phone apps register metadata plus a callback name through the framework so `lsrp_phones` can request app data by stable app id instead of hardcoded per-app backend wiring.
- The default callback timeout is `5000` ms unless a resource passes a custom timeout.
- Built-in server callbacks now include `lsrp_prejoin:register` and `lsrp_prejoin:login` for prejoin auth UIs.
- Notifications now have a shared framework path on both server and client.
- See `TODO.md` in this resource for the implementation checklist that tracks the next framework milestones.

## Conventions

- Framework exports use lowerCamelCase verb-first names such as `getPlayerContext`, `registerPhoneApp`, and `invokeUsableItem`.
- Resource net events should use `<resourceName>:server:<action>` and `<resourceName>:client:<action>`.
- Framework server callbacks should use `<resourceName>:server:<action>` and client callbacks should use `<resourceName>:client:<action>`.
- Framework interaction ids should use `<resourceName>:<action>`.
- Shared state keys should use `<resourceName>:<key>` instead of bare global names.
- Keep local name registries in explicit tables such as `CALLBACK_NAMES`, `INTERACTION_IDS`, and `STATE_KEYS` so handlers and docs stay aligned.