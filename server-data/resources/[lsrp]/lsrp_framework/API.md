# LSRP Framework API

Version: `1.2.0`

`lsrp_framework` is the public facade for the LSRP platform. Version `1.2.0` keeps the shared callback layer and adds a published contract version plus normalized framework error codes.

Contract version: `2026-04-09`

## Design Rules

- Treat these exports as the stable contract for new LSRP resources.
- Do not rely on internal DB schema or internal resource cache layout.
- Prefer `getPlayerContext` for read-heavy flows.
- Use the focused write exports for money and inventory changes.
- Use framework callbacks instead of inventing ad hoc request events when a response is required.
- Read-model fields documented here are stable within the current contract version.
- Additive optional fields are allowed without a contract-version bump; removals, renames, or type changes are not.

## Standard Notification Levels

- `info`
- `success`
- `warning`
- `error`

## Standard Error Codes

The framework now reserves and normalizes these codes across callback and write-facing failure paths:

- `operation_failed`
- `invalid_player`
- `invalid_callback`
- `invalid_handler`
- `invalid_response`
- `invalid_message`
- `invalid_level`
- `invalid_license`
- `invalid_state_id`
- `invalid_account_id`
- `invalid_amount`
- `invalid_item`
- `callback_failed`
- `callback_not_registered`
- `callback_already_registered`
- `timeout`
- `player_dropped`
- `not_found`
- `identity_unavailable`
- `identity_error`
- `character_service_unavailable`
- `character_operation_failed`
- `jobs_unavailable`
- `jobs_error`
- `economy_unavailable`
- `economy_error`
- `inventory_unavailable`
- `inventory_error`

## Callback Response Envelope

Framework callbacks return one standard envelope:

```lua
{
    ok = true,
    data = { ... } or nil,
    error = nil,
    meta = {
        callback = 'resource:action',
        requestId = 'sv:12:12345:1'
    }
}
```

Error responses use the same shape:

```lua
{
    ok = false,
    data = nil,
    error = 'timeout',
    meta = {
        callback = 'resource:action',
        requestId = 'cl:12:12345:1'
    }
}
```

Default timeout: `5000` ms.

Handler return forms supported by the callback layer:

```lua
return true, { value = 1 }, nil
return false, nil, 'not_allowed'
return { ok = true, data = { value = 1 } }
return { ok = false, error = 'not_found' }
return { value = 1 } -- treated as success data
```

## Core Server Exports

### `getApiVersion()`

Returns the current facade API version string.

```lua
'1.2.0'
```

### `getContractVersion()`

Returns the current stable read-contract version.

```lua
'2026-04-09'
```

### `getIdentity(playerSrc)`

Returns normalized identity data for an online player.

Guaranteed fields:

- `license` may be `nil` when the underlying service cannot resolve it.
- `accountId` may be `nil`.
- `stateId` may be `nil`.

```lua
{
    license = 'license:...',
    accountId = 123,
    stateId = 123
}
```

Returns `nil` if the player is invalid or identity is unavailable.

### `getIdentityByLicense(license)`

Returns normalized identity data for a known license when the identity service can resolve it.

```lua
local identity = exports['lsrp_framework']:getIdentityByLicense('license:...')
```

### `isAuthenticated(playerSrc)`

Returns `true` when the current online player has completed prejoin login for this session.

### `getCharacter(playerSrc)`

Returns normalized character data for an online player.

Guaranteed fields:

- `characterId`, `accountId`, and `slot` are normalized integers when present.
- `firstName`, `lastName`, `fullName`, `dateOfBirth`, and `sex` may be `nil` if unset upstream.

```lua
{
    characterId = 12,
    accountId = 123,
    slot = 1,
    firstName = 'John',
    lastName = 'Doe',
    fullName = 'John Doe',
    dateOfBirth = '1998-03-16',
    sex = 'male'
}
```

### `hasCharacter(playerSrc)`

Returns `true` when `getCharacter(playerSrc)` would return a character payload.

### `createCharacter(playerSrc, payload)`

Creates the first character for the current player.

```lua
local response = exports['lsrp_framework']:createCharacter(source, {
    firstName = 'John',
    lastName = 'Doe',
    dateOfBirth = '1998-03-16',
    sex = 'male'
})
```

### `registerPrejoinAccount(playerSrc, payload)`

Registers or updates prejoin auth credentials for the current source account.

```lua
local ok, errorCode = exports['lsrp_framework']:registerPrejoinAccount(source, {
    email = 'name@example.com',
    password = 'secret'
})
```

### `loginPrejoinAccount(playerSrc, payload)`

Authenticates the current source account against prejoin auth credentials.

```lua
local ok, errorCode = exports['lsrp_framework']:loginPrejoinAccount(source, {
    email = 'name@example.com',
    password = 'secret'
})
```

### `getMoney(playerSrc)`

Returns normalized economy data.

Guaranteed fields:

- `balance` and `cash` are non-negative whole numbers.
- `currency` is always a string.
- `accountId` may be `nil`.

```lua
{
    balance = 2500,
    cash = 120,
    currency = 'LS$',
    accountId = 123
}
```

### `getCash(playerSrc)`

Returns the player's current on-hand cash amount as a whole-dollar integer.

### `getAccountIdByLicense(license)`

Resolves an economy `account_id` for a player or business license.

### `getIdentityByStateId(stateId)`

Resolves a normalized identity payload from a gameplay `stateId`.

### `getMigrationStatus()`

Returns the current identity migration/backfill audit payload exposed by `lsrp_core`.

### `getSourceByStateId(stateId)`

Resolves the live player source for a gameplay `stateId` when that player is online.

### `getSourceByLicense(license)`

Resolves the live player source for a license when that player is online.

### `getJob(playerSrc)`

Returns normalized employment data for the current player.

Guaranteed fields:

- `id` is required when a job payload exists.
- `permissions` is always an array.
- `payAmount` and `payIntervalSeconds` are non-negative whole numbers.

```lua
{
    id = 'taxi_driver',
    label = 'Downtown Cab Co.',
    gradeId = 'driver',
    gradeLabel = 'Driver',
    onDuty = true,
    permissions = { 'taxi.dispatch.view' },
    payAmount = 125,
    payIntervalSeconds = 900
}
```

### `isEmployedAs(playerSrc, jobId)`

Returns `true` if the online player is employed in the requested job.

### `isOnDuty(playerSrc, jobId)`

Returns `true` if the online player is on duty for the requested job. If `jobId` is omitted, it checks for any active duty state in the jobs service.

### `setDuty(playerSrc, shouldBeOnDuty)`

Updates duty state through `lsrp_jobs`.

```lua
local ok, job, errorCode = exports['lsrp_framework']:setDuty(source, true)
```

### `registerJobDefinition(definition)`

Registers a gameplay job definition through `lsrp_jobs`.

```lua
local ok, errorCode = exports['lsrp_framework']:registerJobDefinition(Config.JobDefinition)
```

### `employPlayer(playerSrc, jobId, gradeId)`

Assigns an online player to a job through `lsrp_jobs`.

```lua
local ok, job, errorCode = exports['lsrp_framework']:employPlayer(source, 'police_officer', 'officer')
```

### `getPublicJobs()`

Returns the public job list exposed by `lsrp_jobs` for player-facing browsing flows such as the job center.

### `resignPlayer(playerSrc)`

Resigns the current online player from their active job through `lsrp_jobs`.

```lua
local ok, errorCode = exports['lsrp_framework']:resignPlayer(source)
```

### `getInventory(playerSrc)`

Returns the sanitized inventory payload exposed by `lsrp_inventory`.

Guaranteed fields:

- `slots` is a positive whole number.
- `maxWeight` is a non-negative whole number.
- `items` is always an array sorted by slot.
- Each item includes normalized `slot`, `name`, `label`, `count`, `weight`, `totalWeight`, `maxStack`, and `stackable` fields.

### `getPlayerContext(playerSrc)`

Returns the main aggregated read model for an online player.

Guaranteed fields:

- `source`, `name`, `online`, and `authenticated` are always present when a context payload is returned.
- `identity`, `character`, `money`, `job`, and `status` may be `nil` when their backing services or state are unavailable.

```lua
{
    source = 12,
    name = 'PlayerName',
    online = true,
    authenticated = true,
    identity = { ... },
    character = { ... } or nil,
    money = { ... },
    job = { ... } or nil,
    status = {
        hunger = 84,
        thirst = 76
    } or nil
}
```

### `notify(playerSrc, message, level)`

Sends a standard feed notification to one online player.

```lua
local ok, errorCode = exports['lsrp_framework']:notify(source, 'Taxi requested.', 'info')
```

Supported levels: `info`, `success`, `warning`, `error`.

### `notifyAll(message, level)`

Broadcasts a framework notification to all online players.

### `formatCurrency(amount)`

Formats an integer amount using the current economy formatter.

### `canAfford(playerSrc, amount)`

```lua
local ok, balance = exports['lsrp_framework']:canAfford(source, 250)
```

### `addMoney(playerSrc, amount, reason, metadata)`

Adds LS$ balance through `lsrp_economy`.

```lua
local ok, money, errorCode = exports['lsrp_framework']:addMoney(source, 500, 'job_payout', {
    jobId = 'taxi_driver'
})
```

### `removeMoney(playerSrc, amount, reason, metadata)`

Removes LS$ balance through `lsrp_economy`.

```lua
local ok, money, errorCode = exports['lsrp_framework']:removeMoney(source, 250, 'store_purchase', {
    shopId = 'downtown_247'
})
```

### `addCash(playerSrc, amount, reason, metadata)`

Credits on-hand cash through `lsrp_economy`.

```lua
local ok, money, errorCode = exports['lsrp_framework']:addCash(source, 500, 'atm_hack', {
    atmId = 'legion_square'
})
```

### `removeCash(playerSrc, amount, reason, metadata)`

Debits on-hand cash through `lsrp_economy`.

```lua
local ok, money, errorCode = exports['lsrp_framework']:removeCash(source, 25000, 'vendor_purchase', {
    vendor = 'vago_contact'
})
```

### `addMoneyByAccountId(accountId, amount, reason, metadata)`

Credits an economy account by `account_id`.

```lua
local ok, balance, errorCode = exports['lsrp_framework']:addMoneyByAccountId(42, 5000, 'vehicle_sale', {
    shopId = 'premium_deluxe'
})
```

### `removeMoneyByAccountId(accountId, amount, reason, metadata)`

Debits an economy account by `account_id`.

```lua
local ok, balance, errorCode = exports['lsrp_framework']:removeMoneyByAccountId(42, 5000, 'vehicle_sale_reversal', {
    shopId = 'premium_deluxe'
})
```

### `hasPermission(playerSrc, permission)`

Checks job permission state through `lsrp_jobs`.

### `hasItem(playerSrc, itemName, amount)`

```lua
local hasItem, ownedCount = exports['lsrp_framework']:hasItem(source, 'phone', 1)
```

### `addItem(playerSrc, itemName, amount, metadata)`

Adds an inventory item through `lsrp_inventory`.

### `removeItem(playerSrc, itemName, amount)`

Removes inventory items through `lsrp_inventory`.

## Callback Exports

### Server: `registerServerCallback(callbackName, handler)`

Registers a framework callback that clients can call through `triggerServerCallback`.

`handler` can be either:

- A local Lua function for in-resource registrations.
- An event name string for cross-resource-safe registrations.

```lua
local ok, errorCode = exports['lsrp_framework']:registerServerCallback('taxi:getDispatch', function(playerSrc, payload, meta)
    local context = exports['lsrp_framework']:getPlayerContext(playerSrc)
    if not context then
        return false, nil, 'player_unavailable'
    end

    return true, {
        player = context,
        filters = payload
    }, nil
end)
```

```lua
AddEventHandler('taxi:framework:getDispatch', function(playerSrc, payload, meta, respond)
    local context = exports['lsrp_framework']:getPlayerContext(playerSrc)
    if not context then
        respond(false, nil, 'player_unavailable')
        return
    end

    respond(true, {
        player = context,
        filters = payload
    }, nil)
end)

local ok, errorCode = exports['lsrp_framework']:registerServerCallback('taxi:getDispatch', 'taxi:framework:getDispatch')
```

### Server: `unregisterServerCallback(callbackName)`

Removes a previously registered server callback.

### Server: `triggerClientCallback(playerSrc, callbackName, payload, timeoutMs)`

Calls a client callback and waits for the standardized envelope.

```lua
local response = exports['lsrp_framework']:triggerClientCallback(source, 'phones:getUiState', {
    includeDrafts = true
}, 3000)

if not response.ok then
    print(response.error)
    return
end

print(json.encode(response.data))
```

Built-in framework server callbacks:

- `lsrp_prejoin:register`
- `lsrp_prejoin:login`

### Client: `registerClientCallback(callbackName, handler)`

Registers a client callback that the server can call through `triggerClientCallback`.

`handler` can be either a local Lua function or an event name string.

```lua
exports['lsrp_framework']:registerClientCallback('phones:getUiState', function(payload, meta)
    return {
        phoneOpen = LocalPlayer.state.phoneOpen == true,
        includeDrafts = payload and payload.includeDrafts == true
    }
end)
```

### Client: `unregisterClientCallback(callbackName)`

Removes a previously registered client callback.

### Client: `triggerServerCallback(callbackName, payload, timeoutMs)`

Calls a server callback and waits for the standardized envelope.

```lua
local response = exports['lsrp_framework']:triggerServerCallback('taxi:getDispatch', {
    onlyOpen = true
}, 3000)

if not response.ok then
    Framework.notify(('Dispatch refresh failed: %s'):format(tostring(response.error)), 'error')
    return
end

print(json.encode(response.data))
```

### Client: `registerNuiCallback(callbackName, handler)`

Wraps `RegisterNUICallback` with the same response envelope used by framework callbacks.

`handler` can be either a local Lua function or an event name string. Use an event name when registering through a framework export from another resource.

```lua
exports['lsrp_framework']:registerNuiCallback('fetchDispatch', function(data, meta)
    local response = exports['lsrp_framework']:triggerServerCallback('taxi:getDispatch', data, 3000)
    return response
end)
```

```lua
AddEventHandler('phones:frameworkNui:fetchDispatch', function(data, meta, respond)
    local response = exports['lsrp_framework']:triggerServerCallback('taxi:getDispatch', data, 3000)
    respond(response)
end)

exports['lsrp_framework']:registerNuiCallback('fetchDispatch', 'phones:frameworkNui:fetchDispatch')
```

## Usage Pattern

For most new resources, prefer this sequence:

1. Read `getPlayerContext(source)` for UI, checks, and display logic.
2. Use `hasPermission`, `hasItem`, and `canAfford` for gates.
3. Use `addMoney`, `removeMoney`, `addItem`, and `removeItem` for mutations.
4. Use `triggerServerCallback`, `triggerClientCallback`, and `registerNuiCallback` for request-response flows.
5. Use `notify` for player-facing status messages instead of resource-specific notify events.

## Still Out Of Scope

- Registries for items, interactions, and phone apps
- Multi-target identity lookups by `stateId` or `accountId`
- Ownership helper contracts for vehicle, housing, and phone systems

Those remain separate framework milestones after the callback layer.