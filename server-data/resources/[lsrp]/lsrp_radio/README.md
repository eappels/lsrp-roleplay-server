# lsrp_radio

Framework-native handheld radio resource for LSRP.

## Features

- Wraps `pma-voice` radio channels behind LSRP-friendly commands and inventory gating.
- Requires owning a `radio` inventory item before a player can join any radio channel.
- Enforces server-side access checks for restricted channels such as police and EMS dispatch.
- Provides a runtime usable item registration so clicking the radio in inventory opens a simple channel prompt.
- Periodically removes players from channels they no longer qualify for after losing the item or going off duty.

## Controls

- `/radio`: open the radio frequency prompt.
- `/radio <channel>`: tune directly to a channel.
- `/radio off`: leave the current channel.
- `/radio status`: show the current or last tuned channel.
- `/radio volume <1-100>`: set the radio volume.
- `/radiovol <1-100>`: volume shortcut.

## Current Restricted Channels

- `1-4`: LSPD Dispatch, on-duty `police_officer` only.
- `5-6`: EMS Dispatch, on-duty `ems_responder` only.
- `9`: Emergency Command, on-duty police or EMS.

All other channels from `10` through `999` are currently public as long as the player owns a handheld radio.

## Main Files

- `shared/config.lua`: channel limits, item name, and restricted-channel rules.
- `server/server.lua`: framework callback registration, inventory item use callback, pma-voice channel checks, and access enforcement.
- `client/client.lua`: player commands, onscreen frequency prompt, and radio volume controls.

## Notes

- This resource depends on `lsrp_framework` and `pma-voice`.
- The inventory item is registered at runtime through the framework, so no manual patching inside `lsrp_inventory` logic is required beyond the base item definition.
- If you change restricted channels, restart both `pma-voice` and `lsrp_radio` to ensure new channel checks are active.