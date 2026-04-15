RegisterNetEvent('codem-radialmenu:client:ToggleDoor', function(data)
    local vehicle = getNearestVeh()
    if not vehicle then
        Framework:Notify(nil, 'No vehicle nearby', 'error')
        return
    end

    local door = data.door
    if not door then return end

    local isOpen = GetVehicleDoorAngleRatio(vehicle, door) > 0.0

    if isOpen then
        SetVehicleDoorShut(vehicle, door, false)
    else
        SetVehicleDoorOpen(vehicle, door, false, false)
    end
end)

RegisterNetEvent('codem-radialmenu:client:ChangeSeat', function(data)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then
        Framework:Notify(nil, 'You are not in a vehicle', 'error')
        return
    end

    local seat = data.seat
    if not seat then return end

    if not IsVehicleSeatFree(vehicle, seat) then
        Framework:Notify(nil, 'Seat is occupied', 'error')
        return
    end

    local speed = GetEntitySpeed(vehicle) * 3.6 -- Convert to km/h
    local maxSpeed = Config.Limits.MaxSpeedForSeatChange
    if speed > maxSpeed then
        Framework:Notify(nil, 'Vehicle is moving too fast', 'error')
        return
    end

    if GetResourceState('qbx_seatbelt') == 'started' then
        local hasHarness = exports.qbx_seatbelt:HasHarness()
        if hasHarness then
            Framework:Notify(nil, 'Remove harness first', 'error')
            return
        end
    end

    SetPedIntoVehicle(ped, vehicle, seat)
    Framework:Notify(nil, 'Seat changed', 'success')
end)

RegisterNetEvent('codem-radialmenu:client:ToggleExtra', function(data)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not vehicle or vehicle == 0 then
        Framework:Notify(nil, 'You are not in a vehicle', 'error')
        return
    end

    local extra = data.extra
    if not extra then return end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        Framework:Notify(nil, 'You must be the driver', 'error')
        return
    end

    if not DoesExtraExist(vehicle, extra) then
        Framework:Notify(nil, 'Extra does not exist', 'error')
        return
    end

    local isOn = IsVehicleExtraTurnedOn(vehicle, extra)
    SetVehicleExtra(vehicle, extra, isOn)

    Framework:Notify(nil, 'Extra ' .. (isOn and 'disabled' or 'enabled'), 'success')
end)

RegisterNetEvent('codem-radialmenu:client:FlipVehicle', function()
    local ped = PlayerPedId()
    local vehicle = getNearestVeh()

    if not vehicle then
        Framework:Notify(nil, 'No vehicle nearby', 'error')
        return
    end

    local pedCoords = GetEntityCoords(ped)
    local vehCoords = GetEntityCoords(vehicle)
    local maxDistance = Config.Distances.VehicleInteraction

    if #(pedCoords - vehCoords) > maxDistance then
        Framework:Notify(nil, 'Too far from vehicle', 'error')
        return
    end

    if Framework.Type == 'qbx' then
        if GetResourceState('ox_lib') == 'started' and lib and lib.progressBar then
            if lib.progressBar({
                    duration = 15000,
                    label = 'Flipping vehicle',
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }
                }) then
                SetVehicleOnGroundProperly(vehicle)
                Framework:Notify(nil, 'Vehicle flipped', 'success')
            else
                Framework:Notify(nil, 'Flipping cancelled', 'error')
            end
        end
    elseif Framework.Type == 'qbcore' then
        if Framework.Object and Framework.Object.Functions and Framework.Object.Functions.Progressbar then
            Framework.Object.Functions.Progressbar('flip_vehicle', 'Flipping vehicle', 15000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = 'mini@repair',
                anim = 'fixing_a_ped',
                flags = 1,
            }, {}, {}, function()
                SetVehicleOnGroundProperly(vehicle)
                Framework:Notify(nil, 'Vehicle flipped', 'success')
            end, function()
                Framework:Notify(nil, 'Flipping cancelled', 'error')
            end)
        end
    else
        RequestAnimDict('mini@repair')
        while not HasAnimDictLoaded('mini@repair') do
            Wait(10)
        end

        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 8.0, -8.0, -1, 1, 0, false, false, false)

        local elapsed = 0
        local duration = 15000
        local interval = 100
        local cancelled = false

        while elapsed < duration do
            Wait(interval)
            elapsed = elapsed + interval

            if #(GetEntityCoords(ped) - vehCoords) > 5.0 or IsEntityDead(ped) then
                cancelled = true
                break
            end
        end

        StopAnimTask(ped, 'mini@repair', 'fixing_a_ped', 1.0)

        if not cancelled then
            SetVehicleOnGroundProperly(vehicle)
            Framework:Notify(nil, 'Vehicle flipped', 'success')
        else
            Framework:Notify(nil, 'Flipping cancelled', 'error')
        end
    end
end)

function getNearestVeh()
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end

    local offset = GetOffsetFromEntityInWorldCoords(ped, 0.0, 20.0, 0.0)
    local rayHandle = CastRayPointToPoint(pedCoords.x, pedCoords.y, pedCoords.z, offset.x, offset.y, offset.z, 10, ped, 0)
    local _, hit, _, _, entityHit = GetRaycastResult(rayHandle)

    if hit and IsEntityAVehicle(entityHit) then
        local vehCoords = GetEntityCoords(entityHit)
        local maxDistance = Config.Distances.VehicleInteraction
        if #(pedCoords - vehCoords) <= maxDistance then
            return entityHit
        end
    end

    return nil
end
