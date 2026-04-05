# LSRP Vehicle Parking System

A comprehensive vehicle parking system for FiveM with zone-based parking, UI management, and full vehicle customization persistence.

## Features

- **Zone-Based Parking**: Uses PolyZone BoxZone for accurate zone detection
- **Interactive UI**: Modern, responsive interface for managing parked vehicles
- **Full Vehicle Persistence**: Stores all vehicle modifications, colors, damage, and extras
- **Ownership System**: Uses `state_id` as the primary owner key with legacy license fallback/migration support
- **Blip System**: Map blips for all parking zones
- **Easy Configuration**: Simple config file for adding/editing parking locations

## Installation

### 1. Database Setup

Run the SQL schema to create the required database table:

```sql
CREATE TABLE IF NOT EXISTS `parked_vehicles` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `license` varchar(60) NOT NULL,
    `vehicle_model` varchar(50) NOT NULL,
    `vehicle_plate` varchar(20) NOT NULL,
    `parking_zone` varchar(100) NOT NULL,
    `vehicle_props` longtext NOT NULL,
    `stored_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_plate` (`vehicle_plate`),
    KEY `license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Or simply execute the `sql/schema.sql` file in your database.

### 2. Resource Installation

1. Ensure required resources are installed and running:
    - `oxmysql` - Database operations
    - `polyzone` - Zone detection system
2. Place `lsrp_vehicleparking` in your `resources/[lsrp]` folder
3. Add to your `server.cfg`:
    ```
    ensure oxmysql
    ensure polyzone
    ensure lsrp_vehicleparking
    ```
4. Restart your server or start the resource: `ensure lsrp_vehicleparking`

## Configuration

Edit `shared/config.lua` to customize parking zones and settings:

```lua
Config.ParkingZones = {
    {
        name = "Legion Square Parking",
        coords = vector3(215.9, -809.1, 30.7),
        size = vector3(20.0, 20.0, 3.0),
        rotation = 340.0,
        maxSlots = 10,
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "Parking"
        }
    },
    -- Add more zones here
}
```

### Configuration Options

- **name**: Display name of the parking zone
- **coords**: Center coordinates of the zone (`vector3(x, y, z)`)
- **size**: Size of the zone box (`vector3(width, length, height)`)
- **rotation**: Rotation of the zone in degrees
- **maxSlots**: Maximum number of vehicles that can be parked (informational)
- **blip**: Map blip configuration (sprite, color, scale, label)

### Other Settings

```lua
Config.OpenKey = 38 -- E key (change to any control ID)
Config.showParkingZoneDebug = false -- Set to true to visualize zone boundaries
Config.StorageFee = 0 -- Fee to store vehicle
Config.RetrievalFee = 0 -- Fee to retrieve vehicle
```

**Debug Mode**: Enable `Config.showParkingZoneDebug = true` to see zone boundaries in-game (helpful when positioning zones).

## Usage

### For Players

1. **Enter a Parking Zone**: Drive or walk into any parking zone marked on the map
2. **Open Menu**: Press **E** when near the zone center to open the parking menu
3. **Park Vehicle**: 
   - Get into your vehicle
   - Ensure you're in the driver seat
   - Click "Park Current Vehicle" in the menu
   - Exit the vehicle (it will be deleted and stored)
4. **Retrieve Vehicle**:
   - Open the parking menu
   - View your parked vehicles
   - Click "Retrieve Vehicle" on the vehicle you want
   - Vehicle will spawn with all modifications intact

### Vehicle Data Stored

The system stores **all** vehicle properties including:

- ✅ Vehicle model and plate
- ✅ All modifications (engine, brakes, transmission, turbo, etc.)
- ✅ Cosmetic mods (bumpers, spoilers, hood, roof, etc.)
- ✅ Wheels and tires (type, custom tires)
- ✅ Colors (primary, secondary, pearlescent, wheel)
- ✅ Custom RGB colors
- ✅ Neon lights (enabled state and color)
- ✅ Window tint
- ✅ Liveries
- ✅ Extras (turned on/off state)
- ✅ Damage (body, engine, fuel tank)
- ✅ Fuel level
- ✅ Dirt level
- ✅ Tire smoke color
- ✅ Xenon lights
- ✅ Horn type

### Ownership And Persistence Model

- Parked and owned vehicles are stored in the `owned_vehicles` table.
- `state_id` is the primary gameplay owner key when `lsrp_core` is available.
- Legacy license-based rows are still supported and are backfilled/migrated on startup.
- Vehicle status is tracked with `parked` and `out` states instead of treating every row as permanently parked.

## Additional Notes

- Retrieval is transactional: the server marks the row as `out` before the spawn request, then restores `status = 'parked'` and refunds the retrieval fee if client spawn fails or times out.
- The client uses the vehicle payload's saved `parkingZone` for spawning, so retrieval still works even if the player has stepped out of the current interaction zone.
- Only one retrieval can be pending per player at a time.
- Custom/addon vehicles resolve the spawn model from multiple candidates, including saved props, to handle rows that contain a non-spawnable display name.
- `owned_vehicles` tracks both ownership and parking status.
- Startup recovery moves stranded `out` vehicles back to `parked` when the server boots with no players online.

## File Structure

```
lsrp_vehicleparking/
├── client/
│   └── client.lua          # Client-side logic, zone detection, vehicle properties
├── server/
│   └── server.lua          # Server-side logic, database operations
├── shared/
│   └── config.lua          # Configuration file
├── html/
│   ├── index.html          # UI structure
│   ├── style.css           # UI styling
│   └── script.js           # UI logic
├── sql/
│   └── schema.sql          # Database schema
├── fxmanifest.lua          # Resource manifest
└── README.md               # This file
```

## API / Events

### Client Events

**lsrp_vehicleparking:client:notify**
```lua
TriggerEvent('lsrp_vehicleparking:client:notify', message, type)
```
Display a notification to the player

### Server Events

Players trigger these events automatically through the UI. They can also be used in other resources:

**lsrp_vehicleparking:server:getParkedVehicles**
```lua
TriggerServerEvent('lsrp_vehicleparking:server:getParkedVehicles', zoneName)
```

**lsrp_vehicleparking:server:storeVehicle**
```lua
TriggerServerEvent('lsrp_vehicleparking:server:storeVehicle', vehicleData, zoneName)
```

**lsrp_vehicleparking:server:retrieveVehicle**
```lua
TriggerServerEvent('lsrp_vehicleparking:server:retrieveVehicle', vehiclePlate)
```

You can also pass a table with `id` and/or `plate`. The server prefers the owned vehicle row id when available.

## Customization

### Change Notification System

By default, the resource uses native GTA notifications. To integrate with your framework's notification system, edit the `lsrp_vehicleparking:client:notify` event in `client/client.lua`:

```lua
RegisterNetEvent('lsrp_vehicleparking:client:notify', function(message, type)
    -- Replace with your notification system
    -- Examples:
    -- ESX: exports['esx_notify']:Notify('info', 5000, message)
    -- QB: exports['QBCore']:Notify(message, type)
    -- ox_lib: exports.ox_lib:notify({description = message, type = type})
end)
```

### Add More Parking Zones

Simply add new entries to the `Config.ParkingZones` table in `shared/config.lua`. Each zone is independent and stores vehicles separately.

### Change UI Colors/Style

Edit `html/style.css` to customize colors, fonts, and layout. The UI uses CSS variables and can be easily themed.

## Troubleshooting

**Vehicles not spawning with modifications:**

**Zone not detecting player:**
- Ensure `polyzone` resource is started before `lsrp_vehicleparking`
- Enable `Config.showParkingZoneDebug = true` to visualize zone boundaries
- Check console for BoxZone errors

**Vehicles not spawning with modifications:**
- Ensure the database is storing the `vehicle_props` column as `longtext`
- Check server console for any Lua errors

**Vehicle retrieval fails after leaving the marker:**
- Retrieval should use the saved parking zone from the server payload, not only the current client zone
- Check for errors around `lsrp_vehicleparking:client:spawnVehicle` or `retrievalSpawnResult`

**Addon/custom vehicle will not retrieve:**
- Verify the saved row contains a spawnable model hash or model name in `vehicle_model` or `vehicle_props.model`
- Rows containing display labels such as `CARNOTFOUND` need a valid underlying model value to spawn

**UI not opening:**
- Verify you're within the interaction distance
- Check browser console (F8 in-game) for JavaScript errors
- Ensure `ui_page` and `files` are correctly set in `fxmanifest.lua`

**Database errors:**
- Ensure `oxmysql` is started before this resource
- Verify database credentials in your server configuration
- Run the SQL schema if you haven't already

**Players can't store vehicles:**
- Check that the player resolves to a valid `state_id` or legacy license owner
- Verify the vehicle isn't already parked (unique plate constraint)

**Dev-spawned owned vehicles park unexpectedly or behave oddly:**
- A DB-backed vehicle should be marked `status = 'out'` when it is spawned into the world
- If a development spawn sets `ownedVehicleId` on entity state while the DB row is still `parked`, parking logic may treat it as already parkable data

## Support

For issues or suggestions, please create an issue on the repository.

## License

This resource is provided as-is for the LSRP project.

## Credits

- **Author**: LSRP Development Team
- **Framework**: Built for FiveM
- **Database**: OxMySQL
