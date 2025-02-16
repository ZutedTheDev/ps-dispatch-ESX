local ESX = exports['es_extended']:getSharedObject()
local calls = {}
local callCount = 0

-- Functions
exports('GetDispatchCalls', function()
    return calls
end)

-- Events
RegisterServerEvent('ps-dispatch:server:notify', function(data)
    callCount = callCount + 1
    data.id = callCount
    data.time = os.time() * 1000
    data.units = {}
    data.responses = {}

    if #calls > 0 then
        if calls[#calls] == data then
            return
        end
    end
        
    if #calls >= Config.MaxCallList then
        table.remove(calls, 1)
    end

    calls[#calls + 1] = data

    TriggerClientEvent('ps-dispatch:client:notify', -1, data)
end)

RegisterServerEvent('ps-dispatch:server:attach', function(id, player)
    for i=1, #calls do
        if calls[i]['id'] == id then
            for j = 1, #calls[i]['units'] do
                if calls[i]['units'][j]['citizenid'] == player.citizenid then
                    return
                end
            end
            calls[i]['units'][#calls[i]['units'] + 1] = player
            return
        end
    end
end)

RegisterServerEvent('ps-dispatch:server:detach', function(id, player)
    for i = #calls, 1, -1 do
        if calls[i]['id'] == id then
            if calls[i]['units'] and (#calls[i]['units'] or 0) > 0 then
                for j = #calls[i]['units'], 1, -1 do
                    if calls[i]['units'][j]['citizenid'] == player.citizenid then
                        table.remove(calls[i]['units'], j)
                    end
                end
            end
            return
        end
    end
end)

-- Commands
RegisterCommand('911', function(source, args)
    if #args < 1 then 
        TriggerClientEvent('esx:showNotification', source, 'USAGE: /911 [message]')
        return
    end
    local message = table.concat(args, ' ')
    TriggerClientEvent('ps-dispatch:client:sendEmergencyMsg', source, message, '911', false)
end)

RegisterCommand('311', function(source, args)
    if #args < 1 then 
        TriggerClientEvent('esx:showNotification', source, 'USAGE: /311 [message]')
        return
    end
    local message = table.concat(args, ' ')
    TriggerClientEvent('ps-dispatch:client:sendEmergencyMsg', source, message, '311', false)
end)

RegisterCommand('911a', function(source, args)
    if #args < 1 then 
        TriggerClientEvent('esx:showNotification', source, 'USAGE: /911a [message]')
        return
    end
    local message = table.concat(args, ' ')
    TriggerClientEvent('ps-dispatch:client:sendEmergencyMsg', source, message, '911', true)
end)

RegisterCommand('311a', function(source, args)
    if #args < 1 then 
        TriggerClientEvent('esx:showNotification', source, 'USAGE: /311a [message]')
        return
    end
    local message = table.concat(args, ' ')
    TriggerClientEvent('ps-dispatch:client:sendEmergencyMsg', source, message, '311', true)
end)

RegisterCommand('dispatch', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not Config.Jobs[xPlayer.job.name] or not Config.Jobs[xPlayer.job.name].authorized then
        TriggerClientEvent('esx:showNotification', source, 'You do not have permission to use this command')
        return
    end
    TriggerClientEvent('ps-dispatch:client:openMenu', source, calls)
end)

-- Callbacks
lib.callback.register('ps-dispatch:callback:getLatestDispatch', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    
    return calls[#calls]
end)

lib.callback.register('ps-dispatch:callback:getCalls', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    
    return calls
end)
