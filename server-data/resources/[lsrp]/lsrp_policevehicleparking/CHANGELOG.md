# Vehicle Parking Changelog

## 2026-04-09

- Added vehicle trunk storage MVP backed by persistent inventory stashes.
- Keyed trunk storage by owned vehicle id so plate renames do not orphan stored items.
- Added client prompt, `G` keybind, and `/vehstorage` command for nearby trunk access.
- Added lock-state gating so locked vehicles block trunk access until they are unlocked.
- Added server-side ownership and proximity validation for trunk access.

## PolyZone Update

## Changes Made

The `lsrp_policevehicleparking` resource has been updated to use **PolyZone BoxZone** for zone detection:

### Before (Manual Box Detection)
- Simple manual distance and box calculations
- Custom zone detection thread
- No visualization capabilities

### After (PolyZone BoxZone)
- Uses PolyZone's BoxZone library
- Consistent with the wider LSRP PolyZone pattern
- Built-in zone visualization for debugging
- More optimized and reliable
- Better zone boundary detection

## Files Modified

1. **fxmanifest.lua**
   - Added `@polyzone/client.lua` and `@polyzone/BoxZone.lua` client scripts
   - Added `polyzone` to dependencies
   
2. **client/client.lua**
   - Replaced manual zone detection with `BoxZone:Create()`
   - Uses `zone:onPlayerInOut()` callbacks for entry and exit handling
   - Added `createParkingZones()` function
   - Added `destroyParkingZones()` function for cleanup
   - Simplified interaction prompt thread

3. **shared/config.lua**
   - Added `Config.showParkingZoneDebug` option
   - Removed unused `Config.MaxRenderDistance` and `Config.InteractionDistance`

4. **Documentation**
   - Updated README.md with polyzone dependency
   - Updated INSTALL.txt with polyzone requirement
   - Updated CHECKLIST.txt with polyzone verification steps
   - Updated FEATURES.md to mention BoxZone system

## New Features

### Debug Mode
Enable zone visualization to see exact boundaries:
```lua
Config.showParkingZoneDebug = true
```
This will draw zone boxes in-game (red/green depending on if you're inside).

## Installation Requirements

**Important**: You must now ensure `polyzone` is started **before** `lsrp_policevehicleparking`.

### server.cfg Order:
```
ensure oxmysql
ensure polyzone         # <-- Must be before lsrp_policevehicleparking
ensure lsrp_policevehicleparking
```

## Benefits

âœ… **Consistency** - Uses same zone system as other LSRP resources  
âœ… **Reliability** - PolyZone is battle-tested and optimized  
âœ… **Debug Tools** - Built-in zone visualization  
âœ… **Future-Proof** - Easier to maintain and extend  
âœ… **Performance** - More efficient than manual detection  

## Testing

After updating:
1. Ensure `polyzone` is in your resources folder
2. Update your `server.cfg` to include `ensure polyzone`
3. Restart the server
4. Look for console messages:
   ```
   [lsrp_policevehicleparking] Created zone: Legion Square Parking
   [lsrp_policevehicleparking] Created zone: Airport Parking
   [lsrp_policevehicleparking] Created zone: Downtown Parking
   ```
5. Enable debug mode temporarily to verify zones are positioned correctly

## Troubleshooting

**If zones don't work:**
- Check that `polyzone` is started (look in server console)
- Verify it's started BEFORE `lsrp_policevehicleparking` in server.cfg
- Enable `Config.showParkingZoneDebug = true` to visualize zones
- Check F8 console for any BoxZone errors

**BoxZone not available error:**
```
[lsrp_policevehicleparking] BoxZone is not available. Ensure polyzone is started.
```
Fix: Add `ensure polyzone` to your server.cfg before `ensure lsrp_policevehicleparking`

---

**All changes are backward compatible with your existing database.** No database updates needed.
