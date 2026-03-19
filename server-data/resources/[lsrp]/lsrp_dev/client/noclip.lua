-- LSRP Dev Tools - Noclip
--
-- Provides a free-camera noclip mode toggled with F1 (default keybind).
-- While active:
--   W/S        - fly forward/back (flat on XY plane; no unintended altitude drift)
--   A/D        - strafe left/right
--   SPACE/CTRL - ascend/descend
--   SHIFT      - 3x speed multiplier
--
-- The ped's collision and invincibility are toggled automatically with noclip.

local noclip = false
local noclip_speed = 0.5
local lastToggleAt = 0
local toggleCooldownMs = 200

local function toggleNoclip()
    local now = GetGameTimer()
    if (now - lastToggleAt) < toggleCooldownMs then
        return
    end

    lastToggleAt = now
    noclip = not noclip

    local ped = PlayerPedId()

    if noclip then
        print('[lsrp_dev] noclip enabled')
        SetEntityCollision(ped, false, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, false)
    else
        print('[lsrp_dev] noclip disabled')
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, false)
    end
end

RegisterCommand('noclip', toggleNoclip, false)
RegisterCommand('+noclip', toggleNoclip, false)
RegisterCommand('-noclip', function()
end, false)

RegisterKeyMapping('+noclip', 'Toggle noclip', 'keyboard', 'F1')

-- Returns the camera's forward direction as a unit vector (pitch + heading).
local function getCamDirection()
    local rot = GetGameplayCamRot(0)
    local pitch = math.rad(rot.x)
    local heading = math.rad(rot.z)

    local x = -math.sin(heading) * math.cos(pitch)
    local y = math.cos(heading) * math.cos(pitch)
    local z = math.sin(pitch)

    return vector3(x, y, z)
end

-- Returns the camera direction projected onto the XY plane so that forward
-- movement does not push the player up or down based on camera pitch.
local function getFlatDirection(dir)
    local len = math.sqrt((dir.x * dir.x) + (dir.y * dir.y))

    if len <= 0.0001 then
        return vector3(0.0, 1.0, 0.0)
    end

    return vector3(dir.x / len, dir.y / len, 0.0)
end

local function setPlayerCoords(coords)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false, true)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        if noclip then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local camDir = getCamDirection()
            local flatDir = getFlatDirection(camDir)

            local forward = 0.0
            local right = 0.0
            local up = 0.0

            if IsControlPressed(0, 32) then forward = forward + 1.0 end -- W
            if IsControlPressed(0, 33) then forward = forward - 1.0 end -- S
            if IsControlPressed(0, 34) then right = right - 1.0 end   -- A
            if IsControlPressed(0, 35) then right = right + 1.0 end   -- D
            if IsControlPressed(0, 22) then up = up + 1.0 end         -- SPACE
            if IsControlPressed(0, 36) then up = up - 1.0 end         -- CTRL

            local speed = noclip_speed
            if IsControlPressed(0, 21) then -- sprint to increase speed
                speed = speed * 3.0
            end

            local verticalSpeed = speed * 0.1

            -- Keep forward/strafe on a flat plane; vertical movement is space/ctrl only.
            local move = flatDir * (forward * speed)

            -- compute right vector from camera
            local rightVec = vector3(flatDir.y, -flatDir.x, 0.0)
            local moveRight = rightVec * (right * speed)

            local newPos = pos + move + moveRight + vector3(0.0, 0.0, up * verticalSpeed)

            -- apply position
            setPlayerCoords(newPos)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
        else
            Citizen.Wait(200)
        end
    end
end)