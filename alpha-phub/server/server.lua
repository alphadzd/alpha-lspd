local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('alpha-phub:server:requestOfficers')
AddEventHandler('alpha-phub:server:requestOfficers', function()
    local src = source
    local officers = {}
    local players = QBCore.Functions.GetPlayers()
    local onDutyCount = 0

    for _, playerId in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
        if Player and Player.PlayerData.job.name == Config.RequiredJob then
            local callsign = Player.PlayerData.metadata.callsign or "N/A"
            local name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            local grade = Player.PlayerData.job.grade.name
            local status = "red"
            local statusText = "Off Duty"
            local brakeActive = Player.PlayerData.metadata.brakeactive or false
            local onDispatch = Player.PlayerData.metadata.ondispatch or false
            local onCommander = Player.PlayerData.metadata.oncommander or false
            local onBreak = Player.PlayerData.metadata.onbreak or false
            -- Get radio channel from pma-voice by checking which channel the player is in
            local radioChannel = 0
            local success, result = pcall(function()
                -- Check common radio channels 1-100 to find which one the player is in
                for channel = 1, 100 do
                    local playersInChannel = exports['pma-voice']:getPlayersInRadioChannel(channel)
                    if playersInChannel and type(playersInChannel) == "table" then
                        for _, playerInChannel in pairs(playersInChannel) do
                            if tonumber(playerInChannel) == tonumber(playerId) then
                                return channel
                            end
                        end
                    end
                end
                return 0
            end)
            if success and result then
                radioChannel = tonumber(result) or 0
            end

            if Player.PlayerData.job.onduty then
                if onBreak then
                    status = "blue"
                    statusText = "On Break"
                    onDutyCount = onDutyCount + 1
                elseif onCommander then
                    status = "yellow"
                    statusText = "Commander"
                    onDutyCount = onDutyCount + 1
                elseif onDispatch then
                    status = "purple"
                    statusText = "On Dispatch"
                    onDutyCount = onDutyCount + 1
                else
                    status = "green"
                    statusText = "On Duty"
                    onDutyCount = onDutyCount + 1

                    if brakeActive then
                        statusText = "On Duty (Brake)"
                    end
                end
            end

            print("Checking player: " .. name .. " (ID: " .. playerId .. ") - Radio Channel: " .. tostring(radioChannel))
            
            local shouldInclude = true
            if Config.HideOffDutyOfficers and status == "red" then
                shouldInclude = false
            end

            if shouldInclude then
                table.insert(officers, {
                    id = playerId,
                    name = name,
                    callsign = callsign,
                    grade = grade,
                    status = status,
                    statusText = statusText,
                    brakeActive = brakeActive,
                    radioChannel = radioChannel
                })
            end
        end
    end
    
    TriggerClientEvent('alpha-phub:client:syncOfficers', src, {
        officers = officers,
        count = onDutyCount
    })
end)

RegisterNetEvent('alpha-phub:server:updateCallsign')
AddEventHandler('alpha-phub:server:updateCallsign', function(newCallsign)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        Player.Functions.SetMetaData("callsign", newCallsign)
        
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(playerId))
            if TargetPlayer and TargetPlayer.PlayerData.job.name == Config.RequiredJob then
                TriggerClientEvent('alpha-phub:client:officerCallsignChanged', playerId)
            end
        end
    end
end)

RegisterNetEvent('alpha-phub:server:updateDutyStatus')
AddEventHandler('alpha-phub:server:updateDutyStatus', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        if status == "on-duty" then
            Player.Functions.SetJobDuty(true)
            Player.Functions.SetMetaData("onbreak", false)
            TriggerClientEvent('alpha-phub:client:showNotification', src, "You are now on duty", "success")
        elseif status == "off-duty" then
            Player.Functions.SetJobDuty(false)
            Player.Functions.SetMetaData("onbreak", false)
            Player.Functions.SetMetaData("brakeactive", false)
            Player.Functions.SetMetaData("ondispatch", false)
            Player.Functions.SetMetaData("oncommander", false)
            TriggerClientEvent('alpha-phub:client:showNotification', src, "You are now off duty", "error")
        elseif status == "on-break" then
            Player.Functions.SetMetaData("onbreak", true)
            TriggerClientEvent('alpha-phub:client:showNotification', src, "You are now on break", "primary")
        end
        
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(playerId))
            if TargetPlayer and TargetPlayer.PlayerData.job.name == Config.RequiredJob then
                TriggerClientEvent('alpha-phub:client:officerCallsignChanged', playerId)
                TriggerEvent('alpha-phub:server:requestOfficers', playerId)
            end
        end
    end
end)

RegisterNetEvent('alpha-phub:server:updateBrakeStatus')
AddEventHandler('alpha-phub:server:updateBrakeStatus', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        local isActive = (status == "on")
        Player.Functions.SetMetaData("brakeactive", isActive)

        if isActive then
            TriggerClientEvent('alpha-phub:client:showNotification', src, "Brake activated", "success")
        else
            TriggerClientEvent('alpha-phub:client:showNotification', src, "Brake deactivated", "error")
        end

        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(playerId))
            if TargetPlayer and TargetPlayer.PlayerData.job.name == Config.RequiredJob then
                TriggerClientEvent('alpha-phub:client:officerCallsignChanged', playerId)
            end
        end
    end
end)

RegisterNetEvent('alpha-phub:server:updateDispatchStatus')
AddEventHandler('alpha-phub:server:updateDispatchStatus', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        local isActive = (status == "on-dispatch")
        Player.Functions.SetMetaData("ondispatch", isActive)
        if isActive then
            Player.Functions.SetMetaData("oncommander", false)
        end

        if isActive then
            TriggerClientEvent('alpha-phub:client:showNotification', src, "You are now on dispatch", "primary")
        else
            TriggerClientEvent('alpha-phub:client:showNotification', src, "You are no longer on dispatch", "error")
        end

        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(playerId))
            if TargetPlayer and TargetPlayer.PlayerData.job.name == Config.RequiredJob then
                TriggerClientEvent('alpha-phub:client:officerCallsignChanged', playerId)
            end
        end
    end
end)

RegisterNetEvent('alpha-phub:server:updateCommanderStatus')
AddEventHandler('alpha-phub:server:updateCommanderStatus', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        local isActive = (status == "on-commander")
        Player.Functions.SetMetaData("oncommander", isActive)
        if isActive then
            Player.Functions.SetMetaData("ondispatch", false)
        end

        if isActive then
            TriggerClientEvent('alpha-phub:client:showNotification', src, "You are now commander", "primary")
        else
            TriggerClientEvent('alpha-phub:client:showNotification', src, "You are no longer commander", "error")
        end

        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(playerId))
            if TargetPlayer and TargetPlayer.PlayerData.job.name == Config.RequiredJob then
                TriggerClientEvent('alpha-phub:client:officerCallsignChanged', playerId)
            end
        end
    end
end)

RegisterNetEvent('alpha-phub:server:requestOfficerLocation')
AddEventHandler('alpha-phub:server:requestOfficerLocation', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(targetId))
    
    if Player and Player.PlayerData.job.name == Config.RequiredJob and TargetPlayer then
        TriggerClientEvent('alpha-phub:client:shareLocation', targetId, src)
        TriggerClientEvent('alpha-phub:client:showNotification', src, "Location request sent to officer", "primary")
    end
end)

RegisterNetEvent('alpha-phub:server:sendOfficerLocation')
AddEventHandler('alpha-phub:server:sendOfficerLocation', function(requesterId, location)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        TriggerClientEvent('alpha-phub:client:receiveOfficerLocation', requesterId, src, location)
    end
end)

RegisterNetEvent('alpha-phub:server:sendChatMessage')
AddEventHandler('alpha-phub:server:sendChatMessage', function(message, callsign)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        if not callsign or callsign == "" then
            callsign = Player.PlayerData.metadata.callsign or "Unit-" .. src
        end
        
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(playerId))
            if TargetPlayer and TargetPlayer.PlayerData.job.name == Config.RequiredJob then
                if tonumber(playerId) ~= src then
                    TriggerClientEvent('alpha-phub:client:receiveChatMessage', playerId, callsign, message)
                end
            end
        end
    end
end)

RegisterNetEvent('alpha-phub:server:savePosition')
AddEventHandler('alpha-phub:server:savePosition', function(position)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player then
        Player.Functions.SetMetaData("dispatchPosition", {
            left = position.left,
            top = position.top,
            width = position.width,
            height = position.height
        })
        TriggerClientEvent('alpha-phub:client:showNotification', src, "Dispatch position saved", "success")
    end
end)

RegisterNetEvent('alpha-phub:server:requestRadioInfo')
AddEventHandler('alpha-phub:server:requestRadioInfo', function(officerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if Player and Player.PlayerData.job.name == Config.RequiredJob then
        local TargetPlayer = QBCore.Functions.GetPlayer(tonumber(officerId))
        if TargetPlayer then
            local name = TargetPlayer.PlayerData.charinfo.firstname .. " " .. TargetPlayer.PlayerData.charinfo.lastname
            local callsign = TargetPlayer.PlayerData.metadata.callsign or ""
            local displayName = callsign ~= "" and (callsign .. " " .. name) or name

            -- Get actual radio channel from pma-voice by checking which channel the player is in
            local radioChannel = "No Channel"
            local success, result = pcall(function()
                -- Check common radio channels 1-100 to find which one the player is in
                for channel = 1, 100 do
                    local playersInChannel = exports['pma-voice']:getPlayersInRadioChannel(channel)
                    if playersInChannel and type(playersInChannel) == "table" then
                        for _, playerInChannel in pairs(playersInChannel) do
                            if tonumber(playerInChannel) == tonumber(officerId) then
                                return channel
                            end
                        end
                    end
                end
                return 0
            end)
            if success and result and tonumber(result) and tonumber(result) > 0 then
                radioChannel = "Channel " .. result
            end

            TriggerClientEvent('alpha-phub:client:showNotification', src, displayName .. " - Radio: " .. radioChannel, "primary", 4000)
        else
            TriggerClientEvent('alpha-phub:client:showNotification', src, "Officer not found or offline", "error")
        end
    end
end)



