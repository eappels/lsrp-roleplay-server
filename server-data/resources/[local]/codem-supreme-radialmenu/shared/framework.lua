Framework = {
    Type = 'standalone', -- standalone, esx, qbcore, qbx
    Object = nil,
    PlayerData = {},
    PlayerDataCache = {},
    CacheTime = 0
}

function Framework:Detect()
    if GetResourceState('qbx_core') == 'started' then
        self.Type = 'qbx'
        self.Object = exports.qbx_core
        return
    end

    if GetResourceState('qb-core') == 'started' then
        self.Type = 'qbcore'
        self.Object = exports['qb-core']:GetCoreObject()
        return
    end

    if GetResourceState('es_extended') == 'started' then
        self.Type = 'esx'
        self.Object = exports['es_extended']:getSharedObject()
        if not self.Object then
            TriggerEvent('esx:getSharedObject', function(obj)
                self.Object = obj
            end)
        end
        return
    end

    self.Type = 'standalone'
end

function Framework:Notify(source, message, type, duration)
    duration = duration or 5000
    type = type or 'info'

    if self.Type == 'qbx' then
        if source then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Radial Menu',
                description = message,
                type = type,
                duration = duration
            })
        else
            exports.qbx_core:Notify(message, type)
        end
    elseif self.Type == 'qbcore' then
        if source then
            TriggerClientEvent('QBCore:Notify', source, message, type, duration)
        else
            TriggerEvent('QBCore:Notify', message, type, duration)
        end
    elseif self.Type == 'esx' then
        if source then
            TriggerClientEvent('esx:showNotification', source, message)
        else
            TriggerEvent('esx:showNotification', message)
        end
    else
        if source then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"Radial Menu", message}
            })
        else
            print('[Codem-Radialmenu] ' .. message)
        end
    end
end

function Framework:GetPlayerData(force)
    local currentTime = GetGameTimer()
    local cacheTTL = Config and Config.Cache and Config.Cache.PlayerDataTTL or 1000

    if not force and self.PlayerDataCache and (currentTime - self.CacheTime) < cacheTTL then
        return self.PlayerDataCache
    end

    local data = {}

    if self.Type == 'qbx' then
        data = exports.qbx_core:GetPlayerData() or {}
    elseif self.Type == 'qbcore' then
        data = self.Object.Functions.GetPlayerData() or {}
    elseif self.Type == 'esx' then
        if not IsDuplicityVersion() then
            data = self.Object and self.Object.PlayerData or {}
        else
            data = {}
        end
    else
        data = {}
    end

    self.PlayerDataCache = data
    self.CacheTime = currentTime

    return data
end

function Framework:ClearCache()
    self.PlayerDataCache = {}
    self.CacheTime = 0
end

function Framework:GetPlayerJob()
    local data = self:GetPlayerData()

    if self.Type == 'qbx' or self.Type == 'qbcore' then
        return data.job or {}
    elseif self.Type == 'esx' then
        return data.job or {}
    else
        return { name = 'unemployed', label = 'Unemployed', onduty = false }
    end
end

function Framework:GetPlayerGang()
    local data = self:GetPlayerData()

    if self.Type == 'qbx' or self.Type == 'qbcore' then
        return data.gang or {}
    else
        return { name = 'none', label = 'No Gang' }
    end
end

function Framework:IsDead()
    local data = self:GetPlayerData()

    if self.Type == 'qbx' or self.Type == 'qbcore' then
        if data.metadata then
            return data.metadata.isdead or data.metadata.inlaststand or false
        end
    elseif self.Type == 'esx' then
        return data.dead or false
    end

    return false
end

function Framework:IsHandcuffed()
    local data = self:GetPlayerData()

    if self.Type == 'qbx' or self.Type == 'qbcore' then
        if data.metadata then
            return data.metadata.ishandcuffed or false
        end
    elseif self.Type == 'esx' then
        if GetResourceState('esx_policejob') == 'started' then
            local success, isHandcuffed = pcall(function()
                return exports.esx_policejob:IsHandcuffed()
            end)
            if success then
                return isHandcuffed or false
            end
        end
        return false
    end

    return false
end

Framework:Detect()

return Framework
