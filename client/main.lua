ESX = exports['es_extended']:getSharedObject()
PlayerData = {}
inHuntingZone, inNoDispatchZone = false, false
local huntingZones, nodispatchZones, huntingBlips = {} , {}, {}

local blips = {}
local radius2 = {}
local alertsMuted = false
local alertsDisabled = false
local waypointCooldown = false

-- Functions
---@param bool boolean Toggles visibilty of the menu
local function toggleUI(bool)
    SetNuiFocus(bool, bool)
    SendNUIMessage({ action = "setVisible", data = bool })
end

-- Zone Functions --
local function removeZones()
    -- Hunting Zone --
    for i = 1, #huntingZones do
        huntingZones[i]:remove()
    end
    -- No Dispatch Zone --
    for i = 1, #nodispatchZones do
        nodispatchZones[i]:remove()
    end
    -- Hunting Blips --
    for i = 1, #huntingBlips do
        RemoveBlip(huntingBlips[i])
    end
    -- Reset the stored values too
    huntingZones, nodispatchZones, huntingBlips = {} , {}, {}
end

local function createZones()
    -- Hunting Zone --
    if Config.Locations['HuntingZones'][1] then
    	for _, hunting in pairs(Config.Locations["HuntingZones"]) do
            -- Creates the Blips
            if Config.EnableHuntingBlip then
                local blip = AddBlipForCoord(hunting.coords.x, hunting.coords.y, hunting.coords.z)
                local huntingradius = AddBlipForRadius(hunting.coords.x, hunting.coords.y, hunting.coords.z, hunting.radius)
                SetBlipSprite(blip, 442)
                SetBlipAsShortRange(blip, true)
                SetBlipScale(blip, 0.8)
                SetBlipColour(blip, 0)
                SetBlipColour(huntingradius, 0)
                SetBlipAlpha(huntingradius, 40)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(hunting.label)
                EndTextCommandSetBlipName(blip)
                huntingBlips[#huntingBlips+1] = blip
                huntingBlips[#huntingBlips+1] = huntingradius
            end
            -- Creates the Sphere --
            local huntingZone = lib.zones.sphere({
                coords = hunting.coords,
                radius = hunting.radius,
                debug = Config.Debug,
                onEnter = function()
                    inHuntingZone = true
                end,
                onExit = function()
                    inHuntingZone = false
                end
            })
            huntingZones[#huntingZones+1] = huntingZone
    	end
    end
    -- No Dispatch Zone --
    if Config.Locations['NoDispatchZones'][1] then
    	for _, nodispatch in pairs(Config.Locations["NoDispatchZones"]) do
            local nodispatchZone = lib.zones.box({
                coords = nodispatch.coords,
                size = vec3(nodispatch.length, nodispatch.width, nodispatch.maxZ - nodispatch.minZ),
                rotation = nodispatch.heading,
                debug = Config.Debug,
                onEnter = function()
                    inNoDispatchZone = true
                end,
                onExit = function()
                    inNoDispatchZone = false
                end
            })
            nodispatchZones[#nodispatchZones+1] = nodispatchZone
    	end
    end
end

local function setupDispatch()
    local playerInfo = ESX.GetPlayerData()
    local locales = lib.getLocales()
    PlayerData = {
        charinfo = {
            firstname = playerInfo.firstname,
            lastname = playerInfo.lastname
        },
        metadata = {
            callsign = playerInfo.callsign
        },
        citizenid = playerInfo.citizenid,
        job = {
            type = playerInfo.job.name,
            name = playerInfo.job.name,
            label = playerInfo.job.label
        },
    }

    Wait(1000)

    SendNUIMessage({
        action = "setupUI",
        data = {
            locales = locales,
            player = PlayerData,
            keybind = Config.RespondKeybind,
            maxCallList = Config.MaxCallList,
            shortCalls = Config.ShortCalls,
        }
    })
end

---@param jobName string -- The player job to check against
---@return boolean -- Returns true if the job is valid
local function isJobValid(jobName)
    if not PlayerData.job then return false end
    if not Config.Jobs then return false end
    
    local job = Config.Jobs[jobName]
    return job and job.authorized or false
end

local function openMenu()
    if not isJobValid(PlayerData.job.name) then return end

    local calls = lib.callback.await('ps-dispatch:callback:getCalls', false)
    if #calls == 0 then
        lib.notify({ description = locale('no_calls'), position = 'top', type = 'error' })
    else
        SendNUIMessage({ action = 'setDispatchs', data = calls, })
        toggleUI(true)
    end
end

local function setWaypoint()
    if not isJobValid(PlayerData.job.name) then return end
    if not IsOnDuty() then return end

    local data = lib.callback.await('ps-dispatch:callback:getLatestDispatch', false)

    if not data then return end

    if data.alertTime == nil then data.alertTime = Config.AlertTime end
    local timer = data.alertTime * 1000

    if not waypointCooldown and lib.table.contains(data.jobs, PlayerData.job.name) then
        SetNewWaypoint(data.coords.x, data.coords.y)
        TriggerServerEvent('ps-dispatch:server:attach', data.id, PlayerData)
        lib.notify({ description = locale('waypoint_set'), position = 'top', type = 'success' })
        waypointCooldown = true
        SetTimeout(timer, function()
            waypointCooldown = false
        end)
    end
end

local function randomOffset(baseX, baseY, offset)
    local randomX = baseX + math.random(-offset, offset)
    local randomY = baseY + math.random(-offset, offset)

    return randomX, randomY
end

local function createBlipData(coords, radius, sprite, color, scale, flash)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local radiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)

    SetBlipFlashes(blip, flash)
    SetBlipSprite(blip, sprite or 161)
    SetBlipHighDetail(blip, true)
    SetBlipScale(blip, scale or 1.0)
    SetBlipColour(blip, color or 84)
    SetBlipAlpha(blip, 255)
    SetBlipAsShortRange(blip, false)
    SetBlipCategory(blip, 2)
    SetBlipColour(radiusBlip, color or 84)
    SetBlipAlpha(radiusBlip, 128)

    return blip, radiusBlip
end

local function createBlip(data, blipData)
    local blip, radius = nil, nil
    local sprite = blipData.sprite or blipData.alert.sprite or 161
    local color = blipData.color or blipData.alert.color or 84
    local scale = blipData.scale or blipData.alert.scale or 1.0
    local flash = blipData.flash or false
    local alpha = 255
    local radiusAlpha = 128
    local blipWaitTime = ((blipData.length or blipData.alert.length) * 60000) / radiusAlpha

    if blipData.offset then
        local offsetX, offsetY = randomOffset(data.coords.x, data.coords.y, Config.MaxOffset)
        blip, radius = createBlipData({ x = offsetX, y = offsetY, z = data.coords.z }, blipData.radius, sprite, color, scale, flash)
        blips[data.id] = blip
        radius2[data.id] = radius
    else
        blip, radius = createBlipData(data.coords, blipData.radius, sprite, color, scale, flash)
        blips[data.id] = blip
        radius2[data.id] = radius
    end

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(data.code .. ' - ' .. data.message)
    EndTextCommandSetBlipName(blip)

    while radiusAlpha > 0 do
        Wait(blipWaitTime)
        radiusAlpha = math.max(0, radiusAlpha - 1)
        SetBlipAlpha(radius, radiusAlpha)
    end

    RemoveBlip(radius)
    RemoveBlip(blip)
end

local function addBlip(data, blipData)
    CreateThread(function()
        createBlip(data, blipData)
    end)
    if not alertsMuted then
        if blipData.sound == "Lose_1st" then
            PlaySound(-1, blipData.sound, blipData.sound2, 0, 0, 1)
        else
            TriggerServerEvent("InteractSound_SV:PlayOnSource", blipData.sound or blipData.alert.sound, 0.25)
        end
    end
end

-- Keybind
local RespondToDispatch = lib.addKeybind({
    name = 'RespondToDispatch',
    description = 'Set waypoint to last call location',
    defaultKey = Config.RespondKeybind,
    onPressed = setWaypoint,
})

local OpenDispatchMenu = lib.addKeybind({
    name = 'OpenDispatchMenu',
    description = 'Open Dispatch Menu',
    defaultKey = Config.OpenDispatchMenu,
    onPressed = openMenu,
})

-- Events
RegisterNetEvent('ps-dispatch:client:notify')
AddEventHandler('ps-dispatch:client:notify', function(data)
    if alertsMuted or alertsDisabled or inNoDispatchZone then return end
    if not isJobValid(PlayerData.job.name) then return end
    if not IsOnDuty() then return end

    SendNUIMessage({
        action = 'addAlert',
        data = data,
        job = PlayerData.job.name,
        sound = not alertsMuted
    })

    if Config.AddBlipToCall then
        CreateBlip(data)
    end
end)

RegisterNetEvent('ps-dispatch:client:openMenu', function(data)
    if not isJobValid(PlayerData.job.name) then return end
    if not IsOnDuty() then return end

    if #data == 0 then
        lib.notify({ description = locale('no_calls'), position = 'top', type = 'error' })
    else
        toggleUI(true)
        SendNUIMessage({ action = 'setDispatchs', data = data, })
    end
end)

-- EventHandlers
CreateThread(function()
    while ESX == nil do
        ESX = exports['es_extended']:getSharedObject()
        Wait(0)
    end

    while ESX.GetPlayerData().job == nil do
        Wait(10)
    end

    PlayerData = ESX.GetPlayerData()
    setupDispatch()
    createZones()
end)

local function IsOnDuty()
    if not Config.OnDutyOnly then return true end
    if not PlayerData.job then return false end
    return PlayerData.job.name and Config.Jobs[PlayerData.job.name] and Config.Jobs[PlayerData.job.name].authorized
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    setupDispatch()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeZones()
end)

-- NUICallbacks
RegisterNUICallback("hideUI", function(_, cb)
    toggleUI(false)
    cb("ok")
end)

RegisterNUICallback("attachUnit", function(data, cb)
    TriggerServerEvent('ps-dispatch:server:attach', data.id, PlayerData)
    SetNewWaypoint(data.coords.x, data.coords.y)
    cb("ok")
end)

RegisterNUICallback("detachUnit", function(data, cb)
    TriggerServerEvent('ps-dispatch:server:detach', data.id, PlayerData)
    DeleteWaypoint()
    cb("ok")
end)

RegisterNUICallback("toggleMute", function(data, cb)
    local muteStatus = data.boolean and locale('muted') or locale('unmuted')
    lib.notify({ description = locale('alerts') .. muteStatus, position = 'top', type = 'warning' })
    alertsMuted = data.boolean
    cb("ok")
end)

RegisterNUICallback("toggleAlerts", function(data, cb)
    local muteStatus = data.boolean and locale('disabled') or locale('enabled')
    lib.notify({ description = locale('alerts') .. muteStatus, position = 'top', type = 'warning' })
    alertsDisabled = data.boolean
    cb("ok")
end)

RegisterNUICallback("clearBlips", function(data, cb)
    lib.notify({ description = locale('blips_cleared'), position = 'top', type = 'success' })
    for k, v in pairs(blips) do
        RemoveBlip(v)
    end
    for k, v in pairs(radius2) do
        RemoveBlip(v)
    end
    cb("ok")
end)

RegisterNUICallback("refreshAlerts", function(data, cb)
    lib.notify({ description = locale('alerts_refreshed'), position = 'top', type = 'success' })
    local data = lib.callback.await('ps-dispatch:callback:getCalls', false)
    SendNUIMessage({ action = 'setDispatchs', data = data, })
    cb("ok")
end)
