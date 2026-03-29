# lsrp_hacking

ATM hacking gameplay resource for LSRP, including the vendor flow, ATM detection, animation scene, and laptop puzzle UI.

## Included Files

- `fxmanifest.lua`: Resource manifest and dependency declaration.
- `shared/config.lua`: Shared ATM, vendor, reward, and puzzle configuration.
- `client/client.lua`: ATM detection, vendor interaction, synchronized hack animation, and puzzle UI callbacks.
- `server/server.lua`: Vendor purchase flow, ATM cooldowns, and successful hack payouts.
- `html/`: NUI files for the laptop hacking puzzle shown during ATM intrusions.

## Notes

Set `Config.Debug = true` in `shared/config.lua` to enable basic startup logging while developing the resource.

`Config.HackPuzzle` controls the time limit and node counts used by the ATM laptop puzzle. The hack always runs exactly 3 stages, and the ATM payout is only awarded when the player completes all 3 before time expires.