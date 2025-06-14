local QBCore = exports['qb-core']:GetCoreObject()
local bankingModule = exports['qb-banking'] 

local RenewedBanking = nil
if Config.BankingSystem == "renewed-banking" then
    RenewedBanking = exports['Renewed-Banking']
end

-- In-memory storage
local JobData = {}
local PlayerSettings = {}
local RefreshTimers = {}
local JobPermissionsCache = {}
local ActivityData = {}
local PlayerJoinTimes = {}
local PlaytimeCache = {} -- Initialize the cache table

-- Debug function
local function DebugPrint(msg)
    if Config.Debug then
        print("^3[alpha-bossmenu Debug]^7 " .. msg)
    end
end

-- Save playtime to database
function SavePlaytime(citizenid, jobName, sessionTime)
    if not citizenid or not jobName or not sessionTime or sessionTime <= 0 then
        return
    end

    MySQL.Async.execute('INSERT INTO job_playtime (citizenid, job, total_minutes) VALUES (@citizenid, @job, @total_minutes) ON DUPLICATE KEY UPDATE total_minutes = total_minutes + @total_minutes', {
        ['@citizenid'] = citizenid,
        ['@job'] = jobName,
        ['@total_minutes'] = sessionTime
    }, function(affectedRows)
        if affectedRows > 0 then
            -- Update cache
            local cacheKey = citizenid .. "_" .. jobName
            if PlaytimeCache[cacheKey] then
                PlaytimeCache[cacheKey] = PlaytimeCache[cacheKey] + sessionTime
            else
                PlaytimeCache[cacheKey] = sessionTime
            end
        end
    end)
end

RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    local citizenid = Player.PlayerData.citizenid
    local jobName = Player.PlayerData.job.name

    PlayerJoinTimes[citizenid] = {
        time = os.time(),
        job = jobName
    }
end)

-- Clean up when player disconnects
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    -- Clear refresh timer
    if RefreshTimers[src] then
        ClearTimeout(RefreshTimers[src])
        RefreshTimers[src] = nil
    end

    -- Clear player settings
    if PlayerSettings[src] then
        PlayerSettings[src] = nil
    end

    -- Clear permissions cache for this player
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local citizenid = Player.PlayerData.citizenid
        local jobName = Player.PlayerData.job.name

        -- Save playtime before clearing
        if PlayerJoinTimes[citizenid] then
            local sessionTime = math.floor((os.time() - PlayerJoinTimes[citizenid].time) / 60)
            if sessionTime > 0 then
                SavePlaytime(citizenid, jobName, sessionTime)
            end
            PlayerJoinTimes[citizenid] = nil
        end

        -- Clear job permissions cache
        if JobPermissionsCache[jobName] and JobPermissionsCache[jobName][citizenid] then
            JobPermissionsCache[jobName][citizenid] = nil
        end
    end
end)


function GetCachedPlaytime(citizenid, jobName)
    local cacheKey = citizenid .. "_" .. jobName

    if PlaytimeCache[cacheKey] then
        return PlaytimeCache[cacheKey]
    end

    local dbPlaytime = MySQL.Sync.fetchScalar('SELECT total_minutes FROM job_playtime WHERE citizenid = ? AND job = ?',
        {citizenid, jobName})

    if dbPlaytime then
        PlaytimeCache[cacheKey] = dbPlaytime
    end

    return dbPlaytime or 0
end


-- Initialize activity tracking
function InitializeActivityTracking()
    -- Reset activity data for all jobs
    for jobName, _ in pairs(QBCore.Shared.Jobs) do
        ActivityData[jobName] = {}
        for i = 0, 23 do
            ActivityData[jobName][i] = 0
        end
    end
    
    -- Start hourly tracking
    CreateThread(function()
        while true do
            local currentHour = tonumber(os.date('%H'))
            local players = QBCore.Functions.GetQBPlayers()
            
            -- Reset current hour values
            for jobName, _ in pairs(QBCore.Shared.Jobs) do
                ActivityData[jobName][currentHour] = 0
            end
            
            for _, player in pairs(players) do
                local jobName = player.PlayerData.job.name
                if ActivityData[jobName] then
                    ActivityData[jobName][currentHour] = (ActivityData[jobName][currentHour] or 0) + 1
                end
            end
            
            Wait(60000) -- Check every minute
        end
    end)
end

-- Get job data
QBCore.Functions.CreateCallback('alpha-bossmenu:server:GetJobData', function(source, cb, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.name ~= jobName then
        cb(false)
        return
    end
    
    -- Check permissions - either boss or has specific permissions
    local hasBossAccess = Player.PlayerData.job.isboss
    local permissions = nil

    if not hasBossAccess then
        -- Check minimum rank requirement first
        local minimumRank = Config.MinimumRank[jobName] or 0
        local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0

        if playerGrade < minimumRank then
            cb(false)
            return
        end
    end

    -- Get job label
    local jobLabel = QBCore.Shared.Jobs[jobName].label or jobName
    local jobGrades = QBCore.Shared.Jobs[jobName].grades or {}
    
    -- Get all players with this job
    local players = QBCore.Functions.GetQBPlayers()
    local employeeData = {}
    local onlineCount = 0
    local weeklyPlaytime = 0
    local averagePlaytime = 0

    -- Process each player
    for _, player in pairs(players) do
        if player.PlayerData.job.name == jobName then
            local isOnline = true
            onlineCount = onlineCount + 1
            
            -- Calculate playtime
            local playTime = 0
            if PlayerJoinTimes[player.PlayerData.citizenid] then
                playTime = math.floor((os.time() - PlayerJoinTimes[player.PlayerData.citizenid].time) / 60)
            else
                PlayerJoinTimes[player.PlayerData.citizenid] = {
                    time = os.time(),
                    job = jobName
                }
            end
            
            weeklyPlaytime = weeklyPlaytime + playTime

            -- Get employee grade name
            local gradeName = "Unknown"
            if jobGrades[tostring(player.PlayerData.job.grade.level)] then
                gradeName = jobGrades[tostring(player.PlayerData.job.grade.level)].name
            end

            table.insert(employeeData, {
                citizenid = player.PlayerData.citizenid,
                name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                grade = player.PlayerData.job.grade.level,
                gradeName = gradeName,
                playTime = playTime,
                isOnline = isOnline,
                isManagement = player.PlayerData.job.isboss
            })
        end
    end

    -- Calculate average playtime
    if #employeeData > 0 then
        averagePlaytime = weeklyPlaytime / #employeeData
    end

    -- Get permissions for non-boss players
    if not hasBossAccess then
        permissions = JobPermissionsCache[jobName] and JobPermissionsCache[jobName][Player.PlayerData.citizenid] or {}
    end

    -- Create activity data
    local activityData = {}
    for i = 0, 23 do
        activityData[i] = ActivityData[jobName] and ActivityData[jobName][i] or 0
    end

    local jobData = {
        jobName = jobName,
        jobLabel = jobLabel,
        employees = employeeData,
        onlineCount = onlineCount,
        totalEmployees = #employeeData,
        activityData = activityData,
        grades = jobGrades,
        weeklyPlaytime = weeklyPlaytime,
        averagePlaytime = averagePlaytime,
        permissions = permissions
    }
    
    -- Save refresh data for player
    if not RefreshTimers[src] then
        StartRefreshTimer(src, jobName)
    end

    -- Get society data
    local societyData = GetSocietyData(jobName)
    jobData.societyData = societyData
    
    cb(jobData)
end)

-- Create automatic refresh timer for player
function StartRefreshTimer(src, jobName)
    -- Clear existing timer if any
    if RefreshTimers[src] then
        ClearTimeout(RefreshTimers[src])
        RefreshTimers[src] = nil
    end

    -- Create new timer with minimum interval
    local interval = math.max((PlayerSettings[src] and PlayerSettings[src].refreshInterval or 60), 30) * 1000

    RefreshTimers[src] = SetTimeout(interval, function()
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.job.name == jobName then
            -- Check if player still has access
            local hasAccess = Player.PlayerData.job.isboss
            if not hasAccess then
                local minimumRank = Config.MinimumRank[jobName] or 0
                local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0
                hasAccess = playerGrade >= minimumRank
            end

            if hasAccess then
                -- Send auto-refresh event to client
                TriggerClientEvent('alpha-bossmenu:client:RefreshData', src)

                -- Restart timer
                StartRefreshTimer(src, jobName)
            else
                -- Player lost access, clear timer
                RefreshTimers[src] = nil
            end
        else
            -- If player disconnected or changed jobs, clear timer
            RefreshTimers[src] = nil
        end
    end)
end

-- Get user settings
QBCore.Functions.CreateCallback('alpha-bossmenu:server:GetSettings', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        cb(Config.DefaultSettings)
        return
    end
    
    -- Get settings from memory
    if PlayerSettings[src] then
        cb(PlayerSettings[src])
    else
        -- Use default settings
        PlayerSettings[src] = Config.DefaultSettings
        cb(Config.DefaultSettings)
    end
end)

-- Save settings
RegisterNetEvent('alpha-bossmenu:server:SaveSettings', function(settings)
    local src = source
    PlayerSettings[src] = settings
end)

-- Update employee
RegisterNetEvent('alpha-bossmenu:server:UpdateEmployee', function(citizenid, jobName, grade)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.name ~= jobName then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this action", "error")
        return
    end

    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if Target then
        Target.Functions.SetJob(jobName, grade)
        TriggerClientEvent('QBCore:Notify', src, "Employee updated successfully", "success")
    else
        TriggerClientEvent('QBCore:Notify', src, "Employee not found", "error")
    end
end)

-- Remove employee
RegisterNetEvent('alpha-bossmenu:server:RemoveEmployee', function(citizenid, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.name ~= jobName then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this action", "error")
        return
    end

    -- Check if player has boss permissions or minimum rank + hiring permission
    local hasPermission = Player.PlayerData.job.isboss

    if not hasPermission then
        -- Check minimum rank requirement
        local minimumRank = Config.MinimumRank[jobName] or 0
        local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0

        if playerGrade < minimumRank then
            TriggerClientEvent('QBCore:Notify', src, "You don't have sufficient rank for this action", "error")
            return
        end
    end

    -- Get target player
    local Target = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if Target then
        -- Remove job and set to unemployed
        Target.Functions.SetJob("unemployed", 0)
        
        -- Notify both players
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, "You have been fired from your job", "error")
        TriggerClientEvent('QBCore:Notify', src, "Employee removed successfully", "success")

        -- Close boss menu for fired player if they have it open
        TriggerClientEvent('alpha-bossmenu:client:ForceCloseUI', Target.PlayerData.source)

        -- Remove from permissions cache if exists
        if JobPermissionsCache[jobName] and JobPermissionsCache[jobName][citizenid] then
            JobPermissionsCache[jobName][citizenid] = nil
        end

        -- Remove from activity tracking
        if ActivityData[jobName] then
            ActivityData[jobName][citizenid] = nil
        end

        -- Remove from join times tracking
        if PlayerJoinTimes[citizenid] then
            PlayerJoinTimes[citizenid] = nil
        end

        -- Refresh all boss menus for this job
        TriggerClientEvent('alpha-bossmenu:client:RefreshData', -1)
    else
        TriggerClientEvent('QBCore:Notify', src, "Employee not found", "error")
    end
end)

-- Update permissions
RegisterNetEvent('alpha-bossmenu:server:UpdatePermissions', function(citizenid, jobName, permissions)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.name ~= jobName then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this action", "error")
        return
    end

    -- Store permissions in memory
    if not JobPermissionsCache[jobName] then
        JobPermissionsCache[jobName] = {}
    end
    JobPermissionsCache[jobName][citizenid] = permissions

    TriggerClientEvent('QBCore:Notify', src, "Permissions updated successfully", "success")
end)

-- Get society data
function GetSocietyData(jobName)
    local society = "society_" .. jobName
    local account = exports['qb-management']:GetAccount(society)
    
    if account then
        return {
            balance = account.balance,
            name = society,
            transactions = account.transactions or {}
        }
    end
    
    return {
        balance = 0,
        name = society,
        transactions = {}
    }
end

-- Clean up when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    if RefreshTimers[src] then
        ClearTimeout(RefreshTimers[src])
        RefreshTimers[src] = nil
    end
    PlayerSettings[src] = nil
end)

-- Update activity data periodically
CreateThread(function()
    while true do
        Wait(60000) -- Update every minute
        local players = QBCore.Functions.GetQBPlayers()
        
        for _, player in pairs(players) do
            local jobName = player.PlayerData.job.name
            if jobName then
                if not ActivityData[jobName] then
                    ActivityData[jobName] = {}
                end
                
                local hour = tonumber(os.date("%H"))
                ActivityData[jobName][hour] = (ActivityData[jobName][hour] or 0) + 1
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end    
    for citizenid, _ in pairs(PlayerJoinTimes) do
        UpdatePlayerPlaytime(citizenid)
    end
end)

-- Clear timers when player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        UpdatePlayerPlaytime(Player.PlayerData.citizenid)
    end
end)

function UpdatePlayerPlaytime(citizenid)
    local joinData = PlayerJoinTimes[citizenid]
    if not joinData then return end
    
    local currentTime = os.time()
    local sessionTime = currentTime - joinData.time
    local sessionMinutes = math.floor(sessionTime / 60)
    
    if sessionMinutes <= 0 then return end
    
    local jobName = joinData.job  
    
    if PlaytimeCache then  
        local cacheKey = citizenid .. "-" .. jobName
        if PlaytimeCache[cacheKey] then
            PlaytimeCache[cacheKey] = PlaytimeCache[cacheKey] + sessionMinutes
        else
            PlaytimeCache[cacheKey] = sessionMinutes
        end
    end
    
    MySQL.Async.execute('INSERT INTO job_playtime (citizenid, job, total_minutes) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE total_minutes = total_minutes + ?', 
        {citizenid, jobName, sessionMinutes, sessionMinutes}, 
        function(rowsChanged)
            if PlayerJoinTimes[citizenid] then
                PlayerJoinTimes[citizenid].time = currentTime
            end
        end
    )
end


RegisterNetEvent('QBCore:Server:OnJobUpdate', function(source, newJob)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        UpdatePlayerPlaytime(Player.PlayerData.citizenid)
        
        -- Start tracking for new job (existing code)
        PlayerJoinTimes[Player.PlayerData.citizenid] = {
            time = os.time(),
            job = newJob.name
        }
        
        -- NEW: Notify all boss menu clients to refresh their data for this job
        TriggerClientEvent('alpha-bossmenu:client:JobChanged', -1, newJob.name)
    end
end)

-- Add chat command for quick management (optional)
QBCore.Commands.Add('managejob', 'Open job management interface', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local jobName = Player.PlayerData.job.name
    
    -- Check if player has management permissions
    if not Player.PlayerData.job.isboss then
        TriggerClientEvent('QBCore:Notify', source, "You don't have permission to manage this job", "error")
        return
    end
    
    TriggerClientEvent('alpha-bossmenu:client:TriggerOpenManager', source, {jobData = jobName})
end)

RegisterNetEvent('alpha-bossmenu:server:RefreshPlayTime', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if Player.PlayerData.job.isboss then
        TriggerClientEvent('alpha-bossmenu:client:RefreshData', src)
    end
end)

function LoadSocietyTransactions()
    local result = MySQL.Sync.fetchAll('SELECT * FROM society_transactions ORDER BY timestamp DESC LIMIT 1000')
    
    if result and #result > 0 then
        SocietyTransactions = {}
        
        for _, transaction in ipairs(result) do
            local societyName = transaction.society
            
            if not SocietyTransactions[societyName] then
                SocietyTransactions[societyName] = {}
            end
            
            table.insert(SocietyTransactions[societyName], {
                type = transaction.type,
                amount = transaction.amount,
                employee = transaction.employee,
                executor = transaction.executor,
                note = transaction.note,
                timestamp = transaction.timestamp
            })
        end
        
        for societyName, transactions in pairs(SocietyTransactions) do
            table.sort(transactions, function(a, b)
                return a.timestamp > b.timestamp
            end)
            
            if #transactions > 50 then
                local newTransactions = {}
                for i = 1, 50 do
                    newTransactions[i] = transactions[i]
                end
                SocietyTransactions[societyName] = newTransactions
            end
        end
    else
        print("^2[alpha-bossmenu]^7 No society transactions found in database")
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(1000) 
    InitializeActivityTracking()
    LoadSocietyTransactions()
    TriggerEvent('QBCore:server:UpdateObject')
    if resource == GetCurrentResourceName() then
        if Config.BankingSystem == "qb-banking" then
            TriggerEvent('qb-banking:server:RefreshAccounts')
        elseif Config.BankingSystem == "renewed-banking" then
            RenewedBanking = exports['Renewed-Banking']
        end
    end
end)

function GetSocietyData(jobName)
    if not jobName then return nil end
    
    local societyName = jobName
    local result = nil
    local balance = 0
    
    if Config.BankingSystem == "dw-banking" then
        result = MySQL.Sync.fetchSingle('SELECT * FROM society WHERE name = ?', {societyName})
        
        if not result then
            MySQL.Sync.execute('INSERT INTO society (name, money) VALUES (?, ?)', {societyName, 0})
            result = {name = societyName, money = 0}
        end
        
        balance = result.money
    elseif Config.BankingSystem == "qb-banking" then
        local account = bankingModule:GetAccount(societyName)
        
        if account then
            balance = account.account_balance
        else
            result = MySQL.Sync.fetchSingle('SELECT * FROM bank_accounts WHERE account_name = ?', {societyName})
            
            if not result then
                bankingModule:CreateJobAccount(societyName, 0)
                balance = 0
            else
                balance = result.account_balance
            end
        end
    elseif Config.BankingSystem == "renewed-banking" then
        balance = RenewedBanking:getAccountMoney(societyName) or 0
    end
    
    if not SocietyTransactions[societyName] then
        SocietyTransactions[societyName] = {}
        
        local transactions = MySQL.Sync.fetchAll('SELECT * FROM society_transactions WHERE society = ? ORDER BY timestamp DESC LIMIT 50', {societyName})
        if transactions and #transactions > 0 then
            for _, transaction in ipairs(transactions) do
                table.insert(SocietyTransactions[societyName], {
                    type = transaction.type,
                    amount = transaction.amount,
                    employee = transaction.employee,
                    executor = transaction.executor,
                    note = transaction.note,
                    timestamp = transaction.timestamp
                })
            end
        end
    end
    
    -- Return data in a standardized format
    return {
        name = jobName,
        balance = balance,
        transactions = SocietyTransactions[societyName] or {}
    }
end



function AddSocietyTransaction(societyName, transactionData)
    if not SocietyTransactions[societyName] then
        SocietyTransactions[societyName] = {}
    end
    
    transactionData.timestamp = os.time()
    
    table.insert(SocietyTransactions[societyName], 1, transactionData)
    
    if #SocietyTransactions[societyName] > 50 then
        table.remove(SocietyTransactions[societyName], 51)
    end
    
    MySQL.Async.execute('INSERT INTO society_transactions (society, type, amount, employee, executor, note, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        societyName, 
        transactionData.type, 
        transactionData.amount, 
        transactionData.employee or '', 
        transactionData.executor or '', 
        transactionData.note or '', 
        transactionData.timestamp
    })
end

QBCore.Functions.CreateCallback('alpha-bossmenu:server:GetSocietyData', function(source, cb, jobName)
    local src = source
    
    if not HasSocietyPermission(src, jobName) then
        cb(false)
        return
    end
    
    cb(GetSocietyData(jobName))
end)

-- Deposit money into society account
RegisterNetEvent('alpha-bossmenu:server:DepositMoney', function(amount, note, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not HasSocietyPermission(src, jobName) then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this action", "error")
        return
    end
    
    if Player.PlayerData.money.cash < amount then
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash", "error")
        return
    end
    
    Player.Functions.RemoveMoney('cash', amount)
    
    local societyName = jobName
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    if Config.BankingSystem == "dw-banking" then
        MySQL.Async.execute('UPDATE society SET money = money + ? WHERE name = ?', {amount, societyName})
    elseif Config.BankingSystem == "qb-banking" then
        local success = bankingModule:AddMoney(societyName, amount, note or "Boss Menu Deposit")
        
        if not success then
            MySQL.Async.execute('UPDATE bank_accounts SET account_balance = account_balance + ? WHERE account_name = ?', {amount, societyName})
            TriggerEvent('qb-banking:server:RefreshAccounts')
        end
    elseif Config.BankingSystem == "renewed-banking" then
        local success = RenewedBanking:addAccountMoney(societyName, amount)
        
        if success then
            local jobLabel = QBCore.Shared.Jobs[jobName].label or jobName
            RenewedBanking:handleTransaction(
                societyName,  
                "Society Deposit", 
                amount, 
                note or "Boss Menu Deposit", 
                playerName, 
                jobLabel, 
                "deposit" 
            )
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to deposit money", "error")
            Player.Functions.AddMoney('cash', amount)
            return
        end
    end
    
    AddSocietyTransaction(societyName, {
        type = 'deposit',
        amount = amount,
        employee = playerName,
        note = note
    })
    
    TriggerClientEvent('QBCore:Notify', src, "Successfully deposited " .. amount .. "$ to society account", "success")
    
    TriggerEvent('qb-log:server:CreateLog', 'society', 'Society Deposit', 'green', string.format('%s (%s) deposited %s$ to %s society', 
        GetPlayerName(src), Player.PlayerData.citizenid, amount, jobName))
end)

-- Withdraw money from society account
RegisterNetEvent('alpha-bossmenu:server:WithdrawMoney', function(amount, note, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not HasSocietyPermission(src, jobName) then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this action", "error")
        return
    end
    
    local societyName = jobName
    local currentBalance = 0
    
    -- Get current society balance based on banking system
    if Config.BankingSystem == "dw-banking" then
        local society = MySQL.Sync.fetchSingle('SELECT money FROM society WHERE name = ?', {societyName})
        if society then
            currentBalance = society.money
        end
    elseif Config.BankingSystem == "qb-banking" then
        currentBalance = bankingModule:GetAccountBalance(societyName)
        
        if currentBalance == 0 then
            local account = MySQL.Sync.fetchSingle('SELECT account_balance FROM bank_accounts WHERE account_name = ?', {societyName})
            if account then
                currentBalance = account.account_balance
            end
        end
    elseif Config.BankingSystem == "renewed-banking" then
        currentBalance = RenewedBanking:getAccountMoney(societyName) or 0
    end
    
    if currentBalance < amount then
        TriggerClientEvent('QBCore:Notify', src, "Not enough funds in society account", "error")
        return
    end
    
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Update society money based on banking system
    if Config.BankingSystem == "dw-banking" then
        MySQL.Async.execute('UPDATE society SET money = money - ? WHERE name = ?', {amount, societyName})
    elseif Config.BankingSystem == "qb-banking" then
        local success = bankingModule:RemoveMoney(societyName, amount, note or "Boss Menu Withdrawal")
        
        if not success then
            MySQL.Async.execute('UPDATE bank_accounts SET account_balance = account_balance - ? WHERE account_name = ?', {amount, societyName})
            TriggerEvent('qb-banking:server:RefreshAccounts')
        end
    elseif Config.BankingSystem == "renewed-banking" then
        local success = RenewedBanking:removeAccountMoney(societyName, amount)
        
        if success then
            local jobLabel = QBCore.Shared.Jobs[jobName].label or jobName
            RenewedBanking:handleTransaction(
                societyName,  
                "Society Withdrawal", 
                amount, 
                note or "Boss Menu Withdrawal",
                jobLabel, 
                playerName, 
                "withdraw" 
            )
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to withdraw money", "error")
            return
        end
    end
    
    Player.Functions.AddMoney('cash', amount)
    
    AddSocietyTransaction(societyName, {
        type = 'withdraw',
        amount = amount,
        employee = playerName,
        note = note
    })
    
    TriggerClientEvent('QBCore:Notify', src, "Successfully withdrawn " .. amount .. "$ from society account", "success")
    
    TriggerEvent('qb-log:server:CreateLog', 'society', 'Society Withdraw', 'red', string.format('%s (%s) withdrawn %s$ from %s society', 
        GetPlayerName(src), Player.PlayerData.citizenid, amount, jobName))
end)


-- Transfer money from society account to employee
RegisterNetEvent('alpha-bossmenu:server:TransferMoney', function(citizenid, amount, note, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not HasSocietyPermission(src, jobName) then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this action", "error")
        return
    end
    
    local societyName = jobName
    local currentBalance = 0
    
    -- Get current society balance based on banking system
    if Config.BankingSystem == "dw-banking" then
        local society = MySQL.Sync.fetchSingle('SELECT money FROM society WHERE name = ?', {societyName})
        if society then
            currentBalance = society.money
        end
    elseif Config.BankingSystem == "qb-banking" then
        currentBalance = bankingModule:GetAccountBalance(societyName)
        
        if currentBalance == 0 then
            local account = MySQL.Sync.fetchSingle('SELECT account_balance FROM bank_accounts WHERE account_name = ?', {societyName})
            if account then
                currentBalance = account.account_balance
            end
        end
    elseif Config.BankingSystem == "renewed-banking" then
        currentBalance = RenewedBanking:getAccountMoney(societyName) or 0
    end
    
    if currentBalance < amount then
        TriggerClientEvent('QBCore:Notify', src, "Not enough funds in society account", "error")
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "Employee not found or not online", "error")
        return
    end
    
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local targetName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname
    
    -- Update society money based on banking system
    if Config.BankingSystem == "dw-banking" then
        MySQL.Async.execute('UPDATE society SET money = money - ? WHERE name = ?', {amount, societyName})
    elseif Config.BankingSystem == "qb-banking" then
        local success = bankingModule:RemoveMoney(societyName, amount, note or "Boss Menu Transfer to " .. targetPlayer.PlayerData.charinfo.firstname)
        
        if not success then
            MySQL.Async.execute('UPDATE bank_accounts SET account_balance = account_balance - ? WHERE account_name = ?', {amount, societyName})
            TriggerEvent('qb-banking:server:RefreshAccounts')
        end
    elseif Config.BankingSystem == "renewed-banking" then
        local success = RenewedBanking:removeAccountMoney(societyName, amount)
        
        if success then
            local jobLabel = QBCore.Shared.Jobs[jobName].label or jobName
            RenewedBanking:handleTransaction(
                societyName,  
                "Society Transfer", 
                amount, 
                note or "Boss Menu Transfer to " .. targetName, 
                jobLabel, 
                targetName, 
                "withdraw" 
            )
            
            RenewedBanking:handleTransaction(
                targetPlayer.PlayerData.citizenid,  
                "Society Transfer", 
                amount, 
                note or "Transfer from " .. jobLabel, 
                jobLabel, 
                targetName, 
                "deposit" 
            )
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to transfer money", "error")
            return
        end
    end
    
    targetPlayer.Functions.AddMoney('bank', amount)
    
    AddSocietyTransaction(societyName, {
        type = 'transfer',
        amount = amount,
        employee = targetName,
        executor = playerName,
        note = note
    })
    
    TriggerClientEvent('QBCore:Notify', src, "Successfully transferred " .. amount .. "$ to " .. targetName, "success")
    TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "You received " .. amount .. "$ from society account", "success")
    
    TriggerEvent('qb-log:server:CreateLog', 'society', 'Society Transfer', 'yellow', string.format('%s (%s) transferred %s$ from %s society to %s (%s)', 
        GetPlayerName(src), Player.PlayerData.citizenid, amount, jobName, GetPlayerName(targetPlayer.PlayerData.source), citizenid))
end)














-- Save changes directly to the jobs.lua file
function CompletelyRebuildJobDefinition(jobName, newGrades)
    local filePath = GetResourcePath("qb-core").."/shared/jobs.lua"
    local backupPath = filePath .. ".backup"
    
    local originalFile = io.open(filePath, "r")
    if not originalFile then
        return false
    end
    
    local content = originalFile:read("*all")
    originalFile:close()
    
    local backup = io.open(backupPath, "w")
    if backup then
        backup:write(content)
        backup:close()
    end
    
    local lines = {}
    local file = io.open(filePath, "r")
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    
    local jobStartLine = nil
    local jobEndLine = nil
    local jobLabelLine = nil
    local defaultDutyLine = nil
    
    for i, line in ipairs(lines) do
        if line:match("%['" .. jobName .. "'%]%s*=%s*{") then
            jobStartLine = i
            break
        end
    end
    
    if not jobStartLine then
        return false
    end
    
    local braceLevel = 1
    for i = jobStartLine + 1, #lines do
        local line = lines[i]
        
        if not jobLabelLine and line:match("label%s*=") then
            jobLabelLine = line
        end
        
        if not defaultDutyLine and line:match("defaultDuty%s*=") then
            defaultDutyLine = line
        end
        
        local openBraces = line:gsub("[^{]", ""):len()
        local closeBraces = line:gsub("[^}]", ""):len()
        braceLevel = braceLevel + openBraces - closeBraces
        
        if braceLevel == 0 then
            jobEndLine = i
            break
        end
    end
    
    if not jobEndLine then
        return false
    end
    
    local label = jobLabelLine and jobLabelLine:match("label%s*=%s*'([^']*)'") or "Unknown"
    local defaultDuty = defaultDutyLine and defaultDutyLine:match("defaultDuty%s*=%s*(%w+)") or "true"
    
    local gradeNumbers = {}
    local sortedGrades = {}
    
    for level, grade in pairs(newGrades) do
        local numLevel = tonumber(level)
        table.insert(gradeNumbers, numLevel)
        sortedGrades[numLevel] = grade
    end
    
    table.sort(gradeNumbers)
    
    local finalGrades = {}
    local newMapping = {}
    
    for newIndex, oldNumber in ipairs(gradeNumbers) do
        local newIndex = newIndex - 1 
        local grade = sortedGrades[oldNumber]
        
        local newGrade = {
            name = grade.name,
            payment = grade.payment
        }
        
        if grade.isboss then
            newGrade.isboss = true
        end
        
        if grade.bankAuth then
            newGrade.bankAuth = true
        end
        
        finalGrades[tostring(newIndex)] = newGrade
        newMapping[oldNumber] = newIndex
        
    end
    
    local newJobDef = {
        "['" .. jobName .. "'] = {",
        "    label = '" .. label .. "',",
        "    defaultDuty = " .. defaultDuty .. ",",
        "    grades = {"
    }
    
    for i = 0, #gradeNumbers - 1 do
        local level = tostring(i)
        local grade = finalGrades[level]
        
        local gradeLine = string.format("        ['%s'] = { name = '%s'", level, grade.name:gsub("'", "\\'"))
        
        if grade.payment then
            gradeLine = gradeLine .. string.format(", payment = %d", grade.payment)
        end
        
        if grade.isboss then
            gradeLine = gradeLine .. ", isboss = true"
        end
        
        if grade.bankAuth then
            gradeLine = gradeLine .. ", bankAuth = true"
        end
        
        gradeLine = gradeLine .. " },"
        table.insert(newJobDef, gradeLine)
    end
    
    table.insert(newJobDef, "    },")
    table.insert(newJobDef, "},")
    
    local newLines = {}
    
    for i = 1, jobStartLine - 1 do
        table.insert(newLines, lines[i])
    end
    
    for _, line in ipairs(newJobDef) do
        table.insert(newLines, line)
    end
    
    for i = jobEndLine + 1, #lines do
        table.insert(newLines, lines[i])
    end
    
    local outFile = io.open(filePath, "w")
    if not outFile then
        return false
    end
    
    for _, line in ipairs(newLines) do
        outFile:write(line .. "\n")
    end
    outFile:close()
    
    QBCore.Shared.Jobs[jobName].grades = finalGrades
    
    TriggerClientEvent('QBCore:Client:OnSharedUpdate', -1, 'Jobs', jobName, 'grades', finalGrades)
    
    TriggerEvent('QBCore:server:UpdateObject')    
    return true, newMapping
end

function SaveJobGradeChangesToFile(jobName, grades)
    local success, mapping = CompletelyRebuildJobDefinition(jobName, grades)
    
    if success and mapping then
        local hasChanges = false
        for old, new in pairs(mapping) do
            if old ~= new then
                hasChanges = true
                break
            end
        end
        
        if hasChanges then
        end
    end
    
    return success
end

function GetCurrentJobGrades(jobName)
    if not QBCore.Shared.Jobs[jobName] then
        return nil
    end
    
    return QBCore.Shared.Jobs[jobName].grades
end


RegisterNetEvent('alpha-bossmenu:server:RequestRefreshJobData', function()
    TriggerEvent('QBCore:server:UpdateObject')
end)


function table.copy(t)
    local u = { }
    for k, v in pairs(t) do
        if type(v) == "table" then
            u[k] = table.copy(v)
        else
            u[k] = v
        end
    end
    return setmetatable(u, getmetatable(t))
end

-- Get employee permissions
-- Get employee permissions callback
QBCore.Functions.CreateCallback('alpha-bossmenu:server:GetEmployeePermissions', function(source, cb, citizenid, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        cb(false)
        return
    end
    
    -- Check for cached permissions first
    if JobPermissionsCache[jobName] and JobPermissionsCache[jobName][citizenid] then
        cb(JobPermissionsCache[jobName][citizenid])
        return
    end
    
    -- If not in cache, get from database
    MySQL.Async.fetchAll('SELECT permissions FROM job_employee_permissions WHERE citizenid = ? AND job = ?', 
        {citizenid, jobName}, function(result)
        if result and result[1] and result[1].permissions then
            local permissions = json.decode(result[1].permissions)
            
            -- Cache the results
            if not JobPermissionsCache[jobName] then
                JobPermissionsCache[jobName] = {}
            end
            JobPermissionsCache[jobName][citizenid] = permissions
            
            cb(permissions)
        else
            -- Return default permissions (all false)
            local defaultPermissions = {
                dashboard = false,
                employees = false,
                society = false,
                grades = false,
                hiringfiring = false
            }
            
            cb(defaultPermissions)
        end
    end)
end)


-- Load permissions on server start
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- Wait for everything to initialize
    
    -- Load all permissions into cache
    MySQL.Async.fetchAll('SELECT citizenid, job, permissions FROM job_employee_permissions', {}, function(results)
        if results and #results > 0 then
            for _, row in ipairs(results) do
                local jobName = row.job
                local citizenid = row.citizenid
                local permissions = json.decode(row.permissions)
                
                if not JobPermissionsCache[jobName] then
                    JobPermissionsCache[jobName] = {}
                end
                
                JobPermissionsCache[jobName][citizenid] = permissions
            end       
        end
    end)
end)

-- Update employee rank/grade with proper callback
QBCore.Functions.CreateCallback('alpha-bossmenu:server:UpdateEmployeeRank', function(source, cb, citizenid, jobName, grade)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.name ~= jobName then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end

    -- Check if player has boss permissions
    if not Player.PlayerData.job.isboss then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end

    -- Validate grade format
    if type(grade) == 'number' then
        grade = tostring(grade)
    end

    -- Check if grade exists for this job
    if not QBCore.Shared.Jobs[jobName] or not QBCore.Shared.Jobs[jobName].grades[grade] then
        cb({success = false, message = "Invalid job grade"})
        return
    end

    -- Check if employee exists
    MySQL.Async.fetchSingle('SELECT 1 FROM players WHERE citizenid = @citizenid', {
        ['@citizenid'] = citizenid
    }, function(result)
        if not result then
            cb({success = false, message = "Player not found"})
            return
        end

        local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if targetPlayer then
            -- Player is online - update directly
            local targetCurrentJob = targetPlayer.PlayerData.job.name

            if targetCurrentJob == jobName then
                -- Only update grade
                targetPlayer.Functions.SetJobDuty(true)
                targetPlayer.Functions.SetJob(jobName, grade)
                TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Your rank has been updated to " .. QBCore.Shared.Jobs[jobName].grades[grade].name, "success")

                -- Log entry
                TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Employee Rank Update', 'green', string.format('%s (%s) updated %s (%s) to rank %s in job %s',
                    GetPlayerName(src), Player.PlayerData.citizenid, GetPlayerName(targetPlayer.PlayerData.source), citizenid, grade, jobName))

                cb({success = true, message = "Employee rank updated successfully"})
            else
                -- Change job and grade
                targetPlayer.Functions.SetJob(jobName, grade)
                TriggerClientEvent('alpha-bossmenu:client:JobChanged', -1, jobName)
                TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Your job has been changed to " .. QBCore.Shared.Jobs[jobName].label, "success")

                -- Log entry
                TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Job Change', 'green', string.format('%s (%s) changed %s (%s) job from %s to %s at rank %s',
                    GetPlayerName(src), Player.PlayerData.citizenid, GetPlayerName(targetPlayer.PlayerData.source), citizenid, targetCurrentJob, jobName, grade))

                cb({success = true, message = "Employee successfully transferred to this job"})
            end
        else
            -- Player is offline - update database directly
            MySQL.Async.fetchSingle('SELECT job FROM players WHERE citizenid = @citizenid', {
                ['@citizenid'] = citizenid
            }, function(jobResult)
                if not jobResult or not jobResult.job then
                    cb({success = false, message = "Error retrieving employee data"})
                    return
                end

                local currentJob = json.decode(jobResult.job)
                local jobInfo = {
                    name = jobName,
                    label = QBCore.Shared.Jobs[jobName].label,
                    payment = QBCore.Shared.Jobs[jobName].grades[grade].payment,
                    onduty = true,
                    grade = {
                        level = grade,
                        name = QBCore.Shared.Jobs[jobName].grades[grade].name
                    },
                    isboss = QBCore.Shared.Jobs[jobName].grades[grade].isboss or false
                }

                MySQL.Async.execute('UPDATE players SET job = @job WHERE citizenid = @citizenid', {
                    ['@citizenid'] = citizenid,
                    ['@job'] = json.encode(jobInfo)
                }, function(rowsChanged)
                    if rowsChanged > 0 then
                        local message = currentJob.name == jobName and "Employee rank updated successfully" or "Employee successfully transferred to this job"

                        -- Log entry
                        TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Offline Employee Update', 'green', string.format('%s (%s) updated %s job from %s to %s at rank %s',
                            GetPlayerName(src), Player.PlayerData.citizenid, citizenid, currentJob.name, jobName, grade))

                        cb({success = true, message = message})
                    else
                        cb({success = false, message = "Database update failed"})
                    end
                end)
            end)
        end
    end)
end)

-- Remove employee with proper callback
QBCore.Functions.CreateCallback('alpha-bossmenu:server:RemoveEmployeeCallback', function(source, cb, citizenid, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.name ~= jobName then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end

    -- Check if player has boss permissions or minimum rank + hiring permission
    local hasPermission = Player.PlayerData.job.isboss

    if not hasPermission then
        -- Check minimum rank requirement
        local minimumRank = Config.MinimumRank[jobName] or 0
        local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0

        if playerGrade < minimumRank then
            cb({success = false, message = "You don't have sufficient rank for this action"})
            return
        end

        -- Check for hiring/firing permission
        local result = MySQL.Sync.fetchSingle('SELECT permissions FROM job_employee_permissions WHERE citizenid = @citizenid AND job = @job', {
            ['@citizenid'] = Player.PlayerData.citizenid,
            ['@job'] = jobName
        })

        if result and result.permissions then
            local permissions = json.decode(result.permissions)
            hasPermission = permissions.hiringfiring or false
        end
    end

    if not hasPermission then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end

    -- Check if employee exists and belongs to this job
    MySQL.Async.fetchSingle('SELECT job FROM players WHERE citizenid = @citizenid', {
        ['@citizenid'] = citizenid
    }, function(result)
        if not result or not result.job then
            cb({success = false, message = "Player not found"})
            return
        end

        local currentJob = json.decode(result.job)
        if currentJob.name ~= jobName then
            cb({success = false, message = "This player doesn't work for this job"})
            return
        end

        -- Set default job for online player
        local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if targetPlayer then
            targetPlayer.Functions.SetJob("unemployed", 0)
            TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "You have been fired from your job", "error")

            -- Close boss menu for fired player if they have it open
            TriggerClientEvent('alpha-bossmenu:client:ForceCloseUI', targetPlayer.PlayerData.source)

            -- Refresh all boss menus for this job
            TriggerClientEvent('alpha-bossmenu:client:RefreshData', -1)

            -- Log entry
            TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Employee Fired', 'red', string.format('%s (%s) fired %s (%s) from job %s',
                GetPlayerName(src), Player.PlayerData.citizenid, GetPlayerName(targetPlayer.PlayerData.source), citizenid, jobName))

            cb({success = true, message = "Employee removed successfully"})
        else
            local jobInfo = {
                name = "unemployed",
                label = "Unemployed",
                payment = 10,
                onduty = true,
                grade = {
                    level = 0,
                    name = "Unemployed"
                },
                isboss = false
            }

            MySQL.Async.execute('UPDATE players SET job = @job WHERE citizenid = @citizenid', {
                ['@citizenid'] = citizenid,
                ['@job'] = json.encode(jobInfo)
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    -- Refresh all boss menus for this job
                    TriggerClientEvent('alpha-bossmenu:client:RefreshData', -1)

                    -- Log entry
                    TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Offline Employee Fired', 'red', string.format('%s (%s) fired %s from job %s',
                        GetPlayerName(src), Player.PlayerData.citizenid, citizenid, jobName))

                    cb({success = true, message = "Employee removed successfully"})
                else
                    cb({success = false, message = "Database update failed"})
                end
            end)
        end
    end)
end)

-- Deposit money with callback
QBCore.Functions.CreateCallback('alpha-bossmenu:server:DepositMoneyCallback', function(source, cb, amount, note, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not HasSocietyPermission(src, jobName) then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end

    if Player.PlayerData.money.cash < amount then
        cb({success = false, message = "You don't have enough cash"})
        return
    end

    -- Remove money from player
    Player.Functions.RemoveMoney('cash', amount)

    -- Add money to society account
    local success = false
    if Config.BankingSystem == "dw-banking" then
        MySQL.Async.execute('UPDATE society SET money = money + @amount WHERE name = @name', {
            ['@amount'] = amount,
            ['@name'] = jobName
        }, function(rowsChanged)
            if rowsChanged > 0 then
                success = true
            end
        end)
    elseif Config.BankingSystem == "qb-banking" then
        success = bankingModule:AddMoney(jobName, amount)
    elseif Config.BankingSystem == "renewed-banking" then
        success = RenewedBanking:addAccountMoney(jobName, amount)
    end

    if success then
        -- Add transaction record
        AddSocietyTransaction(jobName, {
            type = 'deposit',
            amount = amount,
            employee = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            executor = Player.PlayerData.citizenid,
            note = note or '',
            timestamp = os.time()
        })

        -- Log entry
        TriggerEvent('qb-log:server:CreateLog', 'society', 'Society Deposit', 'green', string.format('%s (%s) deposited %s$ to %s society',
            GetPlayerName(src), Player.PlayerData.citizenid, amount, jobName))

        cb({success = true, message = "Funds deposited successfully"})
    else
        -- Refund player if deposit failed
        Player.Functions.AddMoney('cash', amount)
        cb({success = false, message = "Failed to deposit funds"})
    end
end)

-- Withdraw money with callback
QBCore.Functions.CreateCallback('alpha-bossmenu:server:WithdrawMoneyCallback', function(source, cb, amount, note, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not HasSocietyPermission(src, jobName) then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end

    -- Check society balance
    local societyData = GetSocietyData(jobName)
    if not societyData or societyData.balance < amount then
        cb({success = false, message = "Not enough funds in society account"})
        return
    end

    -- Remove money from society account
    local success = false
    if Config.BankingSystem == "dw-banking" then
        MySQL.Async.execute('UPDATE society SET money = money - @amount WHERE name = @name', {
            ['@amount'] = amount,
            ['@name'] = jobName
        }, function(rowsChanged)
            if rowsChanged > 0 then
                success = true
            end
        end)
    elseif Config.BankingSystem == "qb-banking" then
        success = bankingModule:RemoveMoney(jobName, amount)
    elseif Config.BankingSystem == "renewed-banking" then
        success = RenewedBanking:removeAccountMoney(jobName, amount)
    end

    if success then
        -- Add money to player
        Player.Functions.AddMoney('cash', amount)

        -- Add transaction record
        AddSocietyTransaction(jobName, {
            type = 'withdraw',
            amount = amount,
            employee = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            executor = Player.PlayerData.citizenid,
            note = note or '',
            timestamp = os.time()
        })

        -- Log entry
        TriggerEvent('qb-log:server:CreateLog', 'society', 'Society Withdraw', 'orange', string.format('%s (%s) withdrew %s$ from %s society',
            GetPlayerName(src), Player.PlayerData.citizenid, amount, jobName))

        cb({success = true, message = "Funds withdrawn successfully"})
    else
        cb({success = false, message = "Failed to withdraw funds"})
    end
end)

-- Transfer money with callback
QBCore.Functions.CreateCallback('alpha-bossmenu:server:TransferMoneyCallback', function(source, cb, citizenid, amount, note, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not HasSocietyPermission(src, jobName) then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end

    -- Check society balance
    local societyData = GetSocietyData(jobName)
    if not societyData or societyData.balance < amount then
        cb({success = false, message = "Not enough funds in society account"})
        return
    end

    -- Check if target player exists
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not targetPlayer then
        cb({success = false, message = "Target player not found or offline"})
        return
    end

    -- Remove money from society account
    local success = false
    if Config.BankingSystem == "dw-banking" then
        MySQL.Async.execute('UPDATE society SET money = money - @amount WHERE name = @name', {
            ['@amount'] = amount,
            ['@name'] = jobName
        }, function(rowsChanged)
            if rowsChanged > 0 then
                success = true
            end
        end)
    elseif Config.BankingSystem == "qb-banking" then
        success = bankingModule:RemoveMoney(jobName, amount)
    elseif Config.BankingSystem == "renewed-banking" then
        success = RenewedBanking:removeAccountMoney(jobName, amount)
    end

    if success then
        -- Add money to target player
        targetPlayer.Functions.AddMoney('cash', amount)

        -- Notify target player
        TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source,
            string.format("You received $%s from %s", amount, jobName), "success")

        -- Add transaction record
        AddSocietyTransaction(jobName, {
            type = 'transfer',
            amount = amount,
            employee = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
            executor = Player.PlayerData.citizenid,
            note = note or '',
            timestamp = os.time()
        })

        -- Log entry
        TriggerEvent('qb-log:server:CreateLog', 'society', 'Society Transfer', 'blue', string.format('%s (%s) transferred %s$ from %s society to %s (%s)',
            GetPlayerName(src), Player.PlayerData.citizenid, amount, jobName,
            GetPlayerName(targetPlayer.PlayerData.source), citizenid))

        cb({success = true, message = "Funds transferred successfully"})
    else
        cb({success = false, message = "Failed to transfer funds"})
    end
end)

-- Update employee permissions
QBCore.Functions.CreateCallback('alpha-bossmenu:server:UpdateEmployeePermissions', function(source, cb, citizenid, jobName, permissions)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        cb({success = false, message = "Player not found"})
        return
    end
    
    if Player.PlayerData.job.name ~= jobName then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end
    
    -- Check if player has boss permissions
    if not Player.PlayerData.job.isboss then
        cb({success = false, message = "You don't have permission for this action"})
        return
    end
    
    
    -- Update the permissions cache
    if not JobPermissionsCache[jobName] then
        JobPermissionsCache[jobName] = {}
    end
    JobPermissionsCache[jobName][citizenid] = permissions
    
    -- JSON encode the permissions
    local permissionsJson = json.encode(permissions)
    
    -- Save permissions to database
    MySQL.Async.execute('INSERT INTO job_employee_permissions (citizenid, job, permissions, granted_by) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE permissions = ?, granted_by = ?', 
        {citizenid, jobName, permissionsJson, Player.PlayerData.citizenid, permissionsJson, Player.PlayerData.citizenid}, 
        function(rowsChanged)
        if rowsChanged > 0 then
            cb({success = true})
            
            -- If target is online, update their permissions immediately
            local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
            if targetPlayer then
                TriggerClientEvent('alpha-bossmenu:client:RefreshPermissions', targetPlayer.PlayerData.source, permissions)
                TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Your job permissions have been updated", "info")
            end
            
            -- Broadcast the permission update to all players with this job for real-time sync
            local players = QBCore.Functions.GetQBPlayers()
            for _, p in pairs(players) do
                if p.PlayerData.job.name == jobName then
                    TriggerClientEvent('alpha-bossmenu:client:SyncPermissions', p.PlayerData.source, citizenid, permissions)
                end
            end
            
            -- Log entry
            TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Employee Permissions Update', 'green', string.format('%s (%s) updated permissions for %s in job %s',
                GetPlayerName(src), Player.PlayerData.citizenid, citizenid, jobName))
        else
            cb({success = false, message = "Failed to update permissions"})
        end
    end)
end)

QBCore.Functions.CreateCallback('alpha-bossmenu:server:HireNewEmployee', function(source, cb, targetId, jobName, grade)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    
    if not Player then
        cb({ success = false, message = "Error: Manager not found" })
        return
    end
    
    if not Target then
        cb({ success = false, message = "Player with ID " .. targetId .. " not found" })
        return
    end
    
    if Player.PlayerData.job.name ~= jobName then
        cb({ success = false, message = "You don't have permission for this job" })
        return
    end
    
    -- Check if player has boss permissions
    if not Player.PlayerData.job.isboss then
        cb({ success = false, message = "You don't have hiring permissions" })
        return
    end
    
    -- Check if grade exists for this job
    if not QBCore.Shared.Jobs[jobName].grades[grade] then
        cb({ success = false, message = "Invalid job grade" })
        return
    end
    
    -- Set employee job
    Target.Functions.SetJob(jobName, grade)
    
    -- Notify the target
    TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, "You've been hired: " .. QBCore.Shared.Jobs[jobName].label, "success")
    
    -- Update the job data for all clients
    TriggerClientEvent('alpha-bossmenu:client:JobChanged', -1, jobName)
    
    -- Log the action
    TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Employee Hire', 'green', string.format('%s (%s) hired %s (%s) for job %s at rank %s',
        GetPlayerName(src), Player.PlayerData.citizenid, GetPlayerName(Target.PlayerData.source), Target.PlayerData.citizenid, jobName, grade))
    
    -- Return success
    cb({ success = true, message = "Employee hired successfully" })
end)


QBCore.Functions.CreateCallback('alpha-bossmenu:server:HasJobAccess', function(source, cb, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or Player.PlayerData.job.name ~= jobName then
        cb(false)
        return
    end
    
    -- If player is a boss, they have access
    if Player.PlayerData.job.isboss then
        cb(true)
        return
    end
    
    -- Check if player has any permissions for this job
    MySQL.Async.fetchAll('SELECT permissions FROM job_employee_permissions WHERE citizenid = @citizenid AND job = @job', {
        ['@citizenid'] = Player.PlayerData.citizenid,
        ['@job'] = jobName
    }, function(result)
        if result and result[1] and result[1].permissions then
            local permissions = json.decode(result[1].permissions)
            
            -- Check if any permission is granted
            local hasAnyPermission = false
            for _, permValue in pairs(permissions) do
                if permValue then
                    hasAnyPermission = true
                    break
                end
            end
            
            cb(hasAnyPermission)
        else
            cb(false)
        end
    end)
end)

function HasSocietyPermission(src, jobName)
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.name ~= jobName then
        return false
    end

    if Player.PlayerData.job.isboss then
        return true
    end

    -- Check minimum rank requirement
    local minimumRank = Config.MinimumRank[jobName] or 0
    local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0

    if playerGrade < minimumRank then
        return false
    end

    local citizenid = Player.PlayerData.citizenid
    
    if JobPermissionsCache[jobName] and JobPermissionsCache[jobName][citizenid] then
        return JobPermissionsCache[jobName][citizenid].society or false
    end
    
    local result = MySQL.Sync.fetchSingle('SELECT permissions FROM job_employee_permissions WHERE citizenid = @citizenid AND job = @job', {
        ['@citizenid'] = citizenid,
        ['@job'] = jobName
    })
    
    if result and result.permissions then
        local permissions = json.decode(result.permissions)
        
        if not JobPermissionsCache[jobName] then
            JobPermissionsCache[jobName] = {}
        end
        JobPermissionsCache[jobName][citizenid] = permissions
        
        return permissions.society or false
    end
    
    return false
end

-- Create a new event to handle permission-specific actions
RegisterServerEvent('alpha-bossmenu:server:PermissionAction', function(action, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then return end

    local jobName = Player.PlayerData.job.name
    local citizenid = Player.PlayerData.citizenid

    -- Check if player has permission for this action
    local hasPermission = false

    -- If player is a boss, they have all permissions
    if Player.PlayerData.job.isboss then
        hasPermission = true
    else
        -- Check minimum rank requirement first
        local minimumRank = Config.MinimumRank[jobName] or 0
        local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0

        if playerGrade < minimumRank then
            TriggerClientEvent('QBCore:Notify', src, "You don't have sufficient rank for this action", "error")
            return
        end

        -- Get permissions from database
        local result = MySQL.Sync.fetchSingle('SELECT permissions FROM job_employee_permissions WHERE citizenid = @citizenid AND job = @job', {
            ['@citizenid'] = citizenid,
            ['@job'] = jobName
        })

        if result and result.permissions then
            local permissions = json.decode(result.permissions)

            -- Check specific permission
            if action == "viewEmployees" and permissions.employees then
                hasPermission = true
            elseif action == "viewSociety" and permissions.society then
                hasPermission = true
            elseif action == "viewGrades" and permissions.grades then
                hasPermission = true
            elseif action == "hiring" and permissions.hiringfiring then
                hasPermission = true
            end
        end
    end

    if not hasPermission then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission for this action", "error")
        return
    end

    -- Process the permission-specific action
    if action == "viewEmployees" then
        -- Logic for viewing employees
    elseif action == "viewSociety" then
        -- Logic for viewing society
    elseif action == "viewGrades" then
        -- Logic for viewing grades
    elseif action == "hiring" then
        -- Logic for hiring
    end
end)

-- New callback specifically for playtime updates
QBCore.Functions.CreateCallback('alpha-bossmenu:server:GetPlaytimeData', function(source, cb, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        cb(false)
        return
    end

    if Player.PlayerData.job.name ~= jobName then
        cb(false)
        return
    end

    -- Check permissions - boss or minimum rank
    local hasBossAccess = Player.PlayerData.job.isboss
    local hasPermission = hasBossAccess

    if not hasBossAccess then
        -- Check minimum rank requirement
        local minimumRank = Config.MinimumRank[jobName] or 0
        local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0

        if playerGrade < minimumRank then
            cb(false)
            return
        end

        -- Check for dashboard permission
        local result = MySQL.Sync.fetchSingle('SELECT permissions FROM job_employee_permissions WHERE citizenid = @citizenid AND job = @job', {
            ['@citizenid'] = Player.PlayerData.citizenid,
            ['@job'] = jobName
        })

        if result and result.permissions then
            local permissions = json.decode(result.permissions)
            hasPermission = permissions.dashboard or false
        end
    end

    if not hasPermission then
        cb(false)
        return
    end
    
    -- Get database records for all employees of this job
    MySQL.Async.fetchAll('SELECT citizenid FROM players WHERE JSON_EXTRACT(job, "$.name") = @jobName', {
        ['@jobName'] = jobName
    }, function(employees)
        if not employees or #employees == 0 then
            cb({ employees = {} })
            return
        end
        
        local employeeData = {}
        -- Process each employee
        for _, employee in pairs(employees) do
            local citizenid = employee.citizenid
            
            -- Check if player is online
            local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
            local isOnline = targetPlayer ~= nil
            local playTime = 0
            
            if isOnline then
                -- Calculate playtime from PlayerJoinTimes first
                if PlayerJoinTimes[citizenid] then
                    local sessionTime = math.floor((os.time() - PlayerJoinTimes[citizenid].time) / 60)
                    
                    -- Get accumulated time from database or cache
                    local dbPlaytime = GetCachedPlaytime(citizenid, jobName)
                    
                    -- Use total time
                    playTime = dbPlaytime + sessionTime
                else 
                    -- If no record in PlayerJoinTimes, use metadata or create new tracking
                    local joinTime = targetPlayer.PlayerData.metadata.joinTime or os.time()
                    playTime = math.floor((os.time() - joinTime) / 60)
                    
                    -- Create new tracking record
                    PlayerJoinTimes[citizenid] = {
                        time = joinTime,
                        job = jobName
                    }
                end
            else
                -- For offline players, get playtime from database only
                playTime = GetCachedPlaytime(citizenid, jobName)
            end
            
            table.insert(employeeData, {
                citizenid = citizenid,
                playTime = playTime
            })
        end
            cb({ employees = employeeData })
    end)
end)

QBCore.Functions.CreateCallback('alpha-bossmenu:server:GetJobGrades', function(source, cb, jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player or Player.PlayerData.job.name ~= jobName then
        cb(false)
        return
    end

    if not Player.PlayerData.job.isboss then
        -- Check minimum rank requirement
        local minimumRank = Config.MinimumRank[jobName] or 0
        local playerGrade = tonumber(Player.PlayerData.job.grade.level) or 0

        if playerGrade < minimumRank then
            cb(false)
            return
        end

        local result = MySQL.Sync.fetchSingle('SELECT permissions FROM job_employee_permissions WHERE citizenid = @citizenid AND job = @job', {
            ['@citizenid'] = Player.PlayerData.citizenid,
            ['@job'] = jobName
        })

        local hasPermission = false
        if result and result.permissions then
            local permissions = json.decode(result.permissions)
            if permissions.grades then
                hasPermission = true
            end
        end

        if not hasPermission then
            cb(false)
            return
        end
    end

    if QBCore.Shared.Jobs[jobName] and QBCore.Shared.Jobs[jobName].grades then
        cb(QBCore.Shared.Jobs[jobName].grades)
    else
        cb(false)
    end
end)
