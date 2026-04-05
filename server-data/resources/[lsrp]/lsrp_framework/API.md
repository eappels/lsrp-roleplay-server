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
    identity = { ... },
    money = { ... },
    job = { ... } or nil,
    status = {
        hunger = 84,
        thirst = 76
    } or nil
}
```

Returns `nil` if the player source is invalid or offline.

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

## Out Of Scope In v1

- Callbacks/RPC
- Notification facade
- Registries for items, jobs, interactions, and apps
- Client-side API helpers
- Multi-target identity lookups by `stateId` or `accountId`

Those should be added as separate, deliberate API versions instead of growing the first pass opportunistically.