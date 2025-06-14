local QBCore = exports['qb-core']:GetCoreObject()

print("[Alpha Wings] Loading Alpha Wings System v1.0...")
print("[Alpha Wings] Advanced Police Wings Management with Grade System")
print("[Alpha Wings] Waiting for database initialization...")

CreateThread(function()
    local attempts = 0
    local maxAttempts = 100
    local waitTime = 100

    while not Database and attempts < maxAttempts do
        Wait(waitTime)
        attempts = attempts + 1
    end
    
    if Database then
        print("[Alpha Wings] Database module loaded successfully!")
    else
        print("[Alpha Wings] Critical Error: Failed to load database module after " .. (maxAttempts * waitTime / 1000) .. " seconds!")
        print("[Alpha Wings] The resource will not function properly. Please check your database configuration and restart the resource.")
    end
end)

local function IsPoliceOfficer(Player)
    if not Player or not Player.PlayerData.job then
        return false
    end
    
    local jobName = Player.PlayerData.job.name
    local grade = Player.PlayerData.job.grade.level
    
    if jobName ~= Config.PoliceJob.jobName then
        return false
    end

    for _, allowedGrade in ipairs(Config.PoliceJob.allowedGrades) do
        if grade == allowedGrade then
            return true
        end
    end
    
    return false
end

local function IsPoliceChief(Player)
    return IsPoliceOfficer(Player) and Player.PlayerData.job.grade.level >= Config.PoliceJob.chiefGrade
end

local function IsPoliceSupervisor(Player)
    return IsPoliceOfficer(Player) and Player.PlayerData.job.grade.level >= Config.PoliceJob.supervisorGrade
end

local function CheckWingLeadership(citizenid, wingId, callback)
    Database.IsWingLeader(citizenid, wingId, function(isLeader, memberInfo)
        callback(isLeader, memberInfo)
    end)
end

local function IsPlayerPoliceChief(Player)
    return IsPoliceChief(Player)
end

local function CheckGradeBasedLeadership(citizenid, wingId, callback)
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= wingId then
            callback(false, nil)
            return
        end

        Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            callback(isLeader, memberWithGrade)
        end)
    end)
end

local function SilentWingLeadershipCheck(citizenid, wingId, callback)
    Database.IsWingLeader(citizenid, wingId, function(isLeader, memberInfo)
        if isLeader then
            callback(true, memberInfo)
        else
            callback(false, nil)
        end
    end)
end

local function GetOnlinePoliceOfficers()
    local officers = {}
    local players = QBCore.Functions.GetPlayers()
    
    for _, playerId in pairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if IsPoliceOfficer(Player) then
            table.insert(officers, {
                playerId = playerId,
                citizenid = Player.PlayerData.citizenid,
                name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
                policeGrade = Player.PlayerData.job.grade.name,
                grade = Player.PlayerData.job.grade.level
            })
        end
    end
    
    return officers
end

RegisterNetEvent('alpha-wings:server:getWingMembersForRankManagement', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    Database.IsWingLeader(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end

        Database.GetWingMembersWithGrades(wingId, function(members)
            TriggerClientEvent('alpha-wings:client:receiveWingMembersForRankManagement', src, members or {}, wingId)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateMemberGradeByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local leaderCitizenid = Player.PlayerData.citizenid
    CheckWingLeadership(leaderCitizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end

        local gradeLevel = tonumber(data.newGrade) or 0
        Database.UpdateMemberGrade(data.wingId, data.citizenid, gradeLevel, function(success, message)
            if success then
                Database.LogActivity(data.wingId, data.citizenid, 'grade_updated_by_leader', 'Grade changed to level ' .. gradeLevel .. ' by ' .. Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, 0)

                TriggerClientEvent('QBCore:Notify', src, string.format("%s's grade updated to level %d successfully!", data.memberName, gradeLevel), "success")

                print(string.format("[Alpha Wings] Member %s grade updated to level %d in wing %d by leader %s",
                    data.memberName,
                    gradeLevel,
                    data.wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, message or "Failed to update member rank!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:sendWingAnnouncementByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end

        local senderName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname

        Database.GetWingById(data.wingId, function(wingData)
            if not wingData or not wingData[1] then
                TriggerClientEvent('QBCore:Notify', src, "Wing not found!", "error")
                return
            end

            local wingInfo = wingData[1]

            Database.SendWingAnnouncement(data.wingId, citizenid, senderName, data.message, function(success)
                if success then
                    TriggerClientEvent('QBCore:Notify', src, "Announcement sent successfully!", "success")

                    Database.GetWingMembers(data.wingId, function(members)
                        for _, member in pairs(members) do
                            local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(member.citizenid)
                            if targetPlayer then
                                TriggerClientEvent('alpha-wings:client:receiveWingAnnouncement', targetPlayer.PlayerData.source, {
                                    wingName = wingInfo.name,
                                    senderName = senderName,
                                    message = data.message
                                })
                            end
                        end
                    end)

                    print(string.format("[Alpha Wings] Wing announcement sent by leader %s to wing %d",
                        senderName,
                        data.wingId
                    ))
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to send announcement!", "error")
                end
            end)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:getWingStatisticsForLeader', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end

        Database.GetWingDetailedStatistics(wingId, function(stats)
            TriggerClientEvent('alpha-wings:client:receiveWingStatisticsForLeader', src, stats)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:setWingRadioByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end
        Database.UpdateWingRadio(data.wingId, data.radioFrequency, function(success)
            if success then
                TriggerClientEvent('QBCore:Notify', src, string.format("Wing radio frequency updated to %s!", data.radioFrequency), "success")

                print(string.format("[Alpha Wings] Wing %d radio frequency updated to %s by leader %s",
                    data.wingId,
                    data.radioFrequency,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update wing radio frequency!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateWingDescriptionByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end
        Database.UpdateWingDescription(data.wingId, data.description, function(success)
            if success then
                TriggerClientEvent('QBCore:Notify', src, "Wing description updated successfully!", "success")

                print(string.format("[Alpha Wings] Wing %d description updated by leader %s",
                    data.wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update wing description!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateMaxMembersByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end
        Database.UpdateWingMaxMembers(data.wingId, data.maxMembers, function(success)
            if success then
                TriggerClientEvent('QBCore:Notify', src, string.format("Wing maximum members updated to %d!", data.maxMembers), "success")

                print(string.format("[Alpha Wings] Wing %d max members updated to %d by leader %s",
                    data.wingId,
                    data.maxMembers,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update wing max members!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:checkWingGradeStatus', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if wingInfo then
            Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
                local gradeInfo = {
                    wing_name = wingInfo.name,
                    wing_grade_level = memberWithGrade and memberWithGrade.wing_grade_level or 0,
                    grade_name = memberWithGrade and memberWithGrade.grade_name or "No Grade",
                    police_grade = Player.PlayerData.job.grade.name or "Unknown",
                    wing_grade_level = memberWithGrade and memberWithGrade.wing_grade_level or 0
                }

                TriggerClientEvent('alpha-wings:client:receiveWingGradeStatus', src, gradeInfo)
            end)
        else
            TriggerClientEvent('alpha-wings:client:receiveWingGradeStatus', src, nil)
        end
    end)
end)

print("[Alpha Wings] Wings System server started successfully!")
RegisterNetEvent('alpha-wings:server:flightOps', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        TriggerClientEvent('QBCore:Notify', src, "Flight operations processed on server", "success")
    end
end)
RegisterNetEvent('alpha-wings:server:aircraftManagement', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        TriggerClientEvent('QBCore:Notify', src, "Aircraft management processed on server", "success")
    end
end)

RegisterNetEvent('alpha-wings:server:personnelRecords', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        TriggerClientEvent('QBCore:Notify', src, "Personnel records processed on server", "success")
    end
end)

RegisterNetEvent('alpha-wings:server:createWing', function(wingData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    if not wingData or not wingData.name or not wingData.description or not wingData.maxMembers or not wingData.leader then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing data provided!", "error")
        return
    end
    
    if wingData.maxMembers < 1 then
        TriggerClientEvent('QBCore:Notify', src, "Maximum officers must be at least 1!", "error")
        return
    end
    
    local leaderPlayerId = tonumber(wingData.leader)
    if not leaderPlayerId then
        TriggerClientEvent('QBCore:Notify', src, "Wing commander must be a valid player ID!", "error")
        return
    end
    
    local function createWingInDatabase(leaderName, leaderCitizenId)
        local wingCreateData = {
            name = wingData.name,
            description = wingData.description,
            maxMembers = wingData.maxMembers,
            leaderCitizenId = leaderCitizenId,
            leaderName = leaderName,
            leaderId = wingData.leader,
            logo = wingData.logo or '',
            createdBy = Player.PlayerData.citizenid,
            createdByName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        }
        
        Database.CreateWing(wingCreateData, function(wingId, errorMsg)
            if wingId then
                print(string.format("[Alpha Wings] New police wing created: %s (ID: %d) by %s (%s)", 
                    wingCreateData.name, 
                    wingId,
                    wingCreateData.createdByName,
                    Player.PlayerData.citizenid
                ))
                
                Database.LogActivity(wingId, Player.PlayerData.citizenid, 'wing_created', 'Wing created: ' .. wingCreateData.name, 0)
                
                TriggerClientEvent('QBCore:Notify', src, string.format("Police wing '%s' created successfully!", wingCreateData.name), "success")
                
                TriggerClientEvent('alpha-wings:client:wingCreated', src, {id = wingId, name = wingCreateData.name})
            else
                local errorMessage = errorMsg or "Failed to create wing. Please try again."
                TriggerClientEvent('QBCore:Notify', src, errorMessage, "error")
            end
        end)
    end
    
    local LeaderPlayer = QBCore.Functions.GetPlayer(leaderPlayerId)
    local leaderName = "Unknown Officer"
    local leaderCitizenId = nil
    
    if LeaderPlayer then
        if not IsPoliceOfficer(LeaderPlayer) then
            TriggerClientEvent('QBCore:Notify', src, "Wing commander must be a police officer!", "error")
            return
        end
        leaderName = LeaderPlayer.PlayerData.charinfo.firstname .. " " .. LeaderPlayer.PlayerData.charinfo.lastname
        leaderCitizenId = LeaderPlayer.PlayerData.citizenid
        
        createWingInDatabase(leaderName, leaderCitizenId)
    else
        MySQL.query('SELECT citizenid, charinfo FROM players WHERE id = ?', {wingData.leader}, function(result)
            if result[1] then
                local charinfo = json.decode(result[1].charinfo)
                leaderName = charinfo.firstname .. " " .. charinfo.lastname
                leaderCitizenId = result[1].citizenid
                
                MySQL.query('SELECT job FROM players WHERE citizenid = ?', {leaderCitizenId}, function(jobResult)
                    if not jobResult[1] or json.decode(jobResult[1].job).name ~= 'police' then
                        TriggerClientEvent('QBCore:Notify', src, "Wing commander must be a police officer!", "error")
                        return
                    end
                    
                    createWingInDatabase(leaderName, leaderCitizenId)
                end)
            else
                TriggerClientEvent('QBCore:Notify', src, "Player not found!", "error")
                return
            end
        end)
    end
end)

RegisterNetEvent('alpha-wings:server:getAllWings', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Check if player is also a wing creator (chiefs + creators can access)
    Database.IsWingCreator(citizenid, function(isCreator)
        -- Allow access for all chiefs (they can manage all wings)
        Database.GetAllWings(function(wings)
            TriggerClientEvent('alpha-wings:client:receiveAllWings', src, wings or {})
        end)
    end)
end)

-- Server event for getting wing members
RegisterNetEvent('alpha-wings:server:getWingMembers', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- Check if player is police
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    -- Validate wing ID
    if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    Database.GetWingMembers(wingId, function(members)
        TriggerClientEvent('alpha-wings:client:receiveWingMembers', src, members or {}, wingId)
    end)
end)

-- Server event for getting wing members for removal
RegisterNetEvent('alpha-wings:server:getWingMembersForRemoval', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- Check if player is police chief
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    -- Validate wing ID
    if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    Database.GetWingMembers(wingId, function(members)
        TriggerClientEvent('alpha-wings:client:receiveWingMembersForRemoval', src, members or {}, wingId)
    end)
end)

-- Server event for getting player's wing information
RegisterNetEvent('alpha-wings:server:getPlayerWingInfo', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- Check if player is police
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if wingInfo then
            -- Get member with grade information
            Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
                -- Get player's current job grade name
                local playerJobGrade = Player.PlayerData.job.grade.name or "Unknown"
                
                -- Get wing grade
                local wingGradeText = "No Wing Grade"
                if memberWithGrade and memberWithGrade.grade_name then
                    wingGradeText = string.format("Level %d: %s", memberWithGrade.wing_grade_level, memberWithGrade.grade_name)
                end
                
                -- Check if player is a wing leader (based on wing grade level)
                local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
                
                local wingData = {
                    wingId = wingInfo.id,
                    wingName = wingInfo.name,
                    playerGrade = playerJobGrade,
                    wingGrade = wingGradeText,
                    wingRadio = wingInfo.radio_frequency or "Not Set",
                    wingLeader = wingInfo.leader_name,
                    wingGradeLevel = memberWithGrade and memberWithGrade.wing_grade_level or 0,
                    isLeader = isLeader
                }
                
                TriggerClientEvent('alpha-wings:client:receivePlayerWingInfo', src, wingData)
            end)
        else
            TriggerClientEvent('alpha-wings:client:receivePlayerWingInfo', src, nil)
        end
    end)
end)

-- Server event for setting wing radio frequency
RegisterNetEvent('alpha-wings:server:setWingRadio', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or (not data.radioFrequency and not data.frequency) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end

    local radioFrequency = data.radioFrequency or data.frequency
    
    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= wingId then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            if not isLeader then
                TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leader authorization required.", "error")
                return
            end

            Database.UpdateWingRadio(wingId, radioFrequency, function(success)
                if success then
                    TriggerClientEvent('QBCore:Notify', src, string.format("Wing radio frequency updated to %s", radioFrequency), "success")
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to update radio frequency!", "error")
                end
            end)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:getWingMembersAsLeader', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            if not isLeader then
                return
            end

            Database.GetWingMembers(wingId, function(members)
                TriggerClientEvent('alpha-wings:client:receiveWingMembersAsLeader', src, members or {}, wingId)
            end)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:leaderAddWingMember', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or not data.playerId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    local playerId = tonumber(data.playerId)
    
    if not wingId or not playerId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID or player ID!", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= wingId then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            if not isLeader then
                TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leader authorization required (Grade 5+ required).", "error")
                return
            end

            local TargetPlayer = QBCore.Functions.GetPlayer(playerId)
            if not TargetPlayer then
                TriggerClientEvent('QBCore:Notify', src, "Player not found or not online!", "error")
                return
            end

            if not IsPoliceOfficer(TargetPlayer) then
                TriggerClientEvent('QBCore:Notify', src, "Target player must be a police officer!", "error")
                return
            end

            Database.CanAddPlayerToWing(TargetPlayer.PlayerData.citizenid, wingId, function(canAdd)
                if not canAdd then
                    TriggerClientEvent('QBCore:Notify', src, "Player is already a member of this wing!", "error")
                    return
                end

                Database.GetWingCapacity(wingId, function(capacityInfo)
                    if not capacityInfo or not capacityInfo[1] then
                        TriggerClientEvent('QBCore:Notify', src, "Wing not found!", "error")
                        return
                    end

                    local capacity = capacityInfo[1]
                    if capacity.current_members >= capacity.max_members then
                        TriggerClientEvent('QBCore:Notify', src, "Wing is at maximum capacity!", "error")
                        return
                    end

                     local memberData = {
                        citizenid = TargetPlayer.PlayerData.citizenid,
                        playerName = TargetPlayer.PlayerData.charinfo.firstname .. " " .. TargetPlayer.PlayerData.charinfo.lastname,
                        gradeLevel = 0   
                    }

                    Database.AddWingMember(wingId, memberData, function(success)
                        if success then
                             Database.LogActivity(wingId, Player.PlayerData.citizenid, 'member_added', 'Member added: ' .. memberData.playerName, 0)

                            TriggerClientEvent('QBCore:Notify', src, string.format("Successfully added %s to the wing!", memberData.playerName), "success")
                            TriggerClientEvent('QBCore:Notify', playerId, "You have been added to a police wing!", "info")

                            print(string.format("[Alpha Wings] %s added %s to wing %d",
                                Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                                memberData.playerName,
                                wingId
                            ))
                        else
                            TriggerClientEvent('QBCore:Notify', src, "Failed to add member to wing!", "error")
                        end
                    end)
                end)
            end)
        end)
    end)
end)

-- Server event for leader removing wing member
RegisterNetEvent('alpha-wings:server:leaderRemoveWingMember', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- Check if player is police
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    -- Validate data
    if not data or not data.wingId or not data.citizenid then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    -- Check if player is leader of this wing
    local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= wingId then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        -- Check leadership based on wing grade level
        Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            if not isLeader then
                TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leader authorization required (Grade 5+ required).", "error")
                return
            end

            Database.RemoveWingMember(wingId, data.citizenid, function(success)
                if success then
                    -- Log activity
                    Database.LogActivity(wingId, Player.PlayerData.citizenid, 'member_removed', 'Member removed by wing leader', 0)

                    TriggerClientEvent('QBCore:Notify', src, "Successfully removed member from wing!", "success")

                    -- Notify the removed player if online
                    local RemovedPlayer = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)
                    if RemovedPlayer then
                        TriggerClientEvent('QBCore:Notify', RemovedPlayer.PlayerData.source, "You have been removed from your wing by the wing leader.", "info")
                    end

                    print(string.format("[Alpha Wings] %s removed member %s from wing %d",
                        Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                        data.citizenid,
                        wingId
                    ))
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to remove member from wing!", "error")
                end
            end)
        end)
    end)
end)

-- Server event for changing wing member grade
RegisterNetEvent('alpha-wings:server:changeMemberGrade', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    -- Check if player is police
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    -- Validate data
    if not data or not data.wingId or not data.citizenid or not data.newGrade then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    -- Check if player is leader of this wing (based on wing grade)
    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required (Leader grade level 5+ required).", "error")
            return
        end

        -- Validate grade level
        local gradeLevel = tonumber(data.newGrade)
        if not gradeLevel or gradeLevel < 0 or gradeLevel > 5 then
            TriggerClientEvent('QBCore:Notify', src, "Invalid grade level! Must be between 0 and 5.", "error")
            return
        end

        -- Update member grade
        MySQL.update('UPDATE police_wing_members SET wing_grade_level = ? WHERE wing_id = ? AND citizenid = ?', {
            gradeLevel, wingId, data.citizenid
        }, function(success)
            if success then
                -- Log activity
                Database.LogActivity(wingId, Player.PlayerData.citizenid, 'grade_changed', 'Member grade changed to level: ' .. gradeLevel, 0)
                
                TriggerClientEvent('QBCore:Notify', src, "Member grade updated successfully!", "success")
                
                -- Notify the affected player if online
                local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)
                if TargetPlayer then
                    TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, "Your wing grade has been updated to level: " .. gradeLevel, "info")
                end
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update member grade!", "error")
            end
        end)
    end)
end)

-- Server event for requesting transfer leadership member list
RegisterNetEvent('alpha-wings:server:requestTransferLeadershipMembers', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- Check if player is police
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    -- Validate wing ID
    if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    -- Check if player is leader of this wing
    local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        -- Check leadership based on wing grade level
        Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            if not isLeader then
                -- Silent fail for non-leaders, no notification
                return
            end

            Database.GetWingMembers(wingId, function(members)
                TriggerClientEvent('alpha-wings:client:receiveWingMembersForTransfer', src, members or {}, wingId)
            end)
        end)
    end)
end)

-- Server event for transferring wing leadership
RegisterNetEvent('alpha-wings:server:transferLeadership', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- Check if player is police
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    -- Validate data
    if not data or not data.wingId or not data.newLeaderCitizenId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    -- Check if player is leader of this wing
    local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= wingId then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
         Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            if not isLeader then
                TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leader authorization required (Grade 5+ required).", "error")
                return
            end
        
             MySQL.query('SELECT * FROM police_wing_members WHERE wing_id = ? AND citizenid = ? AND is_active = 1', {
                wingId, data.newLeaderCitizenId
            }, function(memberResult)
                if not memberResult or not memberResult[1] then
                    TriggerClientEvent('QBCore:Notify', src, "New leader must be a member of this wing!", "error")
                    return
                end

                local newLeaderName = memberResult[1].player_name

                 Database.UpdateWingLeader(wingId, data.newLeaderCitizenId, newLeaderName, function(success)
                    if success then
                         local oldLeaderGradeLevel = 0 -- Previous leader goes to grade 0
                        MySQL.update('UPDATE police_wing_members SET wing_grade_level = ? WHERE wing_id = ? AND citizenid = ?', {
                            oldLeaderGradeLevel, wingId, citizenid
                        })

                         local newLeaderGradeLevel = 5 -- Leadership grade level
                        MySQL.update('UPDATE police_wing_members SET wing_grade_level = ? WHERE wing_id = ? AND citizenid = ?', {
                            newLeaderGradeLevel, wingId, data.newLeaderCitizenId
                        })

                         Database.LogActivity(wingId, citizenid, 'leadership_transferred', 'Leadership transferred to: ' .. newLeaderName, 0)

                        TriggerClientEvent('QBCore:Notify', src, "Leadership transferred successfully!", "success")

                         local NewLeaderPlayer = QBCore.Functions.GetPlayerByCitizenId(data.newLeaderCitizenId)
                        if NewLeaderPlayer then
                            TriggerClientEvent('QBCore:Notify', NewLeaderPlayer.PlayerData.source, "You have been promoted to wing leader!", "success")
                        end

                        print(string.format("[Alpha Wings] Leadership of wing %d transferred from %s to %s",
                            wingId,
                            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                            newLeaderName
                        ))
                    else
                        TriggerClientEvent('QBCore:Notify', src, "Failed to transfer leadership!", "error")
                    end
                end)
            end)
        end)
    end)
end)

 RegisterNetEvent('alpha-wings:server:getAllWingsForGrades', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    Database.GetAllWings(function(wings)
        TriggerClientEvent('alpha-wings:client:receiveAllWingsForGrades', src, wings or {})
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingGrades', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    Database.GetWingGrades(wingId, function(grades)
         if _G.gradeAssignmentRequest and _G.gradeAssignmentRequest[src] then
            TriggerClientEvent('alpha-wings:client:receiveWingGradesForAssignment', src, grades or {}, wingId)
            _G.gradeAssignmentRequest[src] = nil
        else
            TriggerClientEvent('alpha-wings:client:receiveWingGrades', src, grades or {}, wingId)
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:createWingGrade', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not data or not data.wingId or not data.name or not data.level then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    local gradeData = {
        name = data.name,
        level = tonumber(data.level),
        description = data.description or "",
        permissions = data.permissions or {}
    }
    
    Database.CreateWingGrade(wingId, gradeData, function(success)
        if success then
            TriggerClientEvent('QBCore:Notify', src, "Wing grade created successfully!", "success")
            
            print(string.format("^2[Alpha Wings]^7 Wing grade '%s' (Level %d) created for wing %d by %s", 
                gradeData.name, 
                gradeData.level, 
                wingId,
                Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            ))
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to create wing grade!", "error")
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:updateWingGrade', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not data or not data.gradeId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local updateData = {}
    if data.name then updateData.grade_name = data.name end
    if data.level then updateData.grade_level = tonumber(data.level) end
    if data.description then updateData.grade_description = data.description end
    if data.permissions then updateData.permissions = data.permissions end
    
    Database.UpdateWingGrade(data.gradeId, updateData, function(success)
        if success then
            TriggerClientEvent('QBCore:Notify', src, "Wing grade updated successfully!", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to update wing grade!", "error")
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:deleteWingGrade', function(gradeId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not gradeId or not tonumber(gradeId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid grade ID!", "error")
        return
    end
    
    Database.DeleteWingGrade(gradeId, function(success)
        if success then
            TriggerClientEvent('QBCore:Notify', src, "Wing grade deleted successfully!", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to delete wing grade!", "error")
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:assignMemberGrade', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not data or not data.wingId or not data.citizenid or not data.gradeLevel then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    local gradeLevel = tonumber(data.gradeLevel)
    
    if not wingId or not gradeLevel then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID or grade level!", "error")
        return
    end
    
    Database.UpdateMemberGrade(wingId, data.citizenid, gradeLevel, function(success)
        if success then
            TriggerClientEvent('QBCore:Notify', src, "Member grade assigned successfully!", "success")
            
             local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)
            if TargetPlayer then
                TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, "Your wing grade has been updated!", "info")
            end
            
             Database.LogActivity(wingId, Player.PlayerData.citizenid, 'grade_assigned', 'Member grade changed to level: ' .. gradeLevel, 0)
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to assign member grade!", "error")
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingGradesForAssignment', function(wingId)
    local src = source
    
     if not _G.gradeAssignmentRequest then
        _G.gradeAssignmentRequest = {}
    end
    
     _G.gradeAssignmentRequest[src] = true
    
     local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    Database.GetWingGrades(wingId, function(grades)
        TriggerClientEvent('alpha-wings:client:receiveWingGradesForAssignment', src, grades or {}, wingId)
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingMembersWithGrades', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

     if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    Database.GetWingMembersWithGrades(wingId, function(members)
         local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.job.grade.level >= Config.PoliceJob.chiefGrade then
            TriggerClientEvent('alpha-wings:client:receiveWingMembersWithGrades', src, members or {}, wingId)
        else
            TriggerClientEvent('alpha-wings:client:displayWingMembersWithGrades', src, members or {}, wingId)
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingMembersForLeaderGrade', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

     if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid

     CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
             return
        end

        Database.GetWingMembersWithGrades(wingId, function(members)
            TriggerClientEvent('alpha-wings:client:receiveWingMembersForLeaderGrade', src, members or {}, wingId)
        end)
    end)
end)

 RegisterNetEvent('alpha-wings:server:sendWingAnnouncement', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
     if not data or not data.wingId or not data.message then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
     local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= wingId then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
         Database.GetMemberWithGrade(wingInfo.id, citizenid, function(memberWithGrade)
            local isLeader = (memberWithGrade and memberWithGrade.wing_grade_level >= 5)
            if not isLeader then
                TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leader authorization required (Grade 5+ required).", "error")
                return
            end
        
             Database.StoreAnnouncement(wingId, citizenid, data.message, function(success)
                if success then
                     Database.GetWingMembers(wingId, function(members)
                        if members then
                            local senderName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname

                            for _, member in pairs(members) do
                                local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.citizenid)
                                if MemberPlayer then
                                    TriggerClientEvent('alpha-wings:client:receiveWingAnnouncement', MemberPlayer.PlayerData.source, {
                                        wingName = wingInfo.name,
                                        senderName = senderName,
                                        message = data.message
                                    })
                                end
                            end

                             Database.LogActivity(wingId, citizenid, 'announcement_sent', 'Wing announcement: ' .. data.message, 0)

                            TriggerClientEvent('QBCore:Notify', src, "Wing announcement sent successfully!", "success")

                            print(string.format("^2[Alpha Wings]^7 Wing announcement sent by %s to wing %d: %s",
                                senderName, wingId, data.message
                            ))
                        else
                            TriggerClientEvent('QBCore:Notify', src, "Failed to get wing members!", "error")
                        end
                    end)
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to store announcement!", "error")
                end
            end)
        end)
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingStatistics', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
     if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
     local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
         CheckGradeBasedLeadership(citizenid, tonumber(wingId), function(isLeader, memberWithGrade)
            if not isLeader then
                TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leader authorization required (Grade 5+ required).", "error")
                return
            end
        
             Database.GetWingById(wingId, function(wingData)
                if not wingData or not wingData[1] then
                    TriggerClientEvent('QBCore:Notify', src, "Wing not found!", "error")
                    return
                end

                local wing = wingData[1]
                Database.GetWingMembers(wingId, function(members)
                    local activeMembers = 0
                    if members then
                        for _, member in pairs(members) do
                            if member.is_active == 1 then
                                activeMembers = activeMembers + 1
                            end
                        end
                    end

                    local stats = {
                        totalMembers = wing.current_members or 0,
                        activeMembers = activeMembers,
                        createdAt = wing.created_at or "Unknown",
                        createdBy = wing.created_by_name or "Unknown"
                    }

                    TriggerClientEvent('alpha-wings:client:receiveWingStatistics', src, stats)
                end)
            end)
        end)
    end)
end)

 RegisterNetEvent('alpha-wings:server:addWingMember', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not data or not data.wingId or not data.playerId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    local playerId = tonumber(data.playerId)
    
    if not wingId or not playerId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID or player ID!", "error")
        return
    end
    
     local TargetPlayer = QBCore.Functions.GetPlayer(playerId)
    if not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "Player not found or not online!", "error")
        return
    end
    
    if not IsPoliceOfficer(TargetPlayer) then
        TriggerClientEvent('QBCore:Notify', src, "Target player must be a police officer!", "error")
        return
    end
    
     local memberData = {
        citizenid = TargetPlayer.PlayerData.citizenid,
        playerName = TargetPlayer.PlayerData.charinfo.firstname .. " " .. TargetPlayer.PlayerData.charinfo.lastname,
        rank = "Member"
    }
    
    Database.AddWingMember(wingId, memberData, function(success)
        if success then
            TriggerClientEvent('QBCore:Notify', src, string.format("Successfully added %s to the wing!", memberData.playerName), "success")
            TriggerClientEvent('QBCore:Notify', playerId, "You have been added to a police wing!", "info")
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to add member to wing!", "error")
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:removeWingMember', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not data or not data.wingId or not data.citizenid then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    Database.RemoveWingMember(wingId, data.citizenid, function(success)
        if success then
            TriggerClientEvent('QBCore:Notify', src, "Successfully removed member from wing!", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to remove member from wing!", "error")
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:deleteWing', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
     Database.GetWingById(wingId, function(wing)
        if not wing then
            TriggerClientEvent('QBCore:Notify', src, "Wing not found!", "error")
            return
        end
        
        local wingName = wing.name
        
         Database.DeleteWing(wingId, function(success)
            if success then
                 print(string.format("^1[Alpha Wings]^7 Wing deleted: %s by %s (%s)", 
                    wingName, 
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                    Player.PlayerData.citizenid
                ))
                
                TriggerClientEvent('QBCore:Notify', src, string.format("Wing '%s' has been deleted!", wingName), "success")
                TriggerClientEvent('alpha-wings:client:wingDeleted', src, wingId)
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to delete wing!", "error")
            end
        end)
    end)
end)

 RegisterNetEvent('alpha-wings:server:editWing', function(wingId, editData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     TriggerClientEvent('QBCore:Notify', src, "Wing editing feature is currently under development.", "info")
end)

 RegisterNetEvent('alpha-wings:server:getPersonalWingInfo', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    local playerCitizenId = Player.PlayerData.citizenid
    
    Database.GetPlayerWingInfo(playerCitizenId, function(wingInfo)
        local playerWingInfo = nil
        
        if wingInfo then
            playerWingInfo = {
                wingName = wingInfo.name,
                wingId = wingInfo.id,
                wingGradeLevel = wingInfo.wing_grade_level or 0,
                joinedAt = wingInfo.joined_at,
                points = wingInfo.points or 0,
                wingPoints = wingInfo.wing_points or 0
            }
        end
        
        TriggerClientEvent('alpha-wings:client:receivePersonalWingInfo', src, playerWingInfo)
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingsPoints', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    Database.GetWingPoints(function(pointsData)
        TriggerClientEvent('alpha-wings:client:receiveWingsPoints', src, pointsData or {})
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingsStatistics', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    Database.GetWingStatistics(function(statsData)
        TriggerClientEvent('alpha-wings:client:receiveWingsStatistics', src, statsData or {})
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingsLeaders', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    local leadersData = {}
    
    for wingId, wingData in pairs(WingsData) do
        local wingPoints = WingsPoints[wingId] or {}
        local leaderOnline = false
        
         if wingData.leaderId then
            local LeaderPlayer = QBCore.Functions.GetPlayer(tonumber(wingData.leaderId))
            leaderOnline = LeaderPlayer ~= nil
        end
        
        table.insert(leadersData, {
            id = wingId,
            name = wingData.name,
            leader = wingData.leader,
            leaderId = wingData.leaderId,
            leaderCitizenId = wingData.leaderCitizenId,
            leaderOnline = leaderOnline,
            currentMembers = wingData.currentMembers,
            maxMembers = wingData.maxMembers,
            createdAt = wingData.createdAt,
            createdByName = wingData.createdByName,
            totalPoints = wingPoints.totalPoints or 0,
            lastActivity = wingPoints.lastActivity,
            members = wingData.members
        })
    end
    
    TriggerClientEvent('alpha-wings:client:receiveWingsLeaders', src, leadersData)
end)

 RegisterNetEvent('alpha-wings:server:getAllWingsForBrowsing', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     local wingsArray = {}
    for wingId, wingData in pairs(WingsData) do
        local wingPoints = WingsPoints[wingId] or {}
        local wingInfo = {}
        
         for k, v in pairs(wingData) do
            wingInfo[k] = v
        end
        
         wingInfo.totalPoints = wingPoints.totalPoints or 0
        wingInfo.lastActivity = wingPoints.lastActivity
        
        table.insert(wingsArray, wingInfo)
    end
    
    TriggerClientEvent('alpha-wings:client:receiveAllWingsForBrowsing', src, wingsArray)
end)

 RegisterNetEvent('alpha-wings:server:getOnlineOfficers', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    local officers = GetOnlinePoliceOfficers()
    TriggerClientEvent('alpha-wings:client:receiveOnlineOfficers', src, officers)
end)

 RegisterNetEvent('alpha-wings:server:getWingsForAssignment', function(officerCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     Database.GetAllWings(function(wings)
         Database.GetPlayerWingInfo(officerCitizenId, function(currentWing)
            TriggerClientEvent('alpha-wings:client:receiveWingsForAssignment', src, wings or {}, officerCitizenId, currentWing)
        end)
    end)
end)

 RegisterNetEvent('alpha-wings:server:assignOfficerToWing', function(officerCitizenId, wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(officerCitizenId)
    local officerName = "Unknown Officer"
    
    if TargetPlayer then
        if not IsPoliceOfficer(TargetPlayer) then
            TriggerClientEvent('QBCore:Notify', src, "Target is not a police officer!", "error")
            return
        end
        officerName = TargetPlayer.PlayerData.charinfo.firstname .. " " .. TargetPlayer.PlayerData.charinfo.lastname
    else
         MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', {officerCitizenId}, function(result)
            if result[1] then
                local charinfo = json.decode(result[1].charinfo)
                officerName = charinfo.firstname .. " " .. charinfo.lastname
            end
        end)
    end
    
     Database.RemoveWingMember(nil, officerCitizenId, function()
         Database.AddWingMember(wingId, {
            citizenid = officerCitizenId,
            playerName = officerName,
            gradeLevel = 1   
        }, function(success)
            if success then
                 Database.LogActivity(wingId, Player.PlayerData.citizenid, 'officer_assigned', 'Officer assigned: ' .. officerName, 0)
                
                print(string.format("^2[Alpha Wings]^7 Officer %s (%s) assigned to wing %d by %s", 
                    officerName, 
                    officerCitizenId, 
                    wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
                
                 if TargetPlayer then
                    TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, "You have been assigned to a new wing!", "success")
                end
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to assign officer to wing!", "error")
            end
        end)
    end)
end)

 RegisterNetEvent('alpha-wings:server:removeOfficerFromWing', function(officerCitizenId, wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
     local TargetPlayer = QBCore.Functions.GetPlayerByCitizenId(officerCitizenId)
    local officerName = "Unknown Officer"
    
    if TargetPlayer then
        officerName = TargetPlayer.PlayerData.charinfo.firstname .. " " .. TargetPlayer.PlayerData.charinfo.lastname
    else
         MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', {officerCitizenId}, function(result)
            if result[1] then
                local charinfo = json.decode(result[1].charinfo)
                officerName = charinfo.firstname .. " " .. charinfo.lastname
            end
        end)
    end
    
    Database.RemoveWingMember(wingId, officerCitizenId, function(success)
        if success then
             Database.LogActivity(wingId, Player.PlayerData.citizenid, 'officer_removed', 'Officer removed: ' .. officerName, 0)
            
            print(string.format("^3[Alpha Wings]^7 Officer %s (%s) removed from wing %d by %s", 
                officerName, 
                officerCitizenId, 
                wingId,
                Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            ))
            
             if TargetPlayer then
                TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, "You have been removed from your wing assignment!", "info")
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to remove officer from wing!", "error")
        end
    end)
end)

 local function AwardWingPoints(wingId, pointType, citizenid, description)
    if not Config.WingsSystem.enablePointsSystem then
        return
    end
    
    local pointsToAward = 0
    
     if pointType == 'mission' then
        pointsToAward = Config.PointsSystem.missionCompletion
    elseif pointType == 'training' then
        pointsToAward = Config.PointsSystem.trainingSession
    elseif pointType == 'event' then
        pointsToAward = Config.PointsSystem.communityEvent
    elseif pointType == 'leadership' then
        pointsToAward = Config.PointsSystem.leadershipActivity
    elseif pointType == 'daily' then
        pointsToAward = Config.PointsSystem.dailyActivity
    end
    
    if pointsToAward > 0 then
         Database.GetWingPoints(function(wingsPoints)
            for _, wing in ipairs(wingsPoints) do
                if wing.id == wingId then
                    local newTotalPoints = (wing.total_points or 0) + pointsToAward
                    local newCategoryPoints = (wing[pointType .. '_points'] or 0) + pointsToAward
                    
                    local updateData = {
                        totalPoints = newTotalPoints
                    }
                    updateData[pointType .. 'Points'] = newCategoryPoints
                    
                    Database.UpdateWingPoints(wingId, updateData, function()
                         if Config.WingsSystem.enableActivityLogging then
                            Database.LogActivity(wingId, citizenid, pointType .. '_points', description, pointsToAward)
                        end
                        
                        print(string.format("^2[Alpha Wings]^7 %d points awarded to wing %d for %s", pointsToAward, wingId, pointType))
                    end)
                    break
                end
            end
        end)
    end
end

 exports('AwardWingPoints', AwardWingPoints)

 RegisterNetEvent('alpha-wings:server:awardPoints', function(wingId, pointType, amount, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    if not wingId or not pointType or not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Invalid point award data!", "error")
        return
    end
    
     Database.GetWingPoints(function(wingsPoints)
        for _, wing in ipairs(wingsPoints) do
            if wing.id == wingId then
                local newTotalPoints = (wing.total_points or 0) + amount
                local categoryField = pointType .. '_points'
                local newCategoryPoints = (wing[categoryField] or 0) + amount
                
                local updateData = {
                    totalPoints = newTotalPoints
                }
                updateData[pointType .. 'Points'] = newCategoryPoints
                
                Database.UpdateWingPoints(wingId, updateData, function()
                     local description = string.format("Manual point award: %s (%d points)", reason or "No reason provided", amount)
                    Database.LogActivity(wingId, Player.PlayerData.citizenid, 'manual_points', description, amount)
                    
                    TriggerClientEvent('QBCore:Notify', src, string.format("%d points awarded to wing!", amount), "success")
                    
                    print(string.format("^2[Alpha Wings]^7 %d %s points manually awarded to wing %d by %s", 
                        amount, 
                        pointType, 
                        wingId, 
                        Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                    ))
                end)
                break
            end
        end
    end)
end)

 CreateThread(function()
    Wait(3000) -- Wait for database to be ready
    
    if not Database then
        print("^1[Alpha Wings]^7 Error: Database object not found!")
        return
    end
    
    print("^3[Alpha Wings]^7 Checking existing wings for grade initialization...")
    
    Database.GetAllWings(function(wings)
        if wings and #wings > 0 then
            print(string.format("^3[Alpha Wings]^7 Found %d wings, checking grades...", #wings))
            for _, wing in pairs(wings) do
                Database.GetWingGrades(wing.id, function(grades)
                    if not grades or #grades == 0 then
                        print(string.format("^3[Alpha Wings]^7 Initializing default grades for wing: %s", wing.name))
                        Database.InitializeDefaultWingGrades(wing.id, function(success)
                            if success then
                                print(string.format("^2[Alpha Wings]^7 Default grades created for wing: %s", wing.name))
                            else
                                print(string.format("^1[Alpha Wings]^7 Failed to create grades for wing: %s", wing.name))
                            end
                        end)
                    else
                        print(string.format("^2[Alpha Wings]^7 Wing '%s' already has %d grades", wing.name, #grades))
                    end
                end)
            end
        else
            print("^3[Alpha Wings]^7 No existing wings found.")
        end
    end)
end)

 RegisterNetEvent('alpha-wings:server:getWingMembersForLeader', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
     if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
     if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
     local citizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        local isLeader = (wingInfo.rank == "Leader" or wingInfo.rank == "Creator" or wingInfo.rank == "Creator & Leader")
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required.", "error")
            return
        end
        
        Database.GetWingMembersWithGrades(wingId, function(members)
            Database.GetWingById(wingId, function(wing)
                local wingName = wing and wing.name or "Unknown Wing"
                TriggerClientEvent('alpha-wings:client:receiveWingMembersForLeader', src, members or {}, wingId, wingName)
            end)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateWingByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if not data or not data.wingId or not data.updateData then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end

    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required (Grade 5+ required).", "error")
            return
        end

        local updateData = data.updateData
        if updateData.description then
            Database.UpdateWingDescription(wingId, updateData.description, function(success)
                if success then
                    TriggerClientEvent('QBCore:Notify', src, "Wing description updated successfully!", "success")
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to update wing description!", "error")
                end
            end)
        end

        if updateData.max_members then
            Database.UpdateWingMaxMembers(wingId, updateData.max_members, function(success)
                if success then
                    TriggerClientEvent('QBCore:Notify', src, "Wing max members updated successfully!", "success")
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to update wing max members!", "error")
                end
            end)
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:addMemberToWingByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if not data or not data.wingId or not data.citizenid then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end

    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required (Grade 5+ required).", "error")
            return
        end

        Database.CanAddPlayerToWing(data.citizenid, wingId, function(canAdd)
            if not canAdd then
                TriggerClientEvent('QBCore:Notify', src, "Player is already a member of this wing!", "error")
                return
            end

            Database.GetWingCapacity(wingId, function(capacityInfo)
                if not capacityInfo or not capacityInfo[1] then
                    TriggerClientEvent('QBCore:Notify', src, "Wing not found!", "error")
                    return
                end

                local capacity = capacityInfo[1]
                if capacity.current_members >= capacity.max_members then
                    TriggerClientEvent('QBCore:Notify', src, "Wing is at maximum capacity!", "error")
                    return
                end

                local memberData = {
                    citizenid = data.citizenid,
                    playerName = data.playerName,
                    gradeLevel = data.gradeLevel or 0
                }

                Database.AddWingMember(wingId, memberData, function(success)
                    if success then
                        Database.LogActivity(wingId, Player.PlayerData.citizenid, 'member_added', 'Member added: ' .. memberData.playerName, 0)

                        TriggerClientEvent('QBCore:Notify', src, string.format("Successfully added %s to the wing!", memberData.playerName), "success")

                        local AddedPlayer = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)
                        if AddedPlayer then
                            TriggerClientEvent('QBCore:Notify', AddedPlayer.PlayerData.source, "You have been added to a police wing!", "info")
                        end

                        print(string.format("^2[Alpha Wings]^7 %s added %s to wing %d",
                            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                            memberData.playerName,
                            wingId
                        ))
                    else
                        TriggerClientEvent('QBCore:Notify', src, "Failed to add member to wing!", "error")
                    end
                end)
            end)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:getPoliceOfficersForWing', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, tonumber(wingId), function(isLeader, memberInfo)
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required (Grade 5+ required).", "error")
            return
        end

        local officers = {}
        local players = QBCore.Functions.GetPlayers()

        for _, playerId in pairs(players) do
            local targetPlayer = QBCore.Functions.GetPlayer(playerId)
            if targetPlayer and IsPoliceOfficer(targetPlayer) then
                Database.CanAddPlayerToWing(targetPlayer.PlayerData.citizenid, wingId, function(canAdd)
                    table.insert(officers, {
                        citizenid = targetPlayer.PlayerData.citizenid,
                        name = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname,
                        grade = targetPlayer.PlayerData.job.grade.name,
                        canAdd = canAdd,
                        alreadyInThisWing = not canAdd
                    })
                end)
            end
        end

        Wait(500) 
        TriggerClientEvent('alpha-wings:client:receivePoliceOfficersForWing', src, officers, wingId)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateWingGradePermissions', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if not data or not data.wingId or not data.gradeLevel or not data.permissions then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end

    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required (Grade 5+ required).", "error")
            return
        end

        Database.UpdateWingGradePermissions(wingId, data.gradeLevel, data.permissions, function(success)
            if success then
                TriggerClientEvent('QBCore:Notify', src, "Grade permissions updated successfully!", "success")
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update grade permissions!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateMemberGrade', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if not data or not data.wingId or not data.citizenid or not data.newGrade then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local leaderCitizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(leaderCitizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(data.wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        local isLeader = (wingInfo.rank == "Leader" or wingInfo.rank == "Creator" or wingInfo.rank == "Creator & Leader")
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required.", "error")
            return
        end
        
        local gradeLevel = tonumber(data.newGrade) or 0
        Database.UpdateMemberGrade(data.wingId, data.citizenid, gradeLevel, function(success)
            if success then
                local description = string.format("Grade changed to level %d by %s", gradeLevel, Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)
                Database.LogActivity(data.wingId, data.citizenid, 'grade_changed', description, 0)

                TriggerClientEvent('QBCore:Notify', src, string.format("%s's grade updated to level %d!", data.memberName, gradeLevel), "success")

                print(string.format("^3[Alpha Wings]^7 Member grade updated: %s to level %d in wing %d by %s",
                    data.memberName,
                    gradeLevel,
                    data.wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update member grade!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:removeMemberAsLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or not data.citizenid then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local leaderCitizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(leaderCitizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(data.wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        local isLeader = (wingInfo.rank == "Leader" or wingInfo.rank == "Creator" or wingInfo.rank == "Creator & Leader")
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required.", "error")
            return
        end
        
        Database.GetPlayerWingInfo(data.citizenid, function(memberInfo)
            if memberInfo then
                local memberIsLeader = (memberInfo.rank == "Leader" or memberInfo.rank == "Creator" or memberInfo.rank == "Creator & Leader")
                if memberIsLeader then
                    TriggerClientEvent('QBCore:Notify', src, "Cannot remove other wing leaders!", "error")
                    return
                end
            end
            
            Database.RemoveMemberFromWing(data.wingId, data.citizenid, function(success)
                if success then
                    local description = string.format("Removed from wing by %s", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)
                    Database.LogActivity(data.wingId, data.citizenid, 'member_removed', description, 0)
                    
                    TriggerClientEvent('QBCore:Notify', src, string.format("%s removed from wing!", data.memberName), "success")
                    
                    print(string.format("^3[Alpha Wings]^7 Member removed: %s from wing %d by %s", 
                        data.memberName, 
                        data.wingId,
                        Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                    ))
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to remove member!", "error")
                end
            end)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:getWingGradesForLeader', function(wingId, citizenid, memberName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    local leaderCitizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(leaderCitizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        local isLeader = (wingInfo.rank == "Leader" or wingInfo.rank == "Creator" or wingInfo.rank == "Creator & Leader")
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required.", "error")
            return
        end
        
        Database.GetWingGrades(wingId, function(grades)
            TriggerClientEvent('alpha-wings:client:receiveWingGradesForLeader', src, grades or {}, wingId, citizenid, memberName)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:assignMemberGradeAsLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or not data.citizenid or not data.gradeLevel then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local leaderCitizenid = Player.PlayerData.citizenid
    Database.GetPlayerWingInfo(leaderCitizenid, function(wingInfo)
        if not wingInfo or wingInfo.id ~= tonumber(data.wingId) then
            TriggerClientEvent('QBCore:Notify', src, "You are not a member of this wing!", "error")
            return
        end
        
        local isLeader = (wingInfo.rank == "Leader" or wingInfo.rank == "Creator" or wingInfo.rank == "Creator & Leader")
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required.", "error")
            return
        end
        
        Database.UpdateMemberGrade(data.wingId, data.citizenid, data.gradeLevel, function(success)
            if success then
                Database.GetWingGrades(data.wingId, function(grades)
                    local gradeName = "Unknown"
                    for _, grade in pairs(grades) do
                        if grade.grade_level == data.gradeLevel then
                            gradeName = grade.grade_name
                            break
                        end
                    end
                    
                    local description = string.format("Wing grade changed to Level %d: %s by %s", data.gradeLevel, gradeName, Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)
                    Database.LogActivity(data.wingId, data.citizenid, 'grade_assigned', description, 0)
                    
                    TriggerClientEvent('QBCore:Notify', src, string.format("%s's wing grade updated to Level %d: %s!", data.memberName, data.gradeLevel, gradeName), "success")
                    
                    print(string.format("^3[Alpha Wings]^7 Member grade updated: %s to Level %d: %s in wing %d by %s", 
                        data.memberName, 
                        data.gradeLevel,
                        gradeName,
                        data.wingId,
                        Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                    ))
                end)
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update member grade!", "error")
            end
        end)
    end)
end)

RegisterCommand('wings_init_grades', function(source, args, rawCommand)
    if source ~= 0 then
        print("^1[Alpha Wings]^7 This command can only be run from the server console!")
        return
    end
    
    print("^3[Alpha Wings]^7 Initializing grades for all wings...")
    
    Database.GetAllWings(function(wings)
        if wings then
            local processed = 0
            local total = #wings
            
            for _, wing in pairs(wings) do
                Database.InitializeDefaultWingGrades(wing.id, function(success)
                    processed = processed + 1
                    if success then
                        print(string.format("^2[Alpha Wings]^7 Grades initialized for wing: %s", wing.name))
                    else
                        print(string.format("^1[Alpha Wings]^7 Failed to initialize grades for wing: %s", wing.name))
                    end
                    
                    if processed == total then
                        print(string.format("^2[Alpha Wings]^7 Grade initialization complete! Processed %d wings.", total))
                    end
                end)
            end
        else
            print("^1[Alpha Wings]^7 No wings found in database!")
        end
    end)
end, true)

RegisterNetEvent('alpha-wings:server:getAllWingsForChief', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    Database.GetAllWings(function(wings)
        TriggerClientEvent('alpha-wings:client:receiveAllWingsForChiefRadio', src, wings or {})
        TriggerClientEvent('alpha-wings:client:receiveAllWingsForChiefAnnouncement', src, wings or {})
    end)
end)

RegisterNetEvent('alpha-wings:server:chiefSetWingRadio', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    if not data or not data.wingId or not data.radioFrequency then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    Database.SetWingRadio(wingId, data.radioFrequency, function(success)
        if success then
            Database.LogActivity(wingId, Player.PlayerData.citizenid, 'radio_set', 'Radio frequency set to: ' .. data.radioFrequency, 0)
            
            TriggerClientEvent('QBCore:Notify', src, string.format("Radio frequency for %s set to %s!", data.wingName, data.radioFrequency), "success")
            
            print(string.format("^2[Alpha Wings]^7 Radio frequency set for wing %s (%d) to %s by Chief %s", 
                data.wingName, 
                wingId, 
                data.radioFrequency,
                Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            ))
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to set radio frequency!", "error")
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:chiefSendWingAnnouncement', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    if not data or not data.wingId or not data.message then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end
    
    Database.StoreAnnouncement(wingId, Player.PlayerData.citizenid, data.message, function(success)
        if success then
            Database.GetWingMembers(wingId, function(members)
                if members then
                    local senderName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                    
                    for _, member in pairs(members) do
                        local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.citizenid)
                        if MemberPlayer then
                            TriggerClientEvent('alpha-wings:client:receiveWingAnnouncement', MemberPlayer.PlayerData.source, {
                                wingName = data.wingName,
                                senderName = senderName .. " (Chief)",
                                message = data.message
                            })
                        end
                    end
                    
                    Database.LogActivity(wingId, Player.PlayerData.citizenid, 'chief_announcement', 'Chief announcement: ' .. data.message, 0)
                    
                    TriggerClientEvent('QBCore:Notify', src, string.format("Announcement sent to %s!", data.wingName), "success")
                    
                    print(string.format("^2[Alpha Wings]^7 Chief announcement sent by %s to wing %s: %s", 
                        senderName, data.wingName, data.message
                    ))
                else
                    TriggerClientEvent('QBCore:Notify', src, "Failed to get wing members!", "error")
                end
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to store announcement!", "error")
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:chiefSendAllWingsAnnouncement', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    if not data or not data.message then
        TriggerClientEvent('QBCore:Notify', src, "Message is required!", "error")
        return
    end
    
    Database.GetAllWings(function(wings)
        if wings and #wings > 0 then
            local senderName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            local totalSent = 0
            
            for _, wing in pairs(wings) do
                Database.StoreAnnouncement(wing.id, Player.PlayerData.citizenid, data.message, function(success)
                    if success then
                        Database.GetWingMembers(wing.id, function(members)
                            if members then
                                for _, member in pairs(members) do
                                    local MemberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.citizenid)
                                    if MemberPlayer then
                                        TriggerClientEvent('alpha-wings:client:receiveWingAnnouncement', MemberPlayer.PlayerData.source, {
                                            wingName = wing.name,
                                            senderName = senderName .. " (Chief)",
                                            message = data.message
                                        })
                                    end
                                end
                                
                                totalSent = totalSent + 1
                                
                                Database.LogActivity(wing.id, Player.PlayerData.citizenid, 'chief_announcement_all', 'Chief announcement to all wings: ' .. data.message, 0)
                            end
                        end)
                    end
                end)
            end
            
            TriggerClientEvent('QBCore:Notify', src, string.format("Announcement sent to all %d wings!", #wings), "success")
            
            print(string.format("^2[Alpha Wings]^7 Chief announcement sent by %s to all wings: %s", 
                senderName, data.message
            ))
        else
            TriggerClientEvent('QBCore:Notify', src, "No wings found!", "error")
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:getChiefStatistics', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police Chief authorization required.", "error")
        return
    end
    
    Database.GetAllWings(function(wings)
        if wings then
            local totalWings = #wings
            local totalMembers = 0
            local activeWings = 0
            local wingDetails = {}
            
            for _, wing in pairs(wings) do
                totalMembers = totalMembers + (wing.current_members or 0)
                if (wing.current_members or 0) > 0 then
                    activeWings = activeWings + 1
                end
                
                table.insert(wingDetails, {
                    name = wing.name,
                    current_members = wing.current_members or 0,
                    max_members = wing.max_members or 0,
                    leader_name = wing.leader_name or "Unknown",
                    created_at = wing.created_at or "Unknown"
                })
            end
            
            local stats = {
                totalWings = totalWings,
                totalMembers = totalMembers,
                activeWings = activeWings,
                wingDetails = wingDetails
            }
            
            TriggerClientEvent('alpha-wings:client:receiveChiefStatistics', src, stats)
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to load statistics!", "error")
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:getPlayerAnnouncements', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    Database.GetPlayerWingInfo(citizenid, function(wingInfo)
        if wingInfo then
            Database.GetWingAnnouncements(wingInfo.id, function(announcements)
                TriggerClientEvent('alpha-wings:client:receivePlayerAnnouncements', src, announcements or {})
            end)
        else
            TriggerClientEvent('alpha-wings:client:receivePlayerAnnouncements', src, {})
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:getWingMemberInfo', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    Database.GetWingMemberWithPermissions(citizenid, function(memberInfo)
        TriggerClientEvent('alpha-wings:client:receiveWingMemberInfo', src, memberInfo)
    end)
end)

RegisterNetEvent('alpha-wings:server:getPoliceOfficersForWing', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end

        Database.GetAllPoliceOfficers(function(officers)
            TriggerClientEvent('alpha-wings:client:receivePoliceOfficersForWing', src, officers or {}, wingId)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:addMemberToWingByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or not data.citizenid or not data.playerName then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local leaderCitizenid = Player.PlayerData.citizenid
    
    CheckWingLeadership(leaderCitizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end
        
        Database.AddMemberToWingByLeader(data.wingId, data.citizenid, data.playerName, data.gradeLevel or 0, function(success, message)
            if success then
                Database.LogActivity(data.wingId, data.citizenid, 'member_added_by_leader', 'Added to wing by ' .. Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, 0)
                
                TriggerClientEvent('QBCore:Notify', src, string.format("%s added to wing successfully!", data.playerName), "success")
                
                print(string.format("^2[Alpha Wings]^7 Member %s added to wing %d by leader %s", 
                    data.playerName, 
                    data.wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, message or "Failed to add member!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateWingByLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or not data.updateData then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    Database.HasWingPermission(citizenid, data.wingId, 'manage_wing', function(hasPermission, memberInfo)
        if not hasPermission then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing management permission required.", "error")
            return
        end
        
        Database.UpdateWingByLeader(data.wingId, data.updateData, function(success, message)
            if success then
                local description = "Wing settings updated by " .. Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                Database.LogActivity(data.wingId, citizenid, 'wing_updated_by_leader', description, 0)
                
                TriggerClientEvent('QBCore:Notify', src, "Wing settings updated successfully!", "success")
                
                print(string.format("^2[Alpha Wings]^7 Wing %d settings updated by leader %s", 
                    data.wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, message or "Failed to update wing settings!", "error")
            end
        end)
    end)
end)



RegisterNetEvent('alpha-wings:server:promoteToLeadership', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or not data.citizenid or not data.newRank then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local leaderCitizenid = Player.PlayerData.citizenid
    
    Database.IsWingLeader(leaderCitizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required.", "error")
            return
        end
        
        if memberInfo.wing_grade_level < 5 then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Only grade 5+ members can promote to leadership.", "error")
            return
        end
        
        local gradeLevel = 5 
        Database.PromoteToLeadership(data.wingId, data.citizenid, gradeLevel, function(success, message)
            if success then
                local description = string.format("Promoted to leadership (grade level %d) by %s", gradeLevel, Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)
                Database.LogActivity(data.wingId, data.citizenid, 'promoted_to_leadership', description, 0)

                TriggerClientEvent('QBCore:Notify', src, string.format("%s promoted to leadership (grade level %d)!", data.memberName, gradeLevel), "success")

                print(string.format("^2[Alpha Wings]^7 Member %s promoted to leadership (grade level %d) in wing %d by %s",
                    data.memberName,
                    gradeLevel,
                    data.wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, message or "Failed to promote member!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:checkWingLeadershipForMenu', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        return
    end

    if IsPlayerPoliceChief(Player) then
        TriggerClientEvent('alpha-wings:client:receiveWingLeadershipCheck', src, false, nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    Database.GetWingMemberWithPermissions(citizenid, function(memberInfo)
        if memberInfo then
            local isLeader = (memberInfo.wing_grade_level >= 5) or
                           (memberInfo.parsed_permissions and (memberInfo.parsed_permissions.manage_wing or memberInfo.parsed_permissions.leadership))

            if memberInfo.wing_grade_level >= 5 then
                memberInfo.parsed_permissions = memberInfo.parsed_permissions or {}
                memberInfo.parsed_permissions.manage_members = true
                memberInfo.parsed_permissions.manage_wing = true
                memberInfo.parsed_permissions.send_announcements = true
                memberInfo.parsed_permissions.view_management = true
                memberInfo.parsed_permissions.leadership = true
                memberInfo.parsed_permissions.view_all_members = true
            end

            TriggerClientEvent('alpha-wings:client:receiveWingLeadershipCheck', src, isLeader, memberInfo)
        else
            TriggerClientEvent('alpha-wings:client:receiveWingLeadershipCheck', src, false, nil)
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:checkManageWingsAccess', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceChief(Player) then
        TriggerClientEvent('alpha-wings:client:receiveManageWingsAccess', src, false)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    Database.IsWingCreator(citizenid, function(isCreator)
        TriggerClientEvent('alpha-wings:client:receiveManageWingsAccess', src, true)
    end)
end)

RegisterNetEvent('alpha-wings:server:getWingLeadershipOptions', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if IsPlayerPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Police Chiefs cannot access wing leadership options. Wing leadership is separate from police rank.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    Database.GetWingMemberWithPermissions(citizenid, function(memberInfo)
        if memberInfo then
            local isLeader = (memberInfo.wing_grade_level >= 5) or
                           (memberInfo.parsed_permissions and (memberInfo.parsed_permissions.manage_wing or memberInfo.parsed_permissions.leadership))

            if isLeader then

                if memberInfo.wing_grade_level >= 5 then
                    memberInfo.parsed_permissions = memberInfo.parsed_permissions or {}
                    memberInfo.parsed_permissions.manage_members = true
                    memberInfo.parsed_permissions.manage_wing = true
                    memberInfo.parsed_permissions.send_announcements = true
                    memberInfo.parsed_permissions.view_management = true
                    memberInfo.parsed_permissions.leadership = true
                    memberInfo.parsed_permissions.view_all_members = true
                end

                TriggerClientEvent('alpha-wings:client:receiveWingLeadershipOptions', src, memberInfo)
            else
                return
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "You are not in any wing!", "error")
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:getWingGradePermissions', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if IsPlayerPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Police Chiefs cannot manage wing permissions. Wing leadership is separate from police rank.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid


    Database.IsWingLeader(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end

        Database.GetWingGradesForPermissionManagement(wingId, function(grades)
            TriggerClientEvent('alpha-wings:client:receiveWingGradePermissions', src, grades, wingId)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:updateWingGradePermissions', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end
    
    if not data or not data.wingId or not data.gradeLevel or not data.permissions then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    Database.IsWingLeader(citizenid, data.wingId, function(isLeader, memberInfo)
        if not isLeader then
            TriggerClientEvent('QBCore:Notify', src, "Access denied. Wing leadership required.", "error")
            return
        end
        
        Database.UpdateWingGradePermissions(data.wingId, data.gradeLevel, data.permissions, function(success)
            if success then
                local description = string.format("Grade permissions updated for level %d by %s", data.gradeLevel, Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)
                Database.LogActivity(data.wingId, citizenid, 'grade_permissions_updated', description, 0)
                
                TriggerClientEvent('QBCore:Notify', src, "Grade permissions updated successfully!", "success")
                
                print(string.format("^2[Alpha Wings]^7 Grade permissions updated for wing %d level %d by %s", 
                    data.wingId,
                    data.gradeLevel,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to update grade permissions!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:checkWingGradeStatus', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    Database.GetWingMemberWithPermissions(citizenid, function(memberInfo)
        if memberInfo then
            local gradeLevel = memberInfo.wing_grade_level or 0
            local isLeader = (gradeLevel >= 5)
            local permissions = memberInfo.parsed_permissions or {}

            local message = string.format(
                "Wing Grade Status: Wing: %s | Grade Level: %d (%s) | Is Leader: %s | Manage Members: %s | Manage Wing: %s | Leadership: %s",
                memberInfo.wing_name or "Unknown",
                gradeLevel,
                memberInfo.grade_name or "No Grade",
                isLeader and "YES" or "NO",
                permissions.manage_members and "YES" or "NO",
                permissions.manage_wing and "YES" or "NO",
                permissions.leadership and "YES" or "NO"
            )

            TriggerClientEvent('QBCore:Notify', src, message, "info")

            Database.IsWingLeader(citizenid, memberInfo.wing_id, function(isLeaderDB, memberInfoDB)
                local dbMessage = string.format(
                    "Database Leadership Check: IsWingLeader: %s | DB Grade Level: %d",
                    isLeaderDB and "YES" or "NO",
                    memberInfoDB and memberInfoDB.wing_grade_level or 0
                )

                TriggerClientEvent('QBCore:Notify', src, dbMessage, "info")
            end)
        else
            TriggerClientEvent('QBCore:Notify', src, "You are not in any wing!", "error")
        end
    end)
end)

RegisterNetEvent('alpha-wings:server:getWingMembersForLeader', function(wingId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if IsPlayerPoliceChief(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Police Chiefs cannot manage wing members. Wing leadership is separate from police rank.", "error")
        return
    end

    if not wingId or not tonumber(wingId) then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    CheckWingLeadership(citizenid, tonumber(wingId), function(isLeader, memberInfo)
        if not isLeader then
            return
        end
        Database.GetWingMembersWithGrades(wingId, function(members)
            Database.GetWingById(wingId, function(wingData)
                local wingName = wingData and wingData[1] and wingData[1].name or "Unknown Wing"
                TriggerClientEvent('alpha-wings:client:receiveWingMembersForLeader', src, members or {}, wingId, wingName)
            end)
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:removeMemberAsLeader', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, "Access denied. Police personnel only.", "error")
        return
    end

    if not data or not data.wingId or not data.citizenid then
        TriggerClientEvent('QBCore:Notify', src, "Invalid data provided!", "error")
        return
    end

    local wingId = tonumber(data.wingId)
    if not wingId then
        TriggerClientEvent('QBCore:Notify', src, "Invalid wing ID!", "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid

    CheckWingLeadership(citizenid, wingId, function(isLeader, memberInfo)
        if not isLeader then
            return
        end

        Database.RemoveWingMember(wingId, data.citizenid, function(success)
            if success then
                Database.LogActivity(wingId, citizenid, 'member_removed', 'Member removed by leader: ' .. (data.memberName or data.citizenid), 0)

                TriggerClientEvent('QBCore:Notify', src, "Member removed successfully!", "success")

                local RemovedPlayer = QBCore.Functions.GetPlayerByCitizenId(data.citizenid)
                if RemovedPlayer then
                    TriggerClientEvent('QBCore:Notify', RemovedPlayer.PlayerData.source, "You have been removed from your wing by a wing leader.", "info")
                end

                print(string.format("^3[Alpha Wings]^7 Member %s removed from wing %d by leader %s",
                    data.citizenid,
                    wingId,
                    Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
                ))
            else
                TriggerClientEvent('QBCore:Notify', src, "Failed to remove member!", "error")
            end
        end)
    end)
end)

RegisterNetEvent('alpha-wings:server:checkAirShipWingAccess', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    if not Config.AirShipNPC.enabled then
        return
    end

    if not IsPoliceOfficer(Player) then
        TriggerClientEvent('QBCore:Notify', src, Config.AirShipNPC.messages.policeOnly, "error")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local requiredWingName = Config.AirShipNPC.requiredWingName

    Database.GetPlayerAllWingMemberships(citizenid, function(wingMemberships)
        if not wingMemberships or #wingMemberships == 0 then
            TriggerClientEvent('QBCore:Notify', src, Config.AirShipNPC.messages.accessDenied, "error")
            return
        end

        local isRequiredWingMember = false
        for _, membership in pairs(wingMemberships) do
            if membership.name == requiredWingName then
                isRequiredWingMember = true
                break
            end
        end

        if not isRequiredWingMember then
            TriggerClientEvent('QBCore:Notify', src, Config.AirShipNPC.messages.accessDenied, "error")
            return
        end

        TriggerClientEvent('QBCore:Notify', src, Config.AirShipNPC.messages.welcome, "success")
        TriggerClientEvent('alpha-wings:client:openAirShipMenu', src)


        print(string.format("^2[Alpha Wings]^7 %s wing member %s (%s) accessed helicopter service",
            requiredWingName,
            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            citizenid
        ))
    end)
end)

print("^2[Alpha Wings]^7 Server events loaded successfully!")