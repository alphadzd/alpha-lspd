local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isLoggedIn = false
local menuOpen = false
local allowAutoOpen = false -- Extra safeguard flag
local currentPermissions = nil
local DEBUG_MODE = true
local LAST_DEBUG = ""


-- Debug function
local function DebugPrint(msg)
    if DEBUG_MODE then
        print("^3[alpha-bossmenu Debug]^7 " .. msg)
        LAST_DEBUG = msg
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
    menuOpen = false
    Wait(2000)
    CreateJobInteractPoints()

end)

RegisterNetEvent('alpha-bossmenu:client:JobChanged', function(jobName)
    if menuOpen and PlayerData.job and PlayerData.job.isboss and PlayerData.job.name == jobName then
        QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetJobData', function(jobData)
            if jobData then
                SendNUIMessage({
                    action = "refreshData",
                    jobData = jobData
                })
            end
        end, jobName)
    end
end)

function UseInteractSystem(action, ...)
    if Config.InteractSystem == "interact" then
        return exports.interact[action](...)
    end
end






RegisterNetEvent('alpha-bossmenu:client:SyncPermissions', function(targetCitizenid, permissions)
    if not PlayerData.job or not PlayerData.job.isboss then return end
    
    if menuOpen and selectedEmployeeForPermissions and selectedEmployeeForPermissions.citizenid == targetCitizenid then
        currentEmployeePermissions = permissions
        
        SendNUIMessage({
            action = "updatePermissionToggles",
            permissions = permissions
        })
    end
end)


RegisterNetEvent('eventName', function()
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = "testModal",
        message = "This is a test modal"
    })
end, false)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    PlayerData = {}
    menuOpen = false
end)


RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    local oldJob = PlayerData.job and PlayerData.job.name or "none"
    PlayerData.job = JobInfo
    
    -- If the menu is open, refresh it
    if menuOpen then
        if PlayerData.job.isboss then
            QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetJobData', function(jobData)
                if jobData then
                    SendNUIMessage({
                        action = "refreshData",
                        jobData = jobData
                    })
                end
            end, PlayerData.job.name)
        else
            -- If the player is no longer a boss, close the menu
            SetNuiFocus(false, false)
            SendNUIMessage({ action = "closeUI" })
            menuOpen = false
        end
    end
end)

-- Create ONLY interaction points for job management
function CreateJobInteractPoints()
    -- Remove existing interactions
    for jobName, _ in pairs(Config.Locations) do
        if Config.InteractSystem == "interact" then
            -- Remove main interaction
            exports.interact:RemoveInteraction("jobmanagement_"..jobName)

            -- Remove numbered interactions
            local i = 1
            while i <= 10 do
                exports.interact:RemoveInteraction("jobmanagement_"..jobName.."_"..i)
                i = i + 1
            end
        end
    end

    for jobName, jobData in pairs(Config.Locations) do
        local jobLabel = jobData.label

        for locationIndex, location in ipairs(jobData.locations) do
            local zoneName = "jobmanagement_"..jobName

            if locationIndex > 1 then
                zoneName = zoneName.."_"..locationIndex
            end

            if Config.InteractSystem == "interact" then
                -- Create job-specific groups table for access control
                local jobGroups = {}
                local minimumRank = Config.MinimumRank[jobName] or 0
                jobGroups[jobName] = minimumRank

                exports.interact:AddInteraction({
                    coords = location.coords,
                    distance = 8.0,
                    interactDst = 2.0,
                    id = zoneName,
                    name = 'jobmanagement_' .. jobName,
                    groups = jobGroups,
                    options = {
                        {
                            label = 'Manage ' .. jobLabel,
                            action = function(entity, coords, args)
                                -- Additional check for boss or minimum rank
                                if PlayerData.job and PlayerData.job.name == jobName then
                                    if PlayerData.job.isboss then
                                        TriggerEvent("alpha-bossmenu:client:TriggerOpenManager", {jobData = jobName})
                                    else
                                        local playerGrade = tonumber(PlayerData.job.grade.level) or 0
                                        if playerGrade >= minimumRank then
                                            TriggerEvent("alpha-bossmenu:client:TriggerOpenManager", {jobData = jobName})
                                        else
                                            QBCore.Functions.Notify("You don't have sufficient rank to access this", "error")
                                        end
                                    end
                                else
                                    QBCore.Functions.Notify("You are not part of this job", "error")
                                end
                            end,
                        },
                    }
                })
            end
        end
    end
end


RegisterNetEvent('alpha-bossmenu:client:TriggerOpenManager', function(data)
    TriggerServerEvent('alpha-bossmenu:server:RequestRefreshJobData')
    
    if not data or not data.jobData then
        return
    end
    
    -- Prevent double-opening
    if menuOpen then
        return
    end
    
    local jobName = data.jobData
    
    -- Multiple validation checks
    if not isLoggedIn then
        return
    end
    
    if not PlayerData.job then
        return
    end
    
    if PlayerData.job.name ~= jobName then
        QBCore.Functions.Notify("You are not part of this job", "error")
        return
    end
    
    -- Check if boss or has permissions
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:HasJobAccess', function(hasAccess)
        if not hasAccess then
            -- Check if it's a rank issue
            local minimumRank = Config.MinimumRank[jobName] or 0
            local playerGrade = tonumber(PlayerData.job.grade.level) or 0

            if not PlayerData.job.isboss and playerGrade < minimumRank then
                local gradeName = QBCore.Shared.Jobs[jobName].grades[tostring(minimumRank)].name or "Unknown"
                QBCore.Functions.Notify("You need to be at least rank " .. gradeName .. " to access the boss menu", "error")
            else
                QBCore.Functions.Notify("You don't have permission to manage this job", "error")
            end
            return
        end

        -- Proceed with opening the manager
        OpenJobManager(jobName)
    end, jobName)
end)

-- Register the NUI callback for updateEmployeePermissions
RegisterNUICallback('updateEmployeePermissions', function(data, cb)
    if not data.citizenid or not data.jobName or not data.permissions then
        cb({success = false, message = "Invalid data"})
        return
    end    
    -- Trigger server event to update permissions
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:UpdateEmployeePermissions', function(result)
        cb(result) 
    end, data.citizenid, data.jobName, data.permissions)
end)

RegisterNUICallback('getEmployeePermissions', function(data, cb)
    local citizenid = data.citizenid
    local jobName = data.jobName
    
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetEmployeePermissions', function(permissions)
        cb(permissions)
    end, citizenid, jobName)
end)

RegisterNetEvent('alpha-bossmenu:client:RefreshPermissions', function(permissions)
    if not PlayerData.job then return end
    
    if permissions then
        -- If permissions were provided directly, update them
        currentPermissions = permissions
        
        -- If menu is open, refresh it with new permissions
        if menuOpen then
            SendNUIMessage({
                action = "updatePermissions",
                permissions = permissions
            })
        end
    else
        -- Otherwise, request current permissions
        QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetEmployeePermissions', function(newPermissions)
            if newPermissions then
                currentPermissions = newPermissions
                
                -- If menu is open, refresh it with new permissions
                if menuOpen then
                    SendNUIMessage({
                        action = "updatePermissions", 
                        permissions = newPermissions
                    })
                end
            end
        end, PlayerData.citizenid, PlayerData.job.name)
    end
end)
-- Separated function to handle the actual opening
function OpenJobManager(jobName)
    if menuOpen then return end
    
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetJobData', function(jobData)
        if not jobData then
            QBCore.Functions.Notify("Unable to load job data", "error")
            return
        end        
        -- Store received permissions
        currentPermissions = jobData.permissions

        local jobConfig = Config.Locations[jobName]
        if jobConfig then
            jobData.logoImage = jobConfig.logoImage
            if jobConfig.jobLabel then
                jobData.jobLabel = jobConfig.jobLabel
            elseif jobConfig.label then
                jobData.jobLabel = jobConfig.label
            end
        end
            
        -- Ensure jobLabel exists
        if not jobData.jobLabel or jobData.jobLabel == "" then
            jobData.jobLabel = QBCore.Shared.Jobs[jobName].label or jobName
        end
        
        QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetSettings', function(settings)
            if not settings then
                return
            end
            QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetSocietyData', function(societyData)
                if not societyData then
                end                
                menuOpen = true
                
                SetNuiFocus(true, true)
                SendNUIMessage({
                    action = "openUI",
                    jobData = jobData,
                    jobName = jobName,
                    playerJob = PlayerData.job,
                    settings = settings,
                    societyData = societyData,
                    permissions = currentPermissions
                })
            end, jobName)
        end)
    end, jobName)
end


RegisterNUICallback('checkPermission', function(data, cb)
    local permissionType = data.permissionType
    
    if PlayerData.job and PlayerData.job.isboss then
        cb(true)
        return
    end
    
    -- If we have stored permissions, check them
    if currentPermissions and currentPermissions[permissionType] then
        cb(true)
        return
    end
    
    -- Default deny if no permissions found
    cb(false)
end)

-- Function to check permissions before certain actions
function HasPermission(permissionType)
    -- If player is a boss, they have all permissions
    if PlayerData.job and PlayerData.job.isboss then
        return true
    end
    
    -- If we have stored permissions, check them
    if currentPermissions and currentPermissions[permissionType] then
        return true
    end
    
    -- Default deny if no permissions found
    return false
end

-- Block the original event to prevent any other scripts from triggering it
RegisterNetEvent('alpha-bossmenu:client:OpenManager', function()
    DebugPrint("Blocked automatic opening from original event")
end)

-- Refresh data event handler
RegisterNetEvent('alpha-bossmenu:client:RefreshData', function()
    if isLoggedIn and PlayerData.job and menuOpen then
        -- Check if player has access (boss or minimum rank)
        local hasAccess = PlayerData.job.isboss
        if not hasAccess then
            local minimumRank = Config.MinimumRank[PlayerData.job.name] or 0
            local playerGrade = tonumber(PlayerData.job.grade.level) or 0
            hasAccess = playerGrade >= minimumRank
        end

        if hasAccess then
            QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetJobData', function(jobData)
                if jobData then
                    SendNUIMessage({
                        action = "refreshData",
                        jobData = jobData
                    })
                end
            end, PlayerData.job.name)
        else
            -- Player lost access, close the UI
            SetNuiFocus(false, false)
            menuOpen = false
            QBCore.Functions.Notify("You no longer have access to the boss menu", "error")
        end
    end
end)

-- Force close UI event (for fired employees)
RegisterNetEvent('alpha-bossmenu:client:ForceCloseUI', function()
    if menuOpen then
        SetNuiFocus(false, false)
        menuOpen = false
        QBCore.Functions.Notify("You have been removed from your job", "error")
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeUI', function(_, cb)
    SetNuiFocus(false, false)
    menuOpen = false
    cb('ok')
end)

RegisterNUICallback('showFireConfirmMenu', function(data, cb)
    local citizenid = data.citizenid
    local employeeName = data.name
    
    ShowFireConfirmationMenu(citizenid, employeeName)
    
    cb('ok')
end)

function ShowFireConfirmationMenu(citizenid, employeeName)
    local headerText = "Fire Employee"
    local message = "Are you sure you want to fire " .. employeeName .. "?"
    
    local menuOptions = {
        {
            header = "Confirm Firing",
            txt = "Yes, fire this employee",
            params = {
                event = "alpha-bossmenu:client:FireEmployeeConfirmed",
                args = {
                    citizenid = citizenid,
                    confirmed = true
                }
            }
        },
        {
            header = "Cancel",
            txt = "No, keep this employee",
            params = {
                event = "alpha-bossmenu:client:FireEmployeeConfirmed",
                args = {
                    citizenid = citizenid,
                    confirmed = false
                }
            }
        }
    }
    
    exports['qb-menu']:openMenu(menuOptions)
end

function ShowCustomFireMenu(citizenid, employeeName)
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = "showCustomFireMenu",
        name = employeeName,
        citizenid = citizenid
    })
end



RegisterNUICallback('fireMenuResponse', function(data, cb)
    if data.confirmed and data.citizenid then
        -- Actually fire the employee using the new callback
        QBCore.Functions.TriggerCallback('alpha-bossmenu:server:RemoveEmployeeCallback', function(result)
            if result.success then
                QBCore.Functions.Notify(result.message, "success")
                cb({success = true, message = result.message})
            else
                QBCore.Functions.Notify(result.message, "error")
                cb({success = false, message = result.message})
            end
        end, data.citizenid, PlayerData.job.name)
    else
        -- User cancelled
        cb({success = false, message = "Action cancelled"})
    end
end)

RegisterNetEvent('alpha-bossmenu:client:FireEmployeeConfirmed', function(data)
    SendNUIMessage({
        action = "fireEmployeeResponse",
        confirmed = data.confirmed,
        citizenid = data.citizenid
    })
end)

RegisterNUICallback('updateEmployee', function(data, cb)
    if not data.citizenid or not data.grade then
        cb({success = false, message = "Missing required data"})
        return
    end

    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:UpdateEmployeeRank', function(result)
        cb(result)
    end, data.citizenid, PlayerData.job.name, data.grade)
end)

RegisterNUICallback('removeEmployee', function(data, cb)
    TriggerServerEvent('alpha-bossmenu:server:RemoveEmployee', data.citizenid, PlayerData.job.name)
    cb('ok')
end)

RegisterNUICallback('saveSettings', function(data, cb)
    TriggerServerEvent('alpha-bossmenu:server:SaveSettings', data)
    cb('ok')
end)

-- Refresh data
RegisterNUICallback('refreshData', function(_, cb)
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetJobData', function(jobData)
        if jobData then
            cb(jobData)
        else
            cb(false)
        end
    end, PlayerData.job.name)
end)

-- Extra safeguard for resource start/stop
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end    
    Wait(3000)
    
    if Config.InteractSystem ~= "interact" then
        print("^1[alpha-bossmenu]^7 Invalid interact system in config: " .. (Config.InteractSystem or "nil") .. ". Defaulting to interact.")
        Config.InteractSystem = "interact"
    end

    if LocalPlayer.state.isLoggedIn then
        PlayerData = QBCore.Functions.GetPlayerData()
        isLoggedIn = true
        CreateJobInteractPoints()

    end
end)

-- Command to manually trigger the job manager (for testing/emergency)
RegisterCommand('fixjobmanager', function()
    CreateJobInteractPoints()
    QBCore.Functions.Notify("Job Manager interact points refreshed", "success")
end, false)

CreateThread(function()
    while true do
        Wait(60000) -- Update every minute

        -- Only refresh if menu is open and player has access
        if menuOpen and isLoggedIn and PlayerData.job then
            local hasAccess = PlayerData.job.isboss
            if not hasAccess then
                local minimumRank = Config.MinimumRank[PlayerData.job.name] or 0
                local playerGrade = tonumber(PlayerData.job.grade.level) or 0
                hasAccess = playerGrade >= minimumRank
            end

            if hasAccess then
                TriggerServerEvent('alpha-bossmenu:server:RefreshPlayTime')
            end
        end

        Wait(60000) -- Wait another minute before next check
    end
end)

RegisterNUICallback('getSocietyData', function(data, cb)
    if not data.jobName then
        cb(false)
        return
    end
    
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetSocietyData', function(societyData)
        if societyData then
            cb(societyData)
        else
            cb(false)
        end
    end, data.jobName)
end)

RegisterNUICallback('depositMoney', function(data, cb)
    if not data.amount or not data.jobName then
        cb({success = false, message = "Missing required data"})
        return
    end

    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:DepositMoneyCallback', function(result)
        cb(result)
    end, data.amount, data.note, data.jobName)
end)

RegisterNUICallback('withdrawMoney', function(data, cb)
    if not data.amount or not data.jobName then
        cb({success = false, message = "Missing required data"})
        return
    end

    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:WithdrawMoneyCallback', function(result)
        cb(result)
    end, data.amount, data.note, data.jobName)
end)

RegisterNUICallback('transferMoney', function(data, cb)
    if not data.citizenid or not data.amount or not data.jobName then
        cb({success = false, message = "Missing required data"})
        return
    end

    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:TransferMoneyCallback', function(result)
        cb(result)
    end, data.citizenid, data.amount, data.note, data.jobName)
end)

RegisterNUICallback('showNotification', function(data, cb)
    local message = data.message or "Error"
    local type = data.type or "error"
    QBCore.Functions.Notify(message, type)
    
    cb('ok')
end)




-- Register client callback for this new function
RegisterNUICallback('getPlaytimeData', function(data, cb)
    if not data or not data.jobName then
        cb({success = false, message = "Missing job name"})
        return
    end    
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetPlaytimeData', function(playtimeData)
        if playtimeData then
            cb(playtimeData)
        else
            cb({success = false, message = "Failed to get playtime data", employees = {}})
        end
    end, data.jobName)
end)


RegisterNUICallback('hireEmployee', function(data, cb)
    if not data.targetId or not data.jobName or not data.grade then
        cb({ success = false, message = "Missing required data" })
        return
    end
    
    -- Convert to numbers if needed
    local targetId = tonumber(data.targetId)
    local grade = data.grade
    
    -- Trigger server event
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:HireNewEmployee', function(result)
        cb(result)
    end, targetId, data.jobName, grade)
end)

RegisterNUICallback('checkPermission', function(data, cb)
    local permissionType = data.permissionType
    
    -- If player is a boss, they have all permissions
    if PlayerData.job and PlayerData.job.isboss then
        cb(true)
        return
    end
    
    -- If we have stored permissions, check them
    if currentPermissions and currentPermissions[permissionType] then
        cb(true)
        return
    end
    
    -- Default deny if no permissions found
    cb(false)
end)


RegisterNUICallback('updateJobGrade', function(data, cb)
    if not data.jobName or not data.gradeLevel or not data.gradeName or not data.gradePayment then
        cb({success = false, message = "Missing required data"})
        return
    end
    
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:UpdateJobGrade', function(result)
        cb(result)
    end, data.jobName, data.gradeLevel, data.gradeName, data.gradePayment, data.gradeIsBoss)
end)

RegisterNUICallback('addJobGrade', function(data, cb)
    if not data.jobName or not data.gradeName or not data.gradePayment then
        cb({success = false, message = "Missing required data"})
        return
    end
    
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:AddJobGrade', function(result)
        cb(result)
    end, data.jobName, data.gradeName, data.gradePayment, data.gradeIsBoss)
end)

RegisterNUICallback('deleteJobGrade', function(data, cb)
    if not data.jobName or not data.gradeLevel then
        cb({success = false, message = "Missing required data"})
        return
    end
    
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:DeleteJobGrade', function(result)
        cb(result)
    end, data.jobName, data.gradeLevel)
end)

RegisterNUICallback('getJobGrades', function(data, cb)
    if not data or not data.jobName then
        cb(false)
        return
    end
        
    QBCore.Functions.TriggerCallback('alpha-bossmenu:server:GetJobGrades', function(gradesData)
        if gradesData then
            cb(gradesData)
        else
            cb(false)
        end
    end, data.jobName)
end)
