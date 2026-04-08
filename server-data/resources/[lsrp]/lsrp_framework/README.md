# LSRP Framework

## Overview

`lsrp_framework` is the public API facade for the LSRP platform.

It does not replace the existing service resources. Instead, it exposes a stable, easier-to-use contract over them so new resources can depend on one framework entrypoint.

## Current Scope

Version `1.1.0` is still intentionally small, but it now covers both the original facade exports and a shared callback layer.

It currently wraps:

- Identity via `lsrp_core`
- Prejoin auth and characters via `lsrp_core`
- Economy via `lsrp_economy`
- Jobs and permissions via `lsrp_jobs`
- Inventory lookups and item mutation via `lsrp_inventory`
- Client-server and server-client callback requests with a shared response envelope
- NUI callback registration helpers on the client

## Public Exports

Server exports:

- `getApiVersion()`
- `getIdentity(playerSrc)`
- `getIdentityByLicense(license)`
- `getIdentityByStateId(stateId)`
- `getMigrationStatus()`
- `getSourceByStateId(stateId)`
- `getSourceByLicense(license)`
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

## Design Notes

- The facade returns normalized payloads and hides internal storage details.
- New LSRP resources should prefer `lsrp_framework` over calling multiple service resources directly.
- The callback layer uses one response envelope with `ok`, `data`, `error`, and `meta` fields.
- Callback registrations accept either local functions or event-name strings; use event names for cross-resource registrations.
- The default callback timeout is `5000` ms unless a resource passes a custom timeout.
- Built-in server callbacks now include `lsrp_prejoin:register` and `lsrp_prejoin:login` for prejoin auth UIs.
- Notifications now have a shared framework path on both server and client.
- See `TODO.md` in this resource for the implementation checklist that tracks the next framework milestones.