local QBCore = exports['qb-core']:GetCoreObject()
local display = false
local brakeActive = false
local mouseVisible = false

function SetDisplay(bool, showMouse)
    display = bool
    
    if showMouse ~= nil then
        mouseVisible = showMouse
    end
    
    SetNuiFocus(bool and mouseVisible, bool and mouseVisible)
    
    if bool then
        DisplayRadar(false)
        if mouseVisible then
            SetCursorLocation(0.5, 0.5)
        end
    else
        DisplayRadar(true)
    end
    
    SendNUIMessage({
        type = "ui",
        status = bool,
        mouseVisible = mouseVisible
    })
    
    if bool then
        TriggerServerEvent('alpha-phub:server:requestOfficers')
    end
end



RegisterCommand('phub', function()
    local Player = QBCore.Functions.GetPlayerData()
    if Player.job.name == Config.RequiredJob then
        if not display then
            SetDisplay(true, false)
            SendNUIMessage({
                type = "notification",
                message = "Press " .. Config.OpenKey .. " to toggle mouse control, ESC to hide mouse",
                style = "primary",
                duration = 5000
            })
        else
            SetDisplay(false)
        end
    else
        SendNUIMessage({
            type = "notification",
            message = "You are not authorized to use this system",
            style = "error",
            duration = 3000
        })
    end
end)

RegisterCommand('togglemouse', function()
    if display then
        mouseVisible = not mouseVisible
        SetNuiFocus(mouseVisible, mouseVisible)
        
        local status = mouseVisible and "enabled" or "disabled"
        SendNUIMessage({
            type = "notification",
            message = "Mouse control " .. status,
            style = "primary",
            duration = 3000
        })
        
        SendNUIMessage({
            type = "mouseVisibility",
            visible = mouseVisible
        })
    end
end)

RegisterCommand('hidemouse', function()
    if display and mouseVisible then
        mouseVisible = false
        SetNuiFocus(false, false)
        
        SendNUIMessage({
            type = "notification",
            message = "Mouse control disabled",
            style = "primary",
            duration = 3000
        })
        
        SendNUIMessage({
            type = "mouseVisibility",
            visible = false
        })
    end
end)

RegisterKeyMapping('togglemouse', 'Toggle Mouse Control', 'keyboard', Config.OpenKey)
RegisterKeyMapping('hidemouse', 'Hide Mouse Control', 'keyboard', 'ESCAPE')
RegisterKeyMapping('policehub', 'Open Police Hub', 'keyboard', Config.OpenHubKey)



RegisterNUICallback('close', function(data, cb)
    SetDisplay(false)
    mouseVisible = false
    cb('ok')
end)

RegisterNUICallback('hidemouse', function(data, cb)
    if display then
        mouseVisible = false
        SetNuiFocus(false, false)
        
        SendNUIMessage({
            type = "mouseVisibility",
            visible = false
        })
    end
    cb('ok')
end)

RegisterNUICallback('changeCallsign', function(data, cb)
    local newCallsign = data.callsign
    if newCallsign and newCallsign ~= "" then
        TriggerServerEvent('alpha-phub:server:updateCallsign', newCallsign)
        SendNUIMessage({
            type = "notification",
            message = "Callsign updated to: " .. newCallsign,
            style = "success",
            duration = 3000
        })
    else
        SendNUIMessage({
            type = "notification",
            message = "Please enter a valid callsign",
            style = "error",
            duration = 3000
        })
    end
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(data, cb)
    local newStatus = data.status
    TriggerServerEvent('alpha-phub:server:updateDutyStatus', newStatus)
    cb('ok')
end)

RegisterNUICallback('toggleBrake', function(data, cb)
    brakeActive = not brakeActive
    local status = brakeActive and "on" or "off"
    TriggerServerEvent('alpha-phub:server:updateBrakeStatus', status)

    SendNUIMessage({
        type = "brakeStatus",
        active = brakeActive
    })

    TriggerServerEvent('alpha-phub:server:requestOfficers')

    cb('ok')
end)

RegisterNUICallback('toggleDispatch', function(data, cb)
    local status = data.status
    TriggerServerEvent('alpha-phub:server:updateDispatchStatus', status)
    cb('ok')
end)

RegisterNUICallback('toggleCommander', function(data, cb)
    local status = data.status
    TriggerServerEvent('alpha-phub:server:updateCommanderStatus', status)
    cb('ok')
end)

RegisterNUICallback('testRadioTalk', function(data, cb)
    local officerId = data.officerId
    TriggerServerEvent('alpha-phub:server:radioTalk', officerId, 3000)
    cb('ok')
end)

RegisterNUICallback('trackOfficer', function(data, cb)
    local officerId = data.id
    if officerId then
        TriggerServerEvent('alpha-phub:server:requestOfficerLocation', officerId)
    end
    cb('ok')
end)

RegisterNUICallback('showRadioInfo', function(data, cb)
    local officerId = data.id
    if officerId then
        TriggerServerEvent('alpha-phub:server:requestRadioInfo', officerId)
    end
    cb('ok')
end)

RegisterNUICallback('sendChatMessage', function(data, cb)
    local message = data.message
    local callsign = data.callsign
    
    if message and message ~= "" then
        TriggerServerEvent('alpha-phub:server:sendChatMessage', message, callsign)
    end
    cb('ok')
end)

RegisterNUICallback('executeCommand', function(data, cb)
    local command = data.command
    
    if command then
        if command == '/cameras' then
            ExecuteCommand('cameras')
        else
            ExecuteCommand(command:sub(2))
        end
    end
    cb('ok')
end)





RegisterNetEvent('alpha-phub:client:syncOfficers')
AddEventHandler('alpha-phub:client:syncOfficers', function(data)
    if display then

        SendNUIMessage({
            type = "updateOfficers",
            data = data.officers,
            count = data.count
        })
    end
end)


RegisterNetEvent('alpha-phub:client:officerCallsignChanged')
AddEventHandler('alpha-phub:client:officerCallsignChanged', function()
    if display then
        TriggerServerEvent('alpha-phub:server:requestOfficers')
    end
end)

RegisterNetEvent('alpha-phub:client:showNotification')
AddEventHandler('alpha-phub:client:showNotification', function(message, style, duration)
    duration = duration or 3000
    SendNUIMessage({
        type = "notification",
        message = message,
        style = style,
        duration = duration
    })
end)

RegisterNetEvent('alpha-phub:client:shareLocation')
AddEventHandler('alpha-phub:client:shareLocation', function(requesterId)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local street = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(street)
    
    TriggerServerEvent('alpha-phub:server:sendOfficerLocation', requesterId, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        street = streetName
    })
end)

RegisterNetEvent('alpha-phub:client:receiveOfficerLocation')
AddEventHandler('alpha-phub:client:receiveOfficerLocation', function(officerId, location)
    SetNewWaypoint(location.x, location.y)
    
    QBCore.Functions.Notify("Waypoint set to officer at " .. location.street, "success")
    
    if display then
        SendNUIMessage({
            type = "officerTracked",
            id = officerId,
            location = location
        })
    end
end)

RegisterNetEvent('alpha-phub:client:receiveChatMessage')
AddEventHandler('alpha-phub:client:receiveChatMessage', function(sender, message)
    SendNUIMessage({
        type = "chatMessage",
        sender = sender,
        message = message
    })

    PlaySound(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)

    if not display then
        QBCore.Functions.Notify(sender .. ": " .. message, "primary")
    end
end)

RegisterNetEvent('alpha-phub:client:radioTalkAnimation')
AddEventHandler('alpha-phub:client:radioTalkAnimation', function(officerId, duration)
    if display then
        SendNUIMessage({
            type = "radioTalk",
            officerId = officerId,
            duration = duration
        })
    end
end)





AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata.callsign then
            SendNUIMessage({
                type = "loadCallsign",
                callsign = PlayerData.metadata.callsign
            })
        end
        
        if PlayerData.metadata.dispatchPosition then
            SendNUIMessage({
                type = "loadPosition",
                position = PlayerData.metadata.dispatchPosition
            })
        end
    end)
end)

RegisterNUICallback('savePosition', function(data, cb)
    local position = {
        left = data.left,
        top = data.top
    }
    
    TriggerServerEvent('alpha-phub:server:savePosition', position)
    
    cb('ok')
end)