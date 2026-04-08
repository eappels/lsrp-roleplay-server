# LSRP Framework API

Version: `1.0.0`

`lsrp_framework` is the public server-side facade for the LSRP platform.

## Design Rules

- Treat these exports as the stable contract for new LSRP resources.
- Do not rely on internal DB schema or internal resource cache layout.
- Prefer `getPlayerContext` for read-heavy flows.
- Use the focused write exports for money and inventory changes.

## Exports

### `getApiVersion()`

Returns the current facade API version string.

Return value:

```lua
'1.0.0'
```

### `getIdentity(playerSrc)`

Returns normalized identity data for an online player.

Return shape:

```lua
{
    license = 'license:...',
    accountId = 123,
    stateId = 123
}
```

Returns `nil` if the player is invalid or identity is unavailable.

### `isAuthenticated(playerSrc)`

Returns `true` when the current online player has completed prejoin login for this session.

### `getCharacter(playerSrc)`

Returns normalized character data for an online player.

Return shape:

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

Returns `nil` if the player has no character yet.

### `hasCharacter(playerSrc)`

Returns `true` when `getCharacter(playerSrc)` would return a character payload.

### `createCharacter(playerSrc, payload)`

Creates the first character for the current player.

Return values:

```lua
local response = exports['lsrp_framework']:createCharacter(source, {
    firstName = 'John',
    lastName = 'Doe',
    dateOfBirth = '1998-03-16',
    sex = 'male'
})
```

Response shape:

```lua
{
    ok = true,
    created = true,
    character = { ... }
}
```

### `getMoney(playerSrc)`

Returns normalized economy data.

Return shape:

```lua
{
    balance = 2500,
    cash = 120,
    currency = 'LS$',
    accountId = 123
}
```

Returns `nil` if economy data is unavailable.

### `getJob(playerSrc)`

Returns normalized employment data for the current player.

Return shape:

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

Returns `nil` if the player has no active employment.

### `isEmployedAs(playerSrc, jobId)`

Returns `true` if the online player is employed in the requested job.

### `isOnDuty(playerSrc, jobId)`

Returns `true` if the online player is on duty for the requested job. If `jobId` is omitted, it checks for any active duty state in the jobs service.

### `setDuty(playerSrc, shouldBeOnDuty)`

Updates duty state through `lsrp_jobs`.

Return values:

```lua
local ok, job, errorCode = exports['lsrp_framework']:setDuty(source, true)
```

`job` is the normalized `getJob()` payload after the change.

### `registerJobDefinition(definition)`

Registers a gameplay job definition through `lsrp_jobs`.

Return values:

```lua
local ok, errorCode = exports['lsrp_framework']:registerJobDefinition(Config.JobDefinition)
```

### `employPlayer(playerSrc, jobId, gradeId)`

Assigns an online player to a job through `lsrp_jobs`.

Return values:

```lua
local ok, job, errorCode = exports['lsrp_framework']:employPlayer(source, 'police_officer', 'officer')
```

`job` is the normalized `getJob()` payload after the assignment.

### `getInventory(playerSrc)`

Returns the sanitized inventory payload exposed by `lsrp_inventory`.

Return shape:

```lua
{
    slots = 15,
    maxWeight = 25000,
    items = {
        {
            slot = 1,
            name = 'phone',
            label = 'Phone',
            count = 1,
            weight = 250,
            totalWeight = 250,
            image = 'phone.png',
            description = 'A mobile phone.',
            maxStack = 1,
            stackable = false,
            use = nil,
            metadata = nil
        }
    }
}
```

Returns `nil` if inventory is unavailable.

### `getPlayerContext(playerSrc)`

Returns the main aggregated read model for an online player.

Return shape:

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

Returns `nil` if the player source is invalid or offline.

### `notify(playerSrc, message, level)`

Sends a standard feed notification to one online player.

Return values:

```lua
local ok, errorCode = exports['lsrp_framework']:notify(source, 'Taxi requested.', 'info')
```

`level` is optional. Current supported values are `info`, `success`, `warning`, and `error`.

### `notifyAll(message, level)`

Broadcasts a framework notification to all online players.

### `formatCurrency(amount)`

Formats an integer amount using the current economy formatter.

### `canAfford(playerSrc, amount)`

Return values:

```lua
local ok, balance = exports['lsrp_framework']:canAfford(source, 250)
```

### `addMoney(playerSrc, amount, reason, metadata)`

Adds LS$ balance through `lsrp_economy`.

Return values:

```lua
local ok, money, errorCode = exports['lsrp_framework']:addMoney(source, 500, 'job_payout', {
    jobId = 'taxi_driver'
})
```

`money` is the normalized `getMoney()` payload after the change.

### `removeMoney(playerSrc, amount, reason, metadata)`

Removes LS$ balance through `lsrp_economy`.

Return values:

```lua
local ok, money, errorCode = exports['lsrp_framework']:removeMoney(source, 250, 'store_purchase', {
    shopId = 'downtown_247'
})
```

### `hasPermission(playerSrc, permission)`

Checks job permission state through `lsrp_jobs`.

### `hasItem(playerSrc, itemName, amount)`

Return values:

```lua
local hasItem, ownedCount = exports['lsrp_framework']:hasItem(source, 'phone', 1)
```

### `addItem(playerSrc, itemName, amount, metadata)`

Adds an inventory item through `lsrp_inventory`.

### `removeItem(playerSrc, itemName, amount)`

Removes inventory items through `lsrp_inventory`.

## Usage Pattern

For most new resources, prefer this sequence:

1. Read `getPlayerContext(source)` for UI, checks, and display logic.
2. Use `hasPermission`, `hasItem`, and `canAfford` for gates.
3. Use `addMoney`, `removeMoney`, `addItem`, and `removeItem` for mutations.
4. Use `notify` for player-facing status messages instead of resource-specific notify events.

## Out Of Scope In v1

- Callbacks/RPC
- Notification facade
- Registries for items, jobs, interactions, and apps
- Client-side API helpers
- Multi-target identity lookups by `stateId` or `accountId`

Those should be added as separate, deliberate API versions instead of growing the first pass opportunistically.