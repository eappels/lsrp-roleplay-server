
local inTrunk = false
local isKidnapped = false
local trunkCam = nil
local currentVehicle = nil

local disabledTrunk = {
    [`penetrator`] = true,
    [`vacca`] = true,
    [`monroe`] = true,
    [`turismor`] = true,
    [`osiris`] = true,
    [`comet`] = true,
    [`ardent`] = true,
    [`jester`] = true,
    [`nero`] = true,
    [`nero2`] = true,
    [`vagner`] = true,
    [`infernus`] = true,
    [`zentorno`] = true,
    [`comet2`] = true,
    [`comet3`] = true,
    [`comet4`] = true,
    [`bullet`] = true,
}

local function DrawText3Ds(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function TrunkCam(bool)
    if bool then
        local vehicle = GetEntityAttachedTo(PlayerPedId())
        if not DoesEntityExist(vehicle) then return end

        local vehCoords = GetEntityCoords(vehicle)
        local vehHeading = GetEntityHeading(vehicle)
        local camCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -5.5, 0.0)

        RenderScriptCams(false, false, 0, 1, 0)
        if trunkCam then
            DestroyCam(trunkCam, false)
        end

        trunkCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamActive(trunkCam, true)
        SetCamCoord(trunkCam, camCoords.x, camCoords.y, camCoords.z + 2.0)
        SetCamRot(trunkCam, -2.5, 0.0, vehHeading, 0.0)
        RenderScriptCams(true, false, 0, true, true)
    else
        RenderScriptCams(false, false, 0, 1, 0)
        if trunkCam then
            DestroyCam(trunkCam, false)
            trunkCam = nil
        end
    end
end

local function IsTrunkBusy(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)

    if Framework.Type == 'qbx' then
        return lib.callback.await('codem-trunk:server:getTrunkBusy', false, plate)
    elseif Framework.Type == 'qbcore' then
        local p = promise.new()
        Framework.Object.Functions.TriggerCallback('codem-trunk:server:getTrunkBusy', function(busy)
            p:resolve(busy)
        end, plate)
        return Citizen.Await(p)
    else
        return false
    end
end

local function SetTrunkBusy(vehicle, busy)
    local plate = GetVehicleNumberPlateText(vehicle)
    TriggerServerEvent('codem-trunk:server:setTrunkBusy', plate, busy)
end

RegisterNetEvent('codem-radialmenu:client:GetInTrunk', function()
    local ped = PlayerPedId()
    local vehicle = getNearestVeh()

    if not vehicle or vehicle == 0 then
        Framework:Notify(nil, 'No vehicle nearby', 'error')
        return
    end

    local pedCoords = GetEntityCoords(ped)
    local vehCoords = GetEntityCoords(vehicle)

    if #(pedCoords - vehCoords) > Config.Distances.TrunkEntry then
        Framework:Notify(nil, 'Too far from trunk', 'error')
        return
    end

    if inTrunk then
        Framework:Notify(nil, 'Already in trunk', 'error')
        return
    end

    if disabledTrunk[GetEntityModel(vehicle)] then
        Framework:Notify(nil, 'This vehicle has no trunk space', 'error')
        return
    end

    local vehClass = GetVehicleClass(vehicle)
    local trunkClass = Config.TrunkClasses[vehClass]

    if not trunkClass or not trunkClass.allowed then
        Framework:Notify(nil, 'This vehicle type cannot be used', 'error')
        return
    end

    if GetVehicleDoorAngleRatio(vehicle, 5) <= 0.0 then
        Framework:Notify(nil, 'Trunk is closed', 'error')
        return
    end

    if IsTrunkBusy(vehicle) then
        Framework:Notify(nil, 'Someone is already in trunk', 'error')
        return
    end

    local offset = {
        x = trunkClass.x,
        y = trunkClass.y,
        z = trunkClass.z,
    }

    RequestAnimDict('fin_ext_p1-7')
    while not HasAnimDictLoaded('fin_ext_p1-7') do
        Wait(0)
    end

    TaskPlayAnim(ped, 'fin_ext_p1-7', 'cs_devin_dual-7', 8.0, 8.0, -1, 1, 999.0, 0, 0, 0)
    AttachEntityToEntity(ped, vehicle, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 40.0, true, true, false, true, 20, true)

    inTrunk = true
    currentVehicle = vehicle
    SetTrunkBusy(vehicle, true)

    Wait(500)
    SetVehicleDoorShut(vehicle, 5, false)

    Framework:Notify(nil, 'Entered trunk - Press E to exit', 'success')
    TrunkCam(true)
end)

RegisterNetEvent('codem-radialmenu:client:GetOutTrunk', function()
    if not inTrunk then return end

    local ped = PlayerPedId()
    local vehicle = GetEntityAttachedTo(ped)

    if not DoesEntityExist(vehicle) then
        inTrunk = false
        isKidnapped = false
        TrunkCam(false)
        return
    end

    if GetVehicleDoorAngleRatio(vehicle, 5) <= 0.0 then
        Framework:Notify(nil, 'Trunk is closed', 'error')
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local vehCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -5.0, 0.0)

    DetachEntity(ped, true, true)
    ClearPedTasks(ped)
    SetEntityCoords(ped, vehCoords.x, vehCoords.y, vehCoords.z)
    SetEntityCollision(ped, true, true)

    inTrunk = false
    isKidnapped = false
    SetTrunkBusy(vehicle, false)
    currentVehicle = nil

    TrunkCam(false)
    Framework:Notify(nil, 'Exited trunk', 'success')
end)

RegisterNetEvent('codem-trunk:client:GetIn', function()
    TriggerEvent('codem-radialmenu:client:GetInTrunk')
end)

RegisterNetEvent('codem-trunk:client:InitKidnapTrunk', function()
    local ped = PlayerPedId()
    local vehicle = getNearestVeh()

    if not vehicle or vehicle == 0 then
        Framework:Notify(nil, 'No vehicle nearby', 'error')
        return
    end

    if GetVehicleDoorAngleRatio(vehicle, 5) <= 0.0 then
        Framework:Notify(nil, 'Trunk must be open', 'error')
        return
    end

    if IsTrunkBusy(vehicle) then
        Framework:Notify(nil, 'Trunk is occupied', 'error')
        return
    end

    local closestPlayer, closestDistance = -1, -1
    local players = GetActivePlayers()
    local myCoords = GetEntityCoords(ped)

    for _, player in ipairs(players) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(myCoords - targetCoords)

            if closestDistance == -1 or distance < closestDistance then
                closestPlayer = player
                closestDistance = distance
            end
        end
    end

    if closestPlayer == -1 or closestDistance > 2.0 then
        Framework:Notify(nil, 'No player nearby', 'error')
        return
    end

    local targetId = GetPlayerServerId(closestPlayer)
    TriggerServerEvent('codem-trunk:server:KidnapTrunk', targetId, VehToNet(vehicle))
    Framework:Notify(nil, 'Putting player in trunk...', 'info')
end)

RegisterNetEvent('codem-trunk:client:KidnapGetIn', function(vehicleNet)
    local vehicle = NetToVeh(vehicleNet)

    if not DoesEntityExist(vehicle) then
        Framework:Notify(nil, 'Vehicle not found', 'error')
        return
    end

    if inTrunk then
        Framework:Notify(nil, 'Already in trunk', 'error')
        return
    end

    local ped = PlayerPedId()

    if disabledTrunk[GetEntityModel(vehicle)] then
        Framework:Notify(nil, 'This vehicle has no trunk space', 'error')
        return
    end

    local vehClass = GetVehicleClass(vehicle)
    local trunkClass = Config.TrunkClasses[vehClass]

    if not trunkClass or not trunkClass.allowed then
        Framework:Notify(nil, 'This vehicle type cannot be used', 'error')
        return
    end

    local offset = {
        x = trunkClass.x,
        y = trunkClass.y,
        z = trunkClass.z,
    }

    RequestAnimDict('fin_ext_p1-7')
    while not HasAnimDictLoaded('fin_ext_p1-7') do
        Wait(0)
    end

    TaskPlayAnim(ped, 'fin_ext_p1-7', 'cs_devin_dual-7', 8.0, 8.0, -1, 1, 999.0, 0, 0, 0)
    AttachEntityToEntity(ped, vehicle, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 40.0, true, true, false, true, 20, true)

    inTrunk = true
    isKidnapped = true
    currentVehicle = vehicle
    SetTrunkBusy(vehicle, true)

    Wait(500)
    SetVehicleDoorShut(vehicle, 5, false)

    Framework:Notify(nil, 'You were kidnapped! Press E to try to escape', 'error')
    TrunkCam(true)
end)

RegisterNetEvent('codem-radialmenu:trunk:client:Door', function(plate, door, open)
    local vehicles = GetGamePool('CVehicle')

    for _, veh in ipairs(vehicles) do
        if GetVehicleNumberPlateText(veh) == plate then
            if open then
                SetVehicleDoorOpen(veh, door, false, false)
            else
                SetVehicleDoorShut(veh, door, false)
            end
            break
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if trunkCam and inTrunk then
            sleep = 0
            local vehicle = GetEntityAttachedTo(PlayerPedId())
            if DoesEntityExist(vehicle) then
                local camCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -5.5, 0.0)
                local vehHeading = GetEntityHeading(vehicle)
                SetCamRot(trunkCam, -2.5, 0.0, vehHeading, 0.0)
                SetCamCoord(trunkCam, camCoords.x, camCoords.y, camCoords.z + 2.0)
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if inTrunk then
            local ped = PlayerPedId()
            local vehicle = GetEntityAttachedTo(ped)

            if DoesEntityExist(vehicle) then
                sleep = 0
                local drawPos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.0)

                if not isKidnapped then
                    DrawText3Ds(drawPos.x, drawPos.y, drawPos.z + 0.75, '[E] Get Out of Trunk')
                    if IsControlJustPressed(0, 38) then
                        TriggerEvent('codem-radialmenu:client:GetOutTrunk')
                        Wait(100)
                    end

                    if GetVehicleDoorAngleRatio(vehicle, 5) > 0.0 then
                        DrawText3Ds(drawPos.x, drawPos.y, drawPos.z + 0.5, '[G] Close Trunk')
                        if IsControlJustPressed(0, 47) then
                            local plate = GetVehicleNumberPlateText(vehicle)
                            if not IsVehicleSeatFree(vehicle, -1) then
                                TriggerServerEvent('codem-radialmenu:trunk:server:Door', false, plate, 5)
                            else
                                SetVehicleDoorShut(vehicle, 5, false)
                            end
                            Wait(100)
                        end
                    else
                        DrawText3Ds(drawPos.x, drawPos.y, drawPos.z + 0.5, '[G] Open Trunk')
                        if IsControlJustPressed(0, 47) then
                            local plate = GetVehicleNumberPlateText(vehicle)
                            if not IsVehicleSeatFree(vehicle, -1) then
                                TriggerServerEvent('codem-radialmenu:trunk:server:Door', true, plate, 5)
                            else
                                SetVehicleDoorOpen(vehicle, 5, false, false)
                            end
                            Wait(100)
                        end
                    end
                else
                    if GetVehicleDoorAngleRatio(vehicle, 5) > 0.0 then
                        DrawText3Ds(drawPos.x, drawPos.y, drawPos.z + 0.75, '[E] Try to Escape')
                        if IsControlJustPressed(0, 38) then
                            TriggerEvent('codem-radialmenu:client:GetOutTrunk')
                            Wait(100)
                        end
                    end
                end
            else
                inTrunk = false
                isKidnapped = false
                TrunkCam(false)
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if inTrunk then
        local ped = PlayerPedId()
        DetachEntity(ped, true, true)
        ClearPedTasks(ped)
        SetEntityCollision(ped, true, true)
        inTrunk = false
        isKidnapped = false
        TrunkCam(false)

        if currentVehicle and DoesEntityExist(currentVehicle) then
            SetTrunkBusy(currentVehicle, false)
        end
    end
end)
