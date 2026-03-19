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
- Phonebook storage.
- Phone number lookup and assignment.
- Integration with parking data for vehicle lists.

## Integrations

- `pma-voice`: call audio and routing.
- `lsrp_economy`: balance display or money-related app features.
- `lsrp_vehicleparking`: parked vehicle data for phone apps.
- `lsrp_core`: shared resource dependency.
- `oxmysql`: persistence.

## Notes

- This is a central player-facing UI resource.
- When debugging calls, check both the phone resource and `pma-voice` state.