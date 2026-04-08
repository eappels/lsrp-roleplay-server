local RESOURCE_PREFIX = '^2LSRP MapEdits'

local DEFAULT_SEARCH_RADIUS = 12.0
local BARRIER_REMOVAL_ENABLED_BY_DEFAULT = true
local BARRIER_REMOVAL_SCAN_RADIUS = 160.0
local BARRIER_REMOVAL_SCAN_INTERVAL_MS = 900
local MODEL_HIDE_RADIUS = 4.0

local BARRIER_MODEL_IDENTIFIERS = {
'prop_sec_barier_02a',
'prop_sec_barier_02b',
'prop_sec_barrier_ld_01a',
'prop_gate_airport_01',
'prop_gate_airport_01_r',
'prop_fnclink_09gate5',
'0x0E76574C'
}

local barrierRemovalEnabled = BARRIER_REMOVAL_ENABLED_BY_DEFAULT
local barrierModelLookup = {}
local hiddenBarrierPointLookup = {}
local hiddenBarrierPoints = {}

local function notify(message)
print(('[lsrp_mapedits] %s'):format(message))
exports.lsrp_framework:notify(('%s %s'):format(RESOURCE_PREFIX, message))
end

local function toSigned32(value)
local integerValue = math.tointeger(value)

if not integerValue then
integerValue = math.floor(tonumber(value) or 0)
end

integerValue = integerValue & 0xFFFFFFFF

if integerValue >= 0x80000000 then
return integerValue - 0x100000000
end

return integerValue
end

local function parseBarrierIdentifier(rawValue)
if not rawValue then
return nil
end

local trimmed = tostring(rawValue):match('^%s*(.-)%s*$')

if trimmed == '' then
return nil
end

local parsedValue = tonumber(trimmed)

if parsedValue then
return toSigned32(parsedValue)
end

return toSigned32(GetHashKey(trimmed))
end

local function parseRadius(rawValue, fallbackRadius)
local radius = tonumber(rawValue)

if not radius or radius <= 0.0 then
return fallbackRadius
end

return radius
end

local function formatHash(hash)
local unsignedHash = hash

if unsignedHash < 0 then
unsignedHash = unsignedHash & 0xFFFFFFFF
end

return ('0x%08X'):format(unsignedHash)
end

local function formatCoords(coords)
return ('x=%.2f, y=%.2f, z=%.2f'):format(coords.x, coords.y, coords.z)
end

local function distanceBetween(a, b)
local dx = a.x - b.x
local dy = a.y - b.y
local dz = a.z - b.z

return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function requestEntityControl(entity, timeoutMs)
if not DoesEntityExist(entity) then
return false
end

if not NetworkGetEntityIsNetworked(entity) then
return true
end

if NetworkHasControlOfEntity(entity) then
return true
end

local startedAt = GetGameTimer()
local timeout = timeoutMs or 500

NetworkRequestControlOfEntity(entity)

while not NetworkHasControlOfEntity(entity) and (GetGameTimer() - startedAt) < timeout do
Wait(0)
NetworkRequestControlOfEntity(entity)
end

return NetworkHasControlOfEntity(entity)
end

local function makeHiddenPointKey(modelHash, coords)
return ('%d:%d:%d:%d'):format(
modelHash,
math.floor(coords.x * 10.0),
math.floor(coords.y * 10.0),
math.floor(coords.z * 10.0)
)
end

local function rememberHiddenPoint(modelHash, coords)
local pointKey = makeHiddenPointKey(modelHash, coords)

if hiddenBarrierPointLookup[pointKey] then
return
end

hiddenBarrierPointLookup[pointKey] = true
hiddenBarrierPoints[#hiddenBarrierPoints + 1] = {
modelHash = modelHash,
x = coords.x,
y = coords.y,
z = coords.z
}
end

local function applyModelHideAtPoint(point)
CreateModelHide(point.x, point.y, point.z, MODEL_HIDE_RADIUS, point.modelHash, true)
end

local function reapplyNearbyModelHides(origin, radius)
for _, point in ipairs(hiddenBarrierPoints) do
local distance = distanceBetween(origin, point)

if distance <= (radius + 25.0) then
applyModelHideAtPoint(point)
end
end
end

local function removeNearbyBarrierProps(radius)
local ped = PlayerPedId()

if not DoesEntityExist(ped) then
return 0
end

local origin = GetEntityCoords(ped)
local removedCount = 0
local ok, objectPool = pcall(GetGamePool, 'CObject')

if not ok or type(objectPool) ~= 'table' then
return 0
end

for _, entity in ipairs(objectPool) do
if DoesEntityExist(entity) then
local modelHash = toSigned32(GetEntityModel(entity))

if barrierModelLookup[modelHash] then
local coords = GetEntityCoords(entity)

if distanceBetween(origin, coords) <= radius then
applyModelHideAtPoint({ modelHash = modelHash, x = coords.x, y = coords.y, z = coords.z })
rememberHiddenPoint(modelHash, coords)

requestEntityControl(entity, 600)
SetEntityAsMissionEntity(entity, true, true)
DeleteEntity(entity)

if DoesEntityExist(entity) then
SetEntityCollision(entity, false, false)
SetEntityVisible(entity, false, false)
end

removedCount = removedCount + 1
end
end
end
end

reapplyNearbyModelHides(origin, radius)

return removedCount
end

local function printBarrierDebug(radius)
local ped = PlayerPedId()

if not DoesEntityExist(ped) then
return
end

local origin = GetEntityCoords(ped)
local found = {}
local ok, objectPool = pcall(GetGamePool, 'CObject')

if not ok or type(objectPool) ~= 'table' then
notify('Barrier debug: CObject pool unavailable.')
return
end

for _, entity in ipairs(objectPool) do
if DoesEntityExist(entity) then
local modelHash = toSigned32(GetEntityModel(entity))

if barrierModelLookup[modelHash] then
local coords = GetEntityCoords(entity)
local distance = distanceBetween(origin, coords)

if distance <= radius then
found[#found + 1] = {
entity = entity,
modelHash = modelHash,
coords = coords,
distance = distance
}
end
end
end
end

table.sort(found, function(a, b)
return a.distance < b.distance
end)

if #found == 0 then
notify(('Barrier debug: no configured barriers within %.1fm.'):format(radius))
return
end

notify(('Barrier debug: found %d configured barriers within %.1fm.'):format(#found, radius))

for index = 1, math.min(#found, 10) do
local item = found[index]
print(('[lsrp_mapedits] barrier[%d] handle=%s model=%s distance=%.2fm coords=%s'):format(
index,
item.entity,
formatHash(item.modelHash),
item.distance,
formatCoords(item.coords)
))
end
end

for _, identifier in ipairs(BARRIER_MODEL_IDENTIFIERS) do
local modelHash = parseBarrierIdentifier(identifier)

if modelHash then
barrierModelLookup[modelHash] = identifier
end
end

CreateThread(function()
while true do
if barrierRemovalEnabled then
removeNearbyBarrierProps(BARRIER_REMOVAL_SCAN_RADIUS)
end

Wait(BARRIER_REMOVAL_SCAN_INTERVAL_MS)
end
end)

RegisterCommand('barrierremove', function(_, args)
local mode = string.lower(args[1] or '')

if mode == 'help' then
notify('Usage: /barrierremove [on|off|status|once] [radius]')
return
end

if mode == 'status' then
local modelCount = 0

for _ in pairs(barrierModelLookup) do
modelCount = modelCount + 1
end

notify(('Barrier removal is %s. Models tracked: %d'):format(
barrierRemovalEnabled and 'enabled' or 'disabled',
modelCount
))
return
end

if mode == 'on' then
barrierRemovalEnabled = true
local removedNow = removeNearbyBarrierProps(BARRIER_REMOVAL_SCAN_RADIUS)
notify(('Barrier removal enabled. Removed %d nearby props.'):format(removedNow))
return
end

if mode == 'off' then
barrierRemovalEnabled = false
notify('Barrier removal disabled.')
return
end

if mode == 'once' then
local radius = parseRadius(args[2], BARRIER_REMOVAL_SCAN_RADIUS)
local removedNow = removeNearbyBarrierProps(radius)
notify(('Removed %d barrier props within %.1fm.'):format(removedNow, radius))
return
end

barrierRemovalEnabled = not barrierRemovalEnabled

if barrierRemovalEnabled then
local removedNow = removeNearbyBarrierProps(BARRIER_REMOVAL_SCAN_RADIUS)
notify(('Barrier removal enabled. Removed %d nearby props.'):format(removedNow))
else
notify('Barrier removal disabled.')
end
end, false)

RegisterCommand('barrierdebug', function(_, args)
local radius = parseRadius(args[1], DEFAULT_SEARCH_RADIUS)
printBarrierDebug(radius)
end, false)

RegisterCommand('barrier', function(_, args)
local radius = parseRadius(args[1], DEFAULT_SEARCH_RADIUS)
local removedNow = removeNearbyBarrierProps(radius)
notify(('Removed %d barrier props within %.1fm.'):format(removedNow, radius))
end, false)
