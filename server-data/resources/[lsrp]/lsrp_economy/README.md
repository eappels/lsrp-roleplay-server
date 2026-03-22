# LSRP Economy

## Overview

`lsrp_economy` manages LS$ balances and transaction history.

It is the main money service used by gameplay systems that need to charge, refund, or transfer currency.

## Main Features

- Persistent player balances.
- Persistent numeric Account IDs for human-friendly transfers.
- Transaction logging.
- Server exports for balance operations.
- Client balance sync for UI and gameplay checks.

## Main Files

- `server/server.lua`: balance persistence, transaction logging, admin commands, and exports.
- `client/client.lua`: local balance state and formatting helpers.

## Commands

- `/lsbalance`: show your current balance.
- `/payls <accountId> <amount>`: transfer LS$ to another account (online or offline).
- `/givels <id> <amount>`: admin grant LS$.
- `/takels <id> <amount>`: admin remove LS$.
- `/setls <id> <amount>`: admin set LS$.

## Important Exports

- `getBalance(playerSrc)`
- `getAccountId(playerSrc)`
- `formatCurrency(amount)`
- `canAfford(playerSrc, amount)`
- `addBalance(playerSrc, amount, reason, metadata)`
- `removeBalance(playerSrc, amount, reason, metadata)`
- `setBalance(playerSrc, amount, reason, metadata)`
- `transferBalance(fromSrc, toSrc, amount, reason, metadata)`

## Database Tables

- `lsrp_economy_balances`: Stores player balances keyed by FiveM license.
- `lsrp_economy_transactions`: Logs all transactions with metadata.

## Integrations

Used by:

- `lsrp_phones`
- `lsrp_vehicleshop`
- `lsrp_vehicleparking`

## Notes

- This resource uses `oxmysql`.
- Admin money commands should stay permission-gated.
- Ensure runtime cache tables are initialized at startup to avoid nil-index crashes.
- Common error: Parse error near EOF in `server/server.lua` can occur if `safeQueryAwait` is incomplete.