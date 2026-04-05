# LSRP Phones

## Overview

`lsrp_phones` provides the in-game phone UI, call flow, and phonebook features.

It also integrates with other gameplay systems such as voice, economy, and vehicle parking.

## Main Files

- `client/client.lua`: phone state, prop and animation handling, ringtone, and NUI bridge.
- `server/server.lua`: phonebook persistence, phone number handling, and call routing.
- `html/`: phone UI.

## Controls

- `F4`: open or close the phone by default.

## Current Features

- Incoming and outgoing call flow.
- Persisted player-to-player text messaging with unread counts and conversation threads.
- Phonebook storage with historical backfill for returning players.
- Phone number lookup and assignment.
- Integration with parking data for vehicle lists.
- Taxi app for rider booking and driver dispatch claims through `lsrp_taxi`.
- Balance app with live LS$ and cash updates through `lsrp_economy`.
- Phone UI, phonebook visibility, and live call or message access now require owning a `phone` inventory item.

## Database Tables

- `phonebook_entries`: Stores phonebook data by `state_id` with legacy `license` kept for compatibility.
- `phone_messages`: Stores persisted SMS-style messages between phone numbers.

## Ownership And Seeding

- The resource resolves players by `state_id` first and falls back to legacy license rows when necessary.
- Missing phonebook rows are seeded from `lsrp_core` historical player data in `player_last_positions`.
- Seeded historical entries use `display_name = 'Unknown'` until the player reconnects and their live name is refreshed.
- Phone ownership checks read the `phone` item from `lsrp_inventory` inventories by `state_id` first, then by legacy license.

## Integrations

- `pma-voice`: call audio and routing.
- `lsrp_economy`: balance display or money-related app features.
- `lsrp_taxi`: taxi booking and dispatch app integration.
- `lsrp_vehicleparking`: parked vehicle data for phone apps.
- `lsrp_core`: shared resource dependency.
- `oxmysql`: persistence.

## Notes

- This is a central player-facing UI resource.
- Players can still use world parking zones without a phone; only the phone app is gated by phone ownership.
- When debugging calls, check both the phone resource and `pma-voice` state.
- Balance app integrates with `lsrp_economy` exports and refreshes on both `lsrp_economy:client:balanceUpdated` and `lsrp_economy:client:cashUpdated`.
- Single-client self-hearback is not a reliable phone-call test because `pma-voice` proximity handling does not make a caller hear their own microphone feed locally.