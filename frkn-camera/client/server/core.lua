Core = nil
CoreName = nil
CoreReady = false
Citizen.CreateThread(function()
    for k, v in pairs(Cores) do
        if GetResourceState(v.ResourceName) == "starting" or GetResourceState(v.ResourceName) == "started" then
            CoreName = v.ResourceName
            Core = v.GetFramework()
            CoreReady = true
        end
    end
end)


function GetActiveInventory()
    if GetResourceState("qb-inventory") == "started" then
        return "qb-inventory"
    elseif GetResourceState("qs-inventory") == "started" then
        return "qs-inventory"
    elseif GetResourceState("ps-inventory") == "started" then
        return "ps-inventory"
    elseif GetResourceState("lj-inventory") == "started" then
        return "lj-inventory"
    elseif GetResourceState("ox_inventory") == "started" then
        return "ox_inventory"
    end
    return nil
end

function GetPlayer(source)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = Core.Functions.GetPlayer(source)
        return player
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerFromId(source)
        return player
    end
end

function GetIdentifier(source)

    local source = tonumber(source)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = Core.Functions.GetPlayer(source)
        return player.PlayerData.citizenid
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerFromId(source)
        return player.identifier
    end
end

function Notify(source, text, length, type)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        Core.Functions.Notify(source, text, type, length)
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerFromId(source)
        player.showNotification(text)
    end
end

function GetPlayerJob(source)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = Core.Functions.GetPlayer(source)
        return player.PlayerData.job
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerFromId(source)
        return player.job
    end
end

function GetPlayerGrade(source)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = Core.Functions.GetPlayer(source)
        return player.PlayerData.job.grade.level
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerFromId(source)
        return player.job.grade
    end
end

function RemoveItem(source, name, amount, metadata)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = Core.Functions.GetPlayer(source)
        player.Functions.RemoveItem(name, amount, metadata)
    elseif CoreName == "es_extended" then
        local player = Core.GetPlayerFromId(source)
        local hasQs = GetResourceState('qs-inventory') == 'started'
        local hasEsx = GetResourceState('esx_inventoryhud') == 'started'
        local hasOx = GetResourceState('qb-inventory') == 'started'

        if hasQs then
            return exports['qs-inventory']:RemoveItem(source, name, amount, metadata)
        elseif hasEsx then
            return player.removeInventoryItem(name, amount)
        elseif hasOx then
            return exports["qb-inventory"]:RemoveItem(source, name, amount, metadata)
        else
            --CUSTOM INVENTORY REMOVE ITEM FUNCTION HERE
        end
    end
end


function GetItemByName(player, name)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        -- local player = Core.Functions.GetPlayer(source)
        return player.Functions.GetItemByName(name)
    elseif CoreName == "es_extended" then
        -- local player = Core.GetPlayerFromId(source)
        local hasQs = GetResourceState('qs-inventory') == 'started'
        local hasEsx = GetResourceState('esx_inventoryhud') == 'started'
        local hasOx = GetResourceState('qb-inventory') == 'started'

        if hasQs then
            return exports['qs-inventory']:GetItem(source, name)
        elseif hasEsx then
            return player.getInventoryItem(name)
        elseif hasOx then
            return exports["qb-inventory"]:GetItem(source, name)
        else
            --CUSTOM INVENTORY GET ITEM FUNCTION HERE
        end
    end
end

function HasAnyItem(xPlayer, items)
    for k , itemName in pairs(items) do
        local item = nil
        if CoreName == 'es_extended' then
            item = xPlayer.hasItem(k)
        else
            item = xPlayer.Functions.GetItemByName(k)
        end
        if item and (item.amount or item.count or 0) > 0 then
            return true
        end
    end
    return false 
end

function GetItem(p, name)
    if CoreName == "qb-core" or CoreName == "qbx_core" then
        local player = p
        return player.Functions.GetItemByName(name)
    elseif CoreName == "es_extended" then
        local player = p
        local hasQs = GetResourceState('qs-inventory') == 'started'
        local hasEsx = GetResourceState('esx_inventoryhud') == 'started'
        local hasOx = GetResourceState('qb-inventory') == 'started'

        if hasQs then
            return exports['qs-inventory']:GetItem(source, name)
        elseif hasEsx then
            return player.getInventoryItem(name)
        elseif hasOx then
            return exports["qb-inventory"]:GetItem(source, name)
        else
            --CUSTOM INVENTORY GET ITEM FUNCTION HERE
        end
    end
end


function RegisterUsableItem(name)
    while CoreReady == false do Citizen.Wait(0) end

    local hasQs = GetResourceState('qs-inventory') == 'started'
    if hasQs then
        exports['qs-inventory']:CreateUsableItem(name, function(source, item)
            if name == FRKN.SignalCutterItem then
                TriggerClientEvent('frkn-camera:signalcutter', source, item.metadata or item.info)
            end
        end)
    elseif CoreName == "qb-core" or CoreName == "qbx_core" then
        Core.Functions.CreateUseableItem(name, function(source, item)
            if name == FRKN.SignalCutterItem then
                TriggerClientEvent('frkn-camera:signalcutter', source, item.metadata or item.info)
            end
        end)
    elseif CoreName == "es_extended" then
        Core.RegisterUsableItem(name, function(source, item)
            if name == FRKN.SignalCutterItem then
                TriggerClientEvent('frkn-camera:signalcutter', source, item.metadata or item.info)
            end
        end)
    end
end



FRKN.ServerCallbacks = {}
function CreateCallback(name, cb)
    FRKN.ServerCallbacks[name] = cb
end

function TriggerCallback(name, source, cb, ...)
    if not FRKN.ServerCallbacks[name] then return end
    FRKN.ServerCallbacks[name](source, cb, ...)
end

RegisterNetEvent('frkn-tuning:server:triggerCallback', function(name, ...)
    local src = source
    TriggerCallback(name, src, function(...)
        TriggerClientEvent('frkn-tuning:client:triggerCallback', src, name, ...)
    end, ...)
end)