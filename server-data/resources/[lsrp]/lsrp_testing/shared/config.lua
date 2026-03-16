-- LSRP Testing - Shared Configuration
--
-- lsrpTestingConfig controls which PolyZone BoxZones are treated as patrol
-- areas and which one the guard NPC actively defends.
--
-- Fields:
--   showPatrolZoneDebug (bool)  - draw zone outlines in-game for debugging
--   guardZoneName (string)      - name of the zone the guard ped patrols
--   patrolZones (array)         - list of BoxZone definitions:
--     name    (string)          - unique identifier; must match guardZoneName
--     center  {x, y, z}        - world center of the box
--     size    {x, y, z}        - dimensions of the box in metres
--     heading (number)         - rotation of the box in degrees

lsrpTestingConfig = {
	showPatrolZoneDebug = true,
	guardZoneName = 'patrol_zancudo_west',
	patrolZones = {
		{
			name = 'patrol_zancudo_west',
			center = { x = -2303.52, y = 3387.41, z = 31.26 },
			size = { x = 15.0, y = 20.0, z = 2.0 },
			heading = 52.5
		}
	}
}