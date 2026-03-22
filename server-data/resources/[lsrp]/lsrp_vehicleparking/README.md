# LSRP Vehicle Parking System

A comprehensive vehicle parking system for FiveM with zone-based parking, UI management, and full vehicle customization persistence.

## Features

- **Zone-Based Parking**: Uses PolyZone BoxZone for accurate zone detection
- **Interactive UI**: Modern, responsive interface for managing parked vehicles
- **Full Vehicle Persistence**: Stores all vehicle modifications, colors, damage, and extras
- **Ownership System**: Uses license identifiers to track vehicle ownership
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

## Additional Notes

- Transactional retrieval ensures vehicles are marked as `out` only after successful client spawn.
- Custom/addon vehicles resolve model hash from multiple candidates to handle non-spawnable display names.
- `owned_vehicles` table tracks vehicle ownership and parking status.

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

**UI not opening:**
- Verify you're within the interaction distance
- Check browser console (F8 in-game) for JavaScript errors
- Ensure `ui_page` and `files` are correctly set in `fxmanifest.lua`

**Database errors:**
- Ensure `oxmysql` is started before this resource
- Verify database credentials in your server configuration
- Run the SQL schema if you haven't already

**Players can't store vehicles:**
- Check that the player has a license identifier
- Verify the vehicle isn't already parked (unique plate constraint)

## Support

For issues or suggestions, please create an issue on the repository.

## License

This resource is provided as-is for the LSRP project.

## Credits

- **Author**: LSRP Development Team
- **Framework**: Built for FiveM
- **Database**: OxMySQL
