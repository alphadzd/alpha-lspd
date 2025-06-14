local QBCore = exports['qb-core']:GetCoreObject()

local airshipNPCPed = nil

local function SpawnAirShipNPC()
    if not Config.AirShipNPC.enabled then
        return
    end

    local model = Config.AirShipNPC.npcModel

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end

    local coords = Config.AirShipNPC.npcCoords
    airshipNPCPed = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)

    SetEntityCanBeDamaged(airshipNPCPed, false)
    SetPedCanRagdollFromPlayerImpact(airshipNPCPed, false)
    SetBlockingOfNonTemporaryEvents(airshipNPCPed, true)
    SetPedDefaultComponentVariation(airshipNPCPed)
    SetPedCanBeTargetted(airshipNPCPed, false)
    SetPedCanBeKnockedOffVehicle(airshipNPCPed, 1)
    FreezeEntityPosition(airshipNPCPed, true)

    Wait(500)

    exports.interact:AddLocalEntityInteraction({
        entity = airshipNPCPed,
        name = 'airship_npc',
        id = 'airship_npc_interaction',
        distance = 8.0,
        interactDst = 2.0,
        ignoreLos = false,
        groups = {
            ['police'] = 0,
        },
        options = {
            {
                label = Config.AirShipNPC.interactLabel,
                action = function(entity, coords, args)
                    TriggerEvent('alpha-wings:client:checkAirShipAccess')
                end,
            },
        }
    })

    exports.interact:AddLocalInteraction({
        coords = vector3(Config.AirShipNPC.npcCoords.x, Config.AirShipNPC.npcCoords.y, Config.AirShipNPC.npcCoords.z),
        name = 'airship_npc_coords',
        id = 'airship_npc_coords_interaction',
        distance = 8.0,
        interactDst = 2.0,
        ignoreLos = false,
        groups = {
            ['police'] = 0,
        },
        options = {
            {
                label = Config.AirShipNPC.interactLabel,
                action = function(coords, args)
                    TriggerEvent('alpha-wings:client:checkAirShipAccess')
                end,
            },
        }
    })

    print("^2[Alpha Wings]^7 AirShip NPC interactions created successfully!")

    print("^2[Alpha Wings]^7 AirShip NPC spawned successfully!")
end

RegisterNetEvent('alpha-wings:client:checkAirShipAccess', function()
    TriggerServerEvent('alpha-wings:server:checkAirShipWingAccess')
end)

RegisterNetEvent('alpha-wings:client:openAirShipMenu', function()
    local airshipMenuOptions = {}

    for _, helicopter in pairs(Config.AirShipNPC.helicopters) do
        table.insert(airshipMenuOptions, {
            title = helicopter.name,
            description = helicopter.description,
            icon = helicopter.icon,
            event = "alpha-wings:client:spawnPoliceHeli",
            args = {
                model = helicopter.model,
                name = helicopter.name,
                livery = helicopter.livery
            }
        })
    end

    local airshipMenu = {
        id = 'airship_helicopter_menu',
        title = Config.AirShipNPC.menu.title,
        position = 'top-right',
        options = airshipMenuOptions
    }

    lib.registerContext(airshipMenu)
    lib.showContext('airship_helicopter_menu')
end)

RegisterNetEvent('alpha-wings:client:spawnPoliceHeli', function(data)
    local heliModel = data.model
    local heliName = data.name
    local heliLivery = data.livery or 0
    local modelHash = GetHashKey(heliModel)
    local coords = Config.AirShipNPC.heliSpawnCoords
    local settings = Config.AirShipNPC.vehicleSettings
    local messages = Config.AirShipNPC.messages

    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end

    local existingVehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
    if existingVehicle ~= 0 then
        QBCore.Functions.Notify(messages.spawnBlocked, "error")
        return
    end

    local helicopter = CreateVehicle(modelHash, coords.x, coords.y, coords.z, coords.w, true, false)

    if helicopter ~= 0 then
        SetVehicleOnGroundProperly(helicopter)

        if settings.setAsMissionEntity then
            SetEntityAsMissionEntity(helicopter, true, true)
        end

        if settings.setAsPlayerOwned then
            SetVehicleHasBeenOwnedByPlayer(helicopter, true)
        end

        SetVehicleNeedsToBeHotwired(helicopter, settings.needsHotwiring)
        SetVehicleEngineOn(helicopter, settings.engineOn, true, false)
        SetVehRadioStation(helicopter, settings.radioStation)

        SetVehicleIsStolen(helicopter, false)

        SetVehicleLivery(helicopter, heliLivery)

        QBCore.Functions.Notify(heliName .. messages.spawnSuccess, "success")

        if settings.autoEnterAsDriver then
            local playerPed = PlayerPedId()
            TaskWarpPedIntoVehicle(playerPed, helicopter, -1)
        end

        print(string.format("^2[Alpha Wings]^7 %s (%s) spawned for AirShip wing member", heliName, heliModel))
    else
        QBCore.Functions.Notify(messages.spawnFailed, "error")
    end

    SetModelAsNoLongerNeeded(modelHash)
end)

CreateThread(function()
    Wait(1000)
    SpawnAirShipNPC()
    print("^2[Alpha Wings]^7 Client-side loaded successfully!")
end)

local function IsPoliceOfficer()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData.job then
        return false
    end

    local jobName = PlayerData.job.name
    local grade = PlayerData.job.grade.level

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

local function IsPoliceChief()
    local PlayerData = QBCore.Functions.GetPlayerData()
    return IsPoliceOfficer() and PlayerData.job.grade.level >= Config.PoliceJob.chiefGrade
end

CreateThread(function()
    Wait(1000)

    local model = `s_m_y_cop_01`
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end

    local wingsSystemPed = CreatePed(4, model, Config.WingsLocation.x, Config.WingsLocation.y, Config.WingsLocation.z - 1.0, Config.WingsLocation.h, false, true)

    SetEntityCanBeDamaged(wingsSystemPed, false)
    SetPedCanRagdollFromPlayerImpact(wingsSystemPed, false)
    SetBlockingOfNonTemporaryEvents(wingsSystemPed, true)
    SetPedDefaultComponentVariation(wingsSystemPed)
    SetPedCanBeTargetted(wingsSystemPed, false)
    SetPedCanBeKnockedOffVehicle(wingsSystemPed, 1)
    FreezeEntityPosition(wingsSystemPed, true)
    SetEntityInvincible(wingsSystemPed, true)

    Wait(500)

    exports.interact:AddLocalEntityInteraction({
        entity = wingsSystemPed,
        name = 'wings_system',
        id = 'wings_system_interaction',
        distance = 8.0,
        interactDst = 2.0,
        ignoreLos = false,
        groups = {
            ['police'] = 0,
        },
        options = {
            {
                label = Config.WingsSystem.name,
                action = function(entity, coords, args)
                    TriggerEvent('alpha-wings:client:openMenu')
                end,
            },
        }
    })

    exports.interact:AddLocalInteraction({
        coords = vector3(Config.WingsLocation.x, Config.WingsLocation.y, Config.WingsLocation.z),
        name = 'wings_system_coords',
        id = 'wings_system_coords_interaction',
        distance = 8.0,
        interactDst = 2.0,
        ignoreLos = false,
        groups = {
            ['police'] = 0,
        },
        options = {
            {
                label = Config.WingsSystem.name,
                action = function(coords, args)
                    TriggerEvent('alpha-wings:client:openMenu')
                end,
            },
        }
    })

    print("^2[Alpha Wings]^7 Wings System interactions created successfully!")
end)

RegisterCommand('testwings', function()
    if IsPoliceOfficer() then
        TriggerEvent('alpha-wings:client:openMenu')
        print("^2[Alpha Wings]^7 Test command executed - opening Wings System menu")
    else
        print("^1[Alpha Wings]^7 Test command failed - not a police officer")
    end
end, false)

RegisterNetEvent('alpha-wings:client:openMenu', function()
    local menuOptions = {
        {
            title = 'View Announcements',
            description = 'View wing announcements',
            event = 'alpha-wings:client:viewAnnouncements'
        }
    }

    TriggerServerEvent('alpha-wings:server:checkWingLeadershipForMenu')

    if IsPoliceChief() then
        table.insert(menuOptions, {
            title = 'Create Wing',
            description = 'Create new wing (Chief Only)',
            event = 'alpha-wings:client:createWings'
        })

        TriggerServerEvent('alpha-wings:server:checkManageWingsAccess')

        table.insert(menuOptions, {
            title = 'Wing Grades Management',
            description = 'Manage wing grades (Chief Only)',
            event = 'alpha-wings:client:wingGradesManagement'
        })

        table.insert(menuOptions, {
            title = 'Chief Management',
            description = 'Advanced chief controls',
            event = 'alpha-wings:client:chiefManagement'
        })
    end

    local dynamicMenu = {
        id = 'wings_system_menu',
        title = 'Wings System',
        position = 'top-right',
        options = menuOptions
    }

    lib.registerContext(dynamicMenu)
    lib.showContext('wings_system_menu')
end)

local globalMenuOptions = {}

RegisterNetEvent('alpha-wings:client:receiveWingLeadershipCheck', function(isLeader, memberInfo)
    if isLeader and memberInfo then
        table.insert(globalMenuOptions, {
            title = 'Wing Management',
            description = 'Manage your wing (Leaders Only)',
            event = 'alpha-wings:client:wingLeadershipMenu',
            args = {
                wingId = memberInfo.wing_id,
                wingName = memberInfo.wing_name
            }
        })
        rebuildMainMenu()
    end
end)

RegisterNetEvent('alpha-wings:client:wingLeadershipMenu', function(data)
    local leadershipMenu = {
        id = 'wing_leadership_main_menu',
        title = 'Wing Management - ' .. (data.wingName or "Unknown Wing"),
        position = 'top-right',
        options = {
            {
                title = 'Manage Members',
                description = 'Add, remove, promote, demote wing members',
                icon = 'users',
                event = 'alpha-wings:client:wingMemberManagement',
                args = data
            },
            {
                title = 'Wing Settings',
                description = 'Update wing description, radio, and settings',
                icon = 'cog',
                event = 'alpha-wings:client:wingSettingsManagement',
                args = data
            },
            {
                title = 'Send Announcement',
                description = 'Send announcement to all wing members',
                icon = 'bullhorn',
                event = 'alpha-wings:client:wingAnnouncementMenu',
                args = data
            },
            {
                title = 'Wing Statistics',
                description = 'View wing statistics and activity',
                icon = 'chart-bar',
                event = 'alpha-wings:client:wingStatisticsMenu',
                args = data
            },
            {
                title = 'Grade Management',
                description = 'Manage wing grades and permissions',
                icon = 'shield-alt',
                event = 'alpha-wings:client:wingGradeManagement',
                args = data
            },
            {
                title = 'Back to Main Menu',
                description = 'Return to Wings System main menu',
                event = 'alpha-wings:client:openMenu'
            }
        }
    }

    lib.registerContext(leadershipMenu)
    lib.showContext('wing_leadership_main_menu')
end)

RegisterNetEvent('alpha-wings:client:wingMemberManagement', function(data)
    local memberManagementMenu = {
        id = 'wing_member_management_menu',
        title = 'Member Management - ' .. (data.wingName or "Unknown Wing"),
        position = 'top-right',
        options = {
            {
                title = 'Add New Member',
                description = 'Add a police officer to your wing',
                icon = 'user-plus',
                event = 'alpha-wings:client:leaderAddMember',
                args = data
            },
            {
                title = 'View All Members',
                description = 'View and manage existing wing members',
                icon = 'users',
                event = 'alpha-wings:client:manageWingMembers',
                args = data
            },
            {
                title = 'Promote/Demote Members',
                description = 'Change member ranks and grades',
                icon = 'arrow-up',
                event = 'alpha-wings:client:memberRankManagement',
                args = data
            },
            {
                title = 'Assign Wing Grades',
                description = 'Assign wing grades to members',
                icon = 'star',
                event = 'alpha-wings:client:leaderAssignGrades',
                args = data
            },
            {
                title = 'Back to Wing Management',
                description = 'Return to wing management menu',
                event = 'alpha-wings:client:wingLeadershipMenu',
                args = data
            }
        }
    }

    lib.registerContext(memberManagementMenu)
    lib.showContext('wing_member_management_menu')
end)

RegisterNetEvent('alpha-wings:client:wingSettingsManagement', function(data)
    local settingsMenu = {
        id = 'wing_settings_management_menu',
        title = 'Wing Settings - ' .. (data.wingName or "Unknown Wing"),
        position = 'top-right',
        options = {
            {
                title = 'Set Radio Frequency',
                description = 'Change wing radio frequency',
                icon = 'radio',
                event = 'alpha-wings:client:setWingRadioFrequency',
                args = data
            },
            {
                title = 'Update Wing Description',
                description = 'Change wing description and information',
                icon = 'edit',
                event = 'alpha-wings:client:updateWingDescription',
                args = data
            },
            {
                title = 'Update Max Members',
                description = 'Change maximum number of wing members',
                icon = 'users-cog',
                event = 'alpha-wings:client:updateMaxMembers',
                args = data
            },
            {
                title = 'Back to Wing Management',
                description = 'Return to wing management menu',
                event = 'alpha-wings:client:wingLeadershipMenu',
                args = data
            }
        }
    }

    lib.registerContext(settingsMenu)
    lib.showContext('wing_settings_management_menu')
end)

RegisterNetEvent('alpha-wings:client:wingAnnouncementMenu', function(data)
    local input = lib.inputDialog('Send Wing Announcement', {
        {type = 'textarea', label = 'Announcement Message', description = 'Message to send to all wing members', required = true, max = 500}
    })

    if not input then return end

    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Announcement message is required!", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:sendWingAnnouncementByLeader', {
        wingId = data.wingId,
        message = input[1]
    })
end)

RegisterNetEvent('alpha-wings:client:wingStatisticsMenu', function(data)
    TriggerServerEvent('alpha-wings:server:getWingStatisticsForLeader', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:wingGradeManagement', function(data)
    TriggerServerEvent('alpha-wings:server:getWingGradePermissions', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:receiveWingStatisticsForLeader', function(stats)
    if not stats then
        QBCore.Functions.Notify("Failed to load wing statistics!", "error")
        return
    end

    local statsMenu = {
        id = 'wing_leader_statistics_menu',
        title = 'Wing Statistics - ' .. (stats.wing_name or "Unknown Wing"),
        position = 'top-right',
        options = {
            {
                title = "Wing Information",
                description = stats.description or "No description",
                disabled = true
            },
            {
                title = "Total Members",
                description = string.format("%d/%d members", stats.active_members or 0, stats.max_members or 0),
                disabled = true
            },
            {
                title = "Leadership Count",
                description = string.format("%d leaders", stats.leaders_count or 0),
                disabled = true
            },
            {
                title = "Total Announcements",
                description = string.format("%d announcements sent", stats.total_announcements or 0),
                disabled = true
            },
            {
                title = "Created Date",
                description = stats.created_at or "Unknown",
                disabled = true
            },
            {
                title = "Created By",
                description = stats.created_by_name or "Unknown",
                disabled = true
            },
            {
                title = "Back to Wing Management",
                description = "Return to wing management menu",
                event = "alpha-wings:client:wingLeadershipMenu",
                args = {
                    wingId = stats.wing_id,
                    wingName = stats.wing_name
                }
            }
        }
    }

    lib.registerContext(statsMenu)
    lib.showContext('wing_leader_statistics_menu')
end)

RegisterNetEvent('alpha-wings:client:receiveWingGradeStatus', function(gradeInfo)
    if not gradeInfo then
        QBCore.Functions.Notify("You are not assigned to any wing!", "info")
        return
    end

    local gradeText = gradeInfo.grade_name and
        string.format("Level %d: %s", gradeInfo.wing_grade_level, gradeInfo.grade_name) or
        "No Grade Assigned"

    local leadershipStatus = (gradeInfo.wing_grade_level >= 5) and "✅ YES (Leader Grade)" or "❌ NO"

    local gradeMenu = {
        id = 'wing_grade_status_menu',
        title = 'Wing Grade Status',
        position = 'top-right',
        options = {
            {
                title = "Wing: " .. gradeInfo.wing_name,
                description = "Your current wing assignment",
                disabled = true
            },
            {
                title = "Wing Grade: " .. gradeText,
                description = "Your current wing grade level",
                disabled = true
            },
            {
                title = "Leadership Access: " .. leadershipStatus,
                description = "Can manage wing (requires Level 5+ Leader grade)",
                disabled = true
            },
            {
                title = "Police Rank: " .. (gradeInfo.police_grade or "Unknown"),
                description = "Your police department rank",
                disabled = true
            },
            {
                title = "ℹ️ Leadership Info",
                description = "Wing leadership is based on wing grade (Level 5+), not police rank",
                disabled = true
            }
        }
    }

    lib.registerContext(gradeMenu)
    lib.showContext('wing_grade_status_menu')
end)

RegisterNetEvent('alpha-wings:client:setWingRadioFrequency', function(data)
    local input = lib.inputDialog('Set Wing Radio Frequency', {
        {
            type = 'input',
            label = 'Radio Frequency',
            description = 'Enter radio frequency (e.g., 123.45)',
            required = true,
            placeholder = '123.45'
        }
    })

    if not input then return end

    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Radio frequency is required!", "error")
        return
    end

    local frequency = input[1]
    if not string.match(frequency, "^%d+%.?%d*$") then
        QBCore.Functions.Notify("Invalid radio frequency format! Use numbers only (e.g., 123.45)", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:setWingRadioByLeader', {
        wingId = data.wingId,
        radioFrequency = frequency
    })
end)

RegisterNetEvent('alpha-wings:client:updateWingDescription', function(data)
    local input = lib.inputDialog('Update Wing Description', {
        {
            type = 'textarea',
            label = 'Wing Description',
            description = 'Enter new wing description',
            required = true,
            max = 500
        }
    })

    if not input then return end

    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Wing description is required!", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:updateWingDescriptionByLeader', {
        wingId = data.wingId,
        description = input[1]
    })
end)

RegisterNetEvent('alpha-wings:client:updateMaxMembers', function(data)
    local input = lib.inputDialog('Update Maximum Members', {
        {
            type = 'number',
            label = 'Maximum Members',
            description = 'Enter maximum number of wing members',
            required = true,
            min = 1,
            max = 50,
            default = 15
        }
    })

    if not input then return end

    if not input[1] or input[1] <= 0 then
        QBCore.Functions.Notify("Maximum members must be a positive number!", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:updateMaxMembersByLeader', {
        wingId = data.wingId,
        maxMembers = input[1]
    })
end)

RegisterNetEvent('alpha-wings:client:receiveManageWingsAccess', function(hasAccess)
    if hasAccess then
        table.insert(globalMenuOptions, {
            title = 'Manage Wings',
            description = 'Manage existing wings (Chief + Creators)',
            event = 'alpha-wings:client:wingsManagement'
        })
        rebuildMainMenu()
    end
end)

function rebuildMainMenu()
    local menuOptions = {
        {
            title = 'View Announcements',
            description = 'View wing announcements',
            event = 'alpha-wings:client:viewAnnouncements'
        }
    }
    
    for _, option in pairs(globalMenuOptions) do
        table.insert(menuOptions, option)
    end

    if IsPoliceChief() then
        table.insert(menuOptions, {
            title = 'Create Wing',
            description = 'Create new wing (Chief Only)',
            event = 'alpha-wings:client:createWings'
        })
        
        table.insert(menuOptions, {
            title = 'Wing Grades Management',
            description = 'Manage wing grades (Chief Only)',
            event = 'alpha-wings:client:wingGradesManagement'
        })
        
        table.insert(menuOptions, {
            title = 'Chief Management',
            description = 'Advanced chief controls',
            event = 'alpha-wings:client:chiefManagement'
        })
    end
    
    local dynamicMenu = {
        id = 'wings_system_menu',
        title = 'Wings System',
        position = 'top-right',
        options = menuOptions
    }
    
    lib.registerContext(dynamicMenu)
    lib.showContext('wings_system_menu')

    globalMenuOptions = {}
end

RegisterNetEvent('alpha-wings:client:createWings', function()
    if not IsPoliceChief() then
        QBCore.Functions.Notify("Access denied. Police Chief authorization required.", "error")
        return
    end
    
    local input = lib.inputDialog('Create New Police Wing', {
        {type = 'input', label = 'Wing Name', description = 'e.g., SWAT, Traffic, Detective', required = true, max = 50},
        {type = 'textarea', label = 'Wing Description', description = 'Wing responsibilities and duties', required = true, max = 500},
        {type = 'number', label = 'Maximum Officers', description = 'Maximum number of officers', required = true, default = Config.WingsSystem.defaultMaxMembers, min = 1, max = 50},
        {type = 'input', label = 'Wing Commander ID', description = 'Player ID of the wing commander', required = true}
    })
    
    if not input then return end

    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Wing name is required!", "error")
        return
    end
    
    if not input[2] or input[2] == '' then
        QBCore.Functions.Notify("Wing description is required!", "error")
        return
    end
    
    if not input[3] or input[3] <= 0 then
        QBCore.Functions.Notify("Max members must be a positive number!", "error")
        return
    end
    
    if not input[4] or input[4] == '' then
        QBCore.Functions.Notify("Wing leader ID is required!", "error")
        return
    end
    
    if not tonumber(input[4]) then
        QBCore.Functions.Notify("Wing leader must be a valid player ID (number)!", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:createWing', {
        name = input[1],
        description = input[2],
        maxMembers = tonumber(input[3]),
        leader = input[4]
    })
end)

RegisterNetEvent('alpha-wings:client:wingsManagement', function()
    if not IsPoliceOfficer() then
        QBCore.Functions.Notify("Access denied. Police personnel only.", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:getAllWings')
end)

RegisterNetEvent('alpha-wings:client:receiveAllWings', function(wingsArray)
    if not wingsArray or #wingsArray == 0 then
        QBCore.Functions.Notify("No wings found!", "error")
        return
    end
    
    local wingsMenu = {
        id = 'wings_management_menu',
        title = 'Wings Management',
        position = 'top-right',
        options = {}
    }
    
    for _, wing in pairs(wingsArray) do
        local currentMembers = wing.current_members or 0
        local maxMembers = wing.max_members or 0
        local leaderName = wing.leader_name or "Unknown"
        
        table.insert(wingsMenu.options, {
            title = wing.name,
            description = string.format("%s | Members: %d/%d | Leader: %s", wing.description, currentMembers, maxMembers, leaderName),
            event = "alpha-wings:client:wingDetails",
            args = {
                wingData = wing
            }
        })
    end
    
    table.insert(wingsMenu.options, {
        title = "Back to Main Menu",
        description = "Return to Wings System",
        event = "alpha-wings:client:openMenu"
    })
    
    lib.registerContext(wingsMenu)
    lib.showContext('wings_management_menu')
end)

RegisterNetEvent('alpha-wings:client:wingDetails', function(data)
    local wing = data.wingData
    local PlayerData = QBCore.Functions.GetPlayerData()
    local isChief = IsPoliceChief()
    
    local detailsMenu = {
        id = 'wing_details_menu',
        title = wing.name,
        position = 'top-right',
        options = {
            {
                title = "Wing Information",
                description = string.format("Description: %s | Leader: %s | Max Members: %d | Current Members: %d | Created: %s", 
                    wing.description, 
                    wing.leader_name or "Unknown", 
                    wing.max_members or 0, 
                    wing.current_members or 0, 
                    wing.created_at or "Unknown"),
                disabled = true
            },
            {
                title = "View Members",
                description = "See all wing members",
                event = "alpha-wings:client:viewWingMembers",
                args = {
                    wingId = wing.id
                }
            }
        }
    }

    if isChief then
        table.insert(detailsMenu.options, {
            title = "Add Member",
            description = "Add officer to this wing",
            event = "alpha-wings:client:addWingMember",
            args = {
                wingId = wing.id,
                wingName = wing.name
            }
        })
        
        table.insert(detailsMenu.options, {
            title = "Remove Member",
            description = "Remove officer from this wing",
            event = "alpha-wings:client:removeWingMember",
            args = {
                wingId = wing.id,
                wingName = wing.name
            }
        })
        
        table.insert(detailsMenu.options, {
            title = "Delete Wing",
            description = "Permanently delete this wing",
            event = "alpha-wings:client:deleteWing",
            args = {
                wingId = wing.id,
                wingName = wing.name
            }
        })
    end
    
    table.insert(detailsMenu.options, {
        title = "Back",
        description = "Return to wings list",
        event = "alpha-wings:client:wingsManagement"
    })
    
    lib.registerContext(detailsMenu)
    lib.showContext('wing_details_menu')
end)

RegisterNetEvent('alpha-wings:client:addWingMember', function(data)
    local input = lib.inputDialog('Add Wing Member', {
        {type = 'input', label = 'Player ID', description = 'ID of the player to add', required = true}
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Player ID is required!", "error")
        return
    end
    
    if not tonumber(input[1]) then
        QBCore.Functions.Notify("Player ID must be a number!", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:addWingMember', {
        wingId = data.wingId,
        playerId = tonumber(input[1])
    })
end)

RegisterNetEvent('alpha-wings:client:removeWingMember', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembersForRemoval', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembersForRemoval', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "info")
        return
    end
    
    local removalMenu = {
        id = 'wing_removal_menu',
        title = 'Remove Wing Member',
        position = 'top-right',
        options = {}
    }
    
    for _, member in pairs(members) do
        local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or string.format("Level %d", member.wing_grade_level)
        table.insert(removalMenu.options, {
            title = member.player_name,
            description = string.format("Grade: %s | Joined: %s", gradeText, member.joined_at),
            event = "alpha-wings:client:confirmRemoveMember",
            args = {
                wingId = wingId,
                citizenid = member.citizenid,
                playerName = member.player_name
            }
        })
    end
    
    if #removalMenu.options == 0 then
        QBCore.Functions.Notify("No removable members found in this wing!", "info")
        return
    end
    
    table.insert(removalMenu.options, {
        title = "Back",
        description = "Return to wings management",
        event = "alpha-wings:client:wingsManagement"
    })
    
    lib.registerContext(removalMenu)
    lib.showContext('wing_removal_menu')
end)

RegisterNetEvent('alpha-wings:client:confirmRemoveMember', function(data)
    local alert = lib.alertDialog({
        header = 'Remove Member',
        content = 'Are you sure you want to remove "' .. data.playerName .. '" from this wing?',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('alpha-wings:server:removeWingMember', {
            wingId = data.wingId,
            citizenid = data.citizenid
        })
    end
end)

RegisterNetEvent('alpha-wings:client:viewWingMembers', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembers', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembers', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "info")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:getWingMembersWithGrades', wingId)
end)

RegisterNetEvent('alpha-wings:client:displayWingMembersWithGrades', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "info")
        return
    end

    local membersMenu = {
        id = 'wing_members_menu',
        title = 'Wing Members',
        position = 'top-right',
        options = {}
    }

    for _, member in pairs(members) do
        local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or "No Grade"

        table.insert(membersMenu.options, {
            title = member.player_name,
            description = string.format("Grade: %s | Rank: %s | Joined: %s", gradeText, member.rank, member.joined_at),
            disabled = true
        })
    end
    
    table.insert(membersMenu.options, {
        title = "Back",
        description = "Return to wings management",
        event = "alpha-wings:client:wingsManagement"
    })
    
    lib.registerContext(membersMenu)
    lib.showContext('wing_members_menu')
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembersForLeaderGrade', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "info")
        return
    end

    local membersMenu = {
        id = 'wing_members_leader_grade_menu',
        title = 'Wing Members (Leader Grade View)',
        position = 'top-right',
        options = {}
    }

    for _, member in pairs(members) do
        local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or "No Grade"
        local isLeader = (member.wing_grade_level >= 4)

        local memberOption = {
            title = member.player_name,
            description = string.format("Grade: %s | Joined: %s", gradeText, member.joined_at)
        }

        memberOption.event = "alpha-wings:client:leaderGradeMemberActions"
        memberOption.args = {
            wingId = wingId,
            member = member
        }

        table.insert(membersMenu.options, memberOption)
    end

    table.insert(membersMenu.options, {
        title = "Back",
        description = "Return to main menu",
        event = "alpha-wings:client:openWingsMenu"
    })

    lib.registerContext(membersMenu)
    lib.showContext('wing_members_leader_grade_menu')
end)

RegisterNetEvent('alpha-wings:client:leaderGradeMemberActions', function(data)
    local member = data.member
    local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or "No Grade"

    local actionsMenu = {
        id = 'leader_grade_member_actions',
        title = 'Member Actions - ' .. member.player_name,
        position = 'top-right',
        options = {
            {
                title = "Current Grade",
                description = gradeText,
                disabled = true
            },
            {
                title = "Assign Grade",
                description = "Change member's wing grade",
                event = "alpha-wings:client:assignMemberGradeAsLeader",
                args = {
                    wingId = data.wingId,
                    citizenid = member.citizenid,
                    memberName = member.player_name,
                    currentGrade = member.wing_grade_level
                }
            },
            {
                title = "Remove Member",
                description = "Remove this member from the wing",
                event = "alpha-wings:client:removeMemberAsLeader",
                args = {
                    wingId = data.wingId,
                    citizenid = member.citizenid,
                    memberName = member.player_name
                }
            },
            {
                title = "Back",
                description = "Return to members list",
                event = "alpha-wings:client:viewWingMembersForLeaderGrade",
                args = {
                    wingId = data.wingId
                }
            }
        }
    }

    lib.registerContext(actionsMenu)
    lib.showContext('leader_grade_member_actions')
end)

RegisterNetEvent('alpha-wings:client:viewWingMembersForLeaderGrade', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembersForLeaderGrade', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:deleteWing', function(data)
    local alert = lib.alertDialog({
        header = 'Delete Wing',
        content = 'Are you sure you want to delete "' .. data.wingName .. '"? This action cannot be undone.',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('alpha-wings:server:deleteWing', data.wingId)
    end
end)

RegisterNetEvent('alpha-wings:client:wingCreated', function(wingData)
    QBCore.Functions.Notify("Wing '" .. wingData.name .. "' created successfully!", "success")
end)

RegisterNetEvent('alpha-wings:client:wingDeleted', function(wingId)
    QBCore.Functions.Notify("Wing deleted successfully!", "success")
end)

RegisterNetEvent('alpha-wings:client:receivePlayerWingInfo', function(wingData)
    if not wingData then
        lib.alertDialog({
            header = 'Wing Information',
            content = 'You are not assigned to any police wing.',
            centered = true
        })
        return
    end
    
    local wingInfoMenu = {
        id = 'player_wing_info',
        title = 'My Wing Information',
        position = 'top-right',
        options = {
            {
                title = "Wing Name",
                description = wingData.wingName,
                disabled = true
            },
            {
                title = "Your Police Grade",
                description = wingData.playerGrade,
                disabled = true
            },
            {
                title = "Your Wing Grade",
                description = wingData.wingGrade or "No Wing Grade",
                disabled = true
            },
            {
                title = "Wing Radio",
                description = wingData.wingRadio,
                disabled = true
            },
            {
                title = "Wing Leader",
                description = wingData.wingLeader,
                disabled = true
            }
        }
    }
    
    if wingData.isLeader then
        table.insert(wingInfoMenu.options, {
            title = "── Leader Controls ──",
            description = "Wing management options",
            disabled = true
        })
        
        table.insert(wingInfoMenu.options, {
            title = "Set Wing Radio",
            description = "Change wing radio frequency",
            event = "alpha-wings:client:setWingRadio",
            args = {
                wingId = wingData.wingId,
                currentRadio = wingData.wingRadio
            }
        })
        
        table.insert(wingInfoMenu.options, {
            title = "View Wing Members",
            description = "See all wing members",
            event = "alpha-wings:client:viewWingMembersAsLeader",
            args = {
                wingId = wingData.wingId
            }
        })
        
        table.insert(wingInfoMenu.options, {
            title = "Wing Management",
            description = "Advanced wing controls",
            event = "alpha-wings:client:wingLeaderManagement",
            args = {
                wingId = wingData.wingId,
                wingName = wingData.wingName
            }
        })
    end
    
    table.insert(wingInfoMenu.options, {
        title = "── System Access ──",
        description = "Wings System options",
        disabled = true
    })
    
    table.insert(wingInfoMenu.options, {
        title = "Open Wings System",
        description = "Access Wings System menu",
        event = "alpha-wings:client:openMenu"
    })
    
    lib.registerContext(wingInfoMenu)
    lib.showContext('player_wing_info')
end)

RegisterNetEvent('alpha-wings:client:setWingRadio', function(data)
    local input = lib.inputDialog('Set Wing Radio Frequency', {
        {
            type = 'input', 
            label = 'Radio Frequency', 
            description = 'Enter radio frequency (e.g., 123.45)', 
            required = true, 
            default = data.currentRadio ~= "Not Set" and data.currentRadio or ""
        }
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Radio frequency is required!", "error")
        return
    end
    
    local frequency = input[1]
    if not string.match(frequency, "^%d+%.?%d*$") then
        QBCore.Functions.Notify("Invalid radio frequency format! Use numbers only (e.g., 123.45)", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:setWingRadio', {
        wingId = data.wingId,
        radioFrequency = frequency
    })
end)

RegisterNetEvent('alpha-wings:client:viewWingMembersAsLeader', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembersAsLeader', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembersAsLeader', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "info")
        return
    end
    
    local membersMenu = {
        id = 'wing_members_leader_menu',
        title = 'Wing Members (Leader View)',
        position = 'top-right',
        options = {}
    }
    
    for _, member in pairs(members) do
        local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or string.format("Level %d", member.wing_grade_level)
        local memberOption = {
            title = member.player_name,
            description = string.format("Grade: %s | Joined: %s", gradeText, member.joined_at)
        }
        table.insert(membersMenu.options, memberOption)
    end
    
    table.insert(membersMenu.options, {
        title = "Back to Wing Info",
        description = "Return to wing information",
        onSelect = function()
            ExecuteCommand('wing')
        end
    })
    
    lib.registerContext(membersMenu)
    lib.showContext('wing_members_leader_menu')
end)

RegisterNetEvent('alpha-wings:client:leaderRemoveMember', function(data)
    local alert = lib.alertDialog({
        header = 'Remove Member',
        content = 'Are you sure you want to remove "' .. data.playerName .. '" from your wing?',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('alpha-wings:server:leaderRemoveWingMember', {
            wingId = data.wingId,
            citizenid = data.citizenid
        })
    end
end)

RegisterNetEvent('alpha-wings:client:wingLeaderManagement', function(data)
    local managementMenu = {
        id = 'wing_leader_management',
        title = 'Wing Management - ' .. data.wingName,
        position = 'top-right',
        options = {
            {
                title = "Add Member",
                description = "Add a police officer to your wing",
                event = "alpha-wings:client:leaderAddMember",
                args = {
                    wingId = data.wingId,
                    wingName = data.wingName
                }
            },
            {
                title = "Manage Members",
                description = "View, promote, demote, or remove members",
                event = "alpha-wings:client:manageWingMembers",
                args = {
                    wingId = data.wingId,
                    wingName = data.wingName
                }
            },
            {
                title = "Assign Member Grades",
                description = "Assign wing grades to members",
                event = "alpha-wings:client:leaderAssignGrades",
                args = {
                    wingId = data.wingId,
                    wingName = data.wingName
                }
            },
            {
                title = "Wing Statistics",
                description = "View wing statistics and information",
                event = "alpha-wings:client:wingStatistics",
                args = {
                    wingId = data.wingId
                }
            },
            {
                title = "Transfer Leadership",
                description = "Transfer wing leadership to another member",
                event = "alpha-wings:client:transferLeadership",
                args = {
                    wingId = data.wingId,
                    wingName = data.wingName
                }
            },
            {
                title = "Send Announcement",
                description = "Send a message to all wing members",
                event = "alpha-wings:client:sendWingAnnouncement",
                args = {
                    wingId = data.wingId,
                    wingName = data.wingName
                }
            },
            {
                title = "Back to Wing Info",
                description = "Return to wing information",
                onSelect = function()
                    ExecuteCommand('wing')
                end
            }
        }
    }
    
    lib.registerContext(managementMenu)
    lib.showContext('wing_leader_management')
end)

RegisterNetEvent('alpha-wings:client:leaderAddMember', function(data)
    local input = lib.inputDialog('Add Wing Member', {
        {type = 'input', label = 'Player ID', description = 'ID of the player to add', required = true}
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Player ID is required!", "error")
        return
    end
    
    if not tonumber(input[1]) then
        QBCore.Functions.Notify("Player ID must be a number!", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:leaderAddWingMember', {
        wingId = data.wingId,
        playerId = tonumber(input[1])
    })
end)

RegisterNetEvent('alpha-wings:client:wingStatistics', function(data)
    TriggerServerEvent('alpha-wings:server:getWingStatistics', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:receiveWingStatistics', function(stats)
    if not stats then
        QBCore.Functions.Notify("Failed to load wing statistics!", "error")
        return
    end
    
    local statsMenu = {
        id = 'wing_statistics',
        title = 'Wing Statistics',
        position = 'top-right',
        options = {
            {
                title = "Total Members",
                description = tostring(stats.totalMembers),
                disabled = true
            },
            {
                title = "Active Members",
                description = tostring(stats.activeMembers),
                disabled = true
            },
            {
                title = "Wing Created",
                description = stats.createdAt,
                disabled = true
            },
            {
                title = "Created By",
                description = stats.createdBy,
                disabled = true
            },
            {
                title = "Back",
                description = "Return to wing management",
                onSelect = function()
                    ExecuteCommand('wing')
                end
            }
        }
    }
    
    lib.registerContext(statsMenu)
    lib.showContext('wing_statistics')
end)

RegisterNetEvent('alpha-wings:client:manageMember', function(data)
    local manageMemberMenu = {
        id = 'manage_member_menu',
        title = 'Manage Member - ' .. data.playerName,
        position = 'top-right',
        options = {
            {
                title = "Change Grade",
                description = "Change this member's wing grade level",
                event = "alpha-wings:client:changeMemberGrade",
                args = data
            },
            {
                title = "Remove Member",
                description = "Remove this member from the wing",
                event = "alpha-wings:client:leaderRemoveMember",
                args = data
            },
            {
                title = "Back",
                description = "Return to members list",
                event = "alpha-wings:client:viewWingMembersAsLeader",
                args = {
                    wingId = data.wingId
                }
            }
        }
    }

    lib.registerContext(manageMemberMenu)
    lib.showContext('manage_member_menu')
end)

RegisterNetEvent('alpha-wings:client:changeMemberGrade', function(data)
    local input = lib.inputDialog('Change Member Grade', {
        {
            type = 'number',
            label = 'New Grade Level',
            description = 'Enter the new grade level for this member (0-5)',
            required = true,
            default = data.currentGrade or 0,
            min = 0,
            max = 5
        }
    })

    if not input then return end

    if input[1] == data.currentGrade then
        QBCore.Functions.Notify("Member already has this grade level!", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:changeMemberGrade', {
        wingId = data.wingId,
        citizenid = data.citizenid,
        newGrade = input[1],
        memberName = data.memberName
    })
end)

RegisterNetEvent('alpha-wings:client:transferLeadership', function(data)
    TriggerServerEvent('alpha-wings:server:requestTransferLeadershipMembers', data.wingId)
    _G.transferData = data
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembersForTransfer', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found to transfer leadership to!", "info")
        return
    end
    
    local transferMenu = {
        id = 'transfer_leadership_menu',
        title = 'Transfer Leadership',
        position = 'top-right',
        options = {}
    }
    
    for _, member in pairs(members) do
        if member.wing_grade_level < 5 then
            local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or string.format("Level %d", member.wing_grade_level)
            table.insert(transferMenu.options, {
                title = member.player_name,
                description = string.format("Current Grade: %s | Joined: %s", gradeText, member.joined_at),
                event = "alpha-wings:client:confirmTransferLeadership",
                args = {
                    wingId = wingId,
                    newLeaderCitizenId = member.citizenid,
                    newLeaderName = member.player_name
                }
            })
        end
    end
    
    if #transferMenu.options == 0 then
        QBCore.Functions.Notify("No eligible members found for leadership transfer!", "info")
        return
    end
    
    table.insert(transferMenu.options, {
        title = "Cancel",
        description = "Cancel leadership transfer",
        event = "alpha-wings:client:wingLeaderManagement",
        args = _G.transferData
    })
    
    lib.registerContext(transferMenu)
    lib.showContext('transfer_leadership_menu')
end)

RegisterNetEvent('alpha-wings:client:confirmTransferLeadership', function(data)
    local alert = lib.alertDialog({
        header = 'Transfer Leadership',
        content = 'Are you sure you want to transfer wing leadership to "' .. data.newLeaderName .. '"? This action cannot be undone.',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('alpha-wings:server:transferLeadership', {
            wingId = data.wingId,
            newLeaderCitizenId = data.newLeaderCitizenId
        })
    end
end)

RegisterNetEvent('alpha-wings:client:wingGradesManagement', function()
    if not IsPoliceChief() then
        QBCore.Functions.Notify("Access denied. Police Chief authorization required.", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:getAllWingsForGrades')
end)

RegisterNetEvent('alpha-wings:client:receiveAllWingsForGrades', function(wingsArray)
    if not wingsArray or #wingsArray == 0 then
        QBCore.Functions.Notify("No wings found!", "error")
        return
    end
    
    local wingsMenu = {
        id = 'wings_grades_selection_menu',
        title = 'Select Wing for Grade Management',
        position = 'top-right',
        options = {}
    }
    
    for _, wing in pairs(wingsArray) do
        table.insert(wingsMenu.options, {
            title = wing.name,
            description = string.format("Members: %d/%d | Leader: %s", 
                wing.current_members or 0, 
                wing.max_members or 0, 
                wing.leader_name or "Unknown"
            ),
            event = "alpha-wings:client:manageWingGrades",
            args = {
                wingId = wing.id,
                wingName = wing.name
            }
        })
    end
    
    table.insert(wingsMenu.options, {
        title = "Back to Main Menu",
        description = "Return to Wings System",
        event = "alpha-wings:client:openMenu"
    })
    
    lib.registerContext(wingsMenu)
    lib.showContext('wings_grades_selection_menu')
end)

RegisterNetEvent('alpha-wings:client:manageWingGrades', function(data)
    TriggerServerEvent('alpha-wings:server:getWingGrades', data.wingId)
    _G.currentWingData = data
end)

RegisterNetEvent('alpha-wings:client:receiveWingGrades', function(grades, wingId)
    local wingData = _G.currentWingData
    
    local gradesMenu = {
        id = 'wing_grades_menu',
        title = 'Wing Grades - ' .. (wingData and wingData.wingName or "Unknown"),
        position = 'top-right',
        options = {
            {
                title = "Create New Grade",
                description = "Add a new grade to this wing",
                event = "alpha-wings:client:createWingGrade",
                args = {
                    wingId = wingId,
                    wingName = wingData and wingData.wingName or "Unknown"
                }
            },
            {
                title = "Assign Member Grades",
                description = "Assign grades to wing members",
                event = "alpha-wings:client:assignMemberGrades",
                args = {
                    wingId = wingId,
                    wingName = wingData and wingData.wingName or "Unknown"
                }
            }
        }
    }
    
    if grades and #grades > 0 then
        table.insert(gradesMenu.options, {
            title = "── Current Grades ──",
            description = "Existing wing grades",
            disabled = true
        })
        
        for _, grade in pairs(grades) do
            table.insert(gradesMenu.options, {
                title = string.format("Level %d: %s", grade.grade_level, grade.grade_name),
                description = grade.grade_description or "No description",
                event = "alpha-wings:client:editWingGrade",
                args = {
                    gradeId = grade.id,
                    wingId = wingId,
                    gradeName = grade.grade_name,
                    gradeLevel = grade.grade_level,
                    gradeDescription = grade.grade_description
                }
            })
        end
    else
        table.insert(gradesMenu.options, {
            title = "No grades found",
            description = "This wing has no custom grades",
            disabled = true
        })
    end
    
    table.insert(gradesMenu.options, {
        title = "Back",
        description = "Return to wing selection",
        event = "alpha-wings:client:wingGradesManagement"
    })
    
    lib.registerContext(gradesMenu)
    lib.showContext('wing_grades_menu')
end)

RegisterNetEvent('alpha-wings:client:createWingGrade', function(data)
    local input = lib.inputDialog('Create Wing Grade', {
        {type = 'input', label = 'Grade Name', description = 'e.g., Senior Detective, SWAT Officer', required = true, max = 50},
        {type = 'number', label = 'Grade Level', description = 'Grade level (0-10)', required = true, min = 0, max = 10},
        {type = 'textarea', label = 'Description', description = 'Grade description and responsibilities', max = 200}
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Grade name is required!", "error")
        return
    end
    
    if not input[2] or input[2] < 0 or input[2] > 10 then
        QBCore.Functions.Notify("Grade level must be between 0 and 10!", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:createWingGrade', {
        wingId = data.wingId,
        name = input[1],
        level = input[2],
        description = input[3] or ""
    })
end)

RegisterNetEvent('alpha-wings:client:editWingGrade', function(data)
    local editMenu = {
        id = 'edit_wing_grade_menu',
        title = 'Edit Grade - ' .. data.gradeName,
        position = 'top-right',
        options = {
            {
                title = "Edit Grade Details",
                description = "Modify grade name, level, or description",
                event = "alpha-wings:client:editGradeDetails",
                args = data
            },
            {
                title = "Delete Grade",
                description = "Remove this grade from the wing",
                event = "alpha-wings:client:deleteWingGrade",
                args = data
            },
            {
                title = "Back",
                description = "Return to grades list",
                event = "alpha-wings:client:manageWingGrades",
                args = {
                    wingId = data.wingId
                }
            }
        }
    }
    
    lib.registerContext(editMenu)
    lib.showContext('edit_wing_grade_menu')
end)

RegisterNetEvent('alpha-wings:client:editGradeDetails', function(data)
    local input = lib.inputDialog('Edit Wing Grade', {
        {type = 'input', label = 'Grade Name', description = 'Grade name', required = true, default = data.gradeName, max = 50},
        {type = 'number', label = 'Grade Level', description = 'Grade level (0-10)', required = true, default = data.gradeLevel, min = 0, max = 10},
        {type = 'textarea', label = 'Description', description = 'Grade description', default = data.gradeDescription or "", max = 200}
    })
    
    if not input then return end
    
    TriggerServerEvent('alpha-wings:server:updateWingGrade', {
        gradeId = data.gradeId,
        name = input[1],
        level = input[2],
        description = input[3]
    })
end)

RegisterNetEvent('alpha-wings:client:deleteWingGrade', function(data)
    local alert = lib.alertDialog({
        header = 'Delete Wing Grade',
        content = 'Are you sure you want to delete the grade "' .. data.gradeName .. '"? This action cannot be undone.',
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('alpha-wings:server:deleteWingGrade', data.gradeId)
    end
end)

RegisterNetEvent('alpha-wings:client:assignMemberGrades', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembersWithGrades', data.wingId)
    _G.currentWingForGrades = data
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembersWithGrades', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "info")
        return
    end
    
    local wingData = _G.currentWingForGrades
    
    local membersMenu = {
        id = 'wing_members_grades_menu',
        title = 'Assign Member Grades - ' .. (wingData and wingData.wingName or "Unknown"),
        position = 'top-right',
        options = {}
    }
    
    for _, member in pairs(members) do
        local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or "No Grade"
        
        table.insert(membersMenu.options, {
            title = member.player_name,
            description = string.format("Current Grade: %s | Rank: %s", gradeText, member.rank),
            event = "alpha-wings:client:selectMemberGrade",
            args = {
                wingId = wingId,
                citizenid = member.citizenid,
                playerName = member.player_name,
                currentGradeLevel = member.wing_grade_level
            }
        })
    end
    
    table.insert(membersMenu.options, {
        title = "Back",
        description = "Return to grades management",
        event = "alpha-wings:client:manageWingGrades",
        args = {
            wingId = wingId,
            wingName = wingData and wingData.wingName or "Unknown"
        }
    })
    
    lib.registerContext(membersMenu)
    lib.showContext('wing_members_grades_menu')
end)

RegisterNetEvent('alpha-wings:client:selectMemberGrade', function(data)
    TriggerServerEvent('alpha-wings:server:getWingGradesForAssignment', data.wingId)
    _G.memberForGradeAssignment = data
end)

RegisterNetEvent('alpha-wings:client:receiveWingGradesForAssignment', function(grades, wingId)
    local memberData = _G.memberForGradeAssignment
    
    if not grades or #grades == 0 then
        QBCore.Functions.Notify("No grades available for this wing!", "error")
        return
    end
    
    local gradeOptions = {}
    for _, grade in pairs(grades) do
        table.insert(gradeOptions, {
            value = grade.grade_level,
            label = string.format("Level %d: %s", grade.grade_level, grade.grade_name)
        })
    end
    
    local input = lib.inputDialog('Assign Member Grade', {
        {
            type = 'select',
            label = 'Select Grade',
            description = 'Choose a grade for ' .. memberData.playerName,
            required = true,
            default = memberData.currentGradeLevel,
            options = gradeOptions
        }
    })
    
    if not input then return end
    
    if input[1] == memberData.currentGradeLevel then
        QBCore.Functions.Notify("Member already has this grade!", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:assignMemberGrade', {
        wingId = memberData.wingId,
        citizenid = memberData.citizenid,
        gradeLevel = input[1]
    })
end)

RegisterNetEvent('alpha-wings:client:sendWingAnnouncement', function(data)
    local input = lib.inputDialog('Send Wing Announcement', {
        {type = 'textarea', label = 'Announcement Message', description = 'Message to send to all wing members', required = true, max = 500}
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Announcement message is required!", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:sendWingAnnouncement', {
        wingId = data.wingId,
        message = input[1]
    })
end)

RegisterNetEvent('alpha-wings:client:receiveWingAnnouncement', function(data)
    lib.alertDialog({
        header = 'Wing Announcement - ' .. data.wingName,
        content = string.format("From: %s\n\n%s", data.senderName, data.message),
        centered = true
    })
end)

RegisterCommand('wings', function()
    if not HasWingsViewPermission() then
        QBCore.Functions.Notify("Access denied. Insufficient permissions to view wings information.", "error")
        return
    end

    TriggerEvent('alpha-wings:client:showWingsInformation')
end, false)

RegisterCommand('testwings', function()
    if not HasWingsViewPermission() then
        QBCore.Functions.Notify("Access denied. Insufficient permissions to view wings information.", "error")
        return
    end

    TriggerEvent('alpha-wings:client:showWingsInformation')
end, false)

RegisterCommand('wingsadmin', function()
    if Config.WingsSystem.readOnlyMode then
        QBCore.Functions.Notify("Wings management is disabled. System is in read-only mode.", "error")
        return
    end

    if not IsPoliceChief() then
        QBCore.Functions.Notify("Access denied. Police Chief authorization required.", "error")
        return
    end

    QBCore.Functions.Notify("Wings management is disabled. System is in read-only mode.", "error")
end, false)

RegisterNetEvent('alpha-wings:client:memberRankManagement', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembersForRankManagement', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembersForRankManagement', function(members, wingId)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "error")
        return
    end

    local rankManagementMenu = {
        id = 'wing_rank_management_menu',
        title = 'Member Rank Management',
        position = 'top-right',
        options = {}
    }

    for _, member in pairs(members) do
        if member.wing_grade_level < 5 then
            local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or string.format("Level %d", member.wing_grade_level)

            table.insert(rankManagementMenu.options, {
                title = member.player_name,
                description = string.format("Current Grade: %s", gradeText),
                event = "alpha-wings:client:changeSpecificMemberGrade",
                args = {
                    wingId = wingId,
                    citizenid = member.citizenid,
                    playerName = member.player_name,
                    currentGrade = member.wing_grade_level
                }
            })
        end
    end

    if #rankManagementMenu.options == 0 then
        QBCore.Functions.Notify("No members available for grade management!", "info")
        return
    end

    table.insert(rankManagementMenu.options, {
        title = "Back to Member Management",
        description = "Return to member management menu",
        event = "alpha-wings:client:wingMemberManagement",
        args = {
            wingId = wingId
        }
    })

    lib.registerContext(rankManagementMenu)
    lib.showContext('wing_grade_management_menu')
end)

RegisterNetEvent('alpha-wings:client:changeSpecificMemberGrade', function(data)
    local input = lib.inputDialog('Change Member Grade - ' .. data.playerName, {
        {
            type = 'number',
            label = 'New Grade Level',
            description = 'Enter new grade level for member (0-5)',
            required = true,
            default = data.currentGrade or 0,
            min = 0,
            max = 5
        }
    })

    if not input then return end

    if input[1] == data.currentGrade then
        QBCore.Functions.Notify("Member already has this grade level!", "info")
        return
    end

    TriggerServerEvent('alpha-wings:server:updateMemberGradeByLeader', {
        wingId = data.wingId,
        citizenid = data.citizenid,
        newGrade = input[1],
        memberName = data.playerName
    })
end)

RegisterNetEvent('alpha-wings:client:manageWingMembers', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembersForLeader', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:receiveWingMembersForLeader', function(members, wingId, wingName)
    if not members or #members == 0 then
        QBCore.Functions.Notify("No members found in this wing!", "info")
        return
    end
    
    local membersMenu = {
        id = 'leader_manage_members',
        title = 'Manage Members - ' .. wingName,
        position = 'top-right',
        options = {}
    }
    
    for _, member in pairs(members) do
        local gradeText = member.grade_name and string.format("Level %d: %s", member.wing_grade_level, member.grade_name) or "No Grade"
        local isLeader = (member.wing_grade_level >= 5)
        
        table.insert(membersMenu.options, {
            title = member.player_name,
            description = string.format("Grade: %s | Joined: %s", gradeText, member.joined_at),
            event = "alpha-wings:client:memberActions",
            args = {
                wingId = wingId,
                wingName = wingName,
                member = member,
                isLeader = isLeader
            }
        })
    end
    
    table.insert(membersMenu.options, {
        title = "Back to Management",
        description = "Return to wing management",
        event = "alpha-wings:client:wingLeaderManagement",
        args = {
            wingId = wingId,
            wingName = wingName
        }
    })
    
    lib.registerContext(membersMenu)
    lib.showContext('leader_manage_members')
end)

RegisterNetEvent('alpha-wings:client:memberActions', function(data)
    local member = data.member
    local isCurrentLeader = (member.wing_grade_level >= 5)

    local actionsMenu = {
        id = 'member_actions',
        title = 'Manage: ' .. member.player_name,
        position = 'top-right',
        options = {}
    }
    
    if not isCurrentLeader then
        table.insert(actionsMenu.options, {
            title = "Promote to Senior",
            description = "Promote member to Senior rank",
            event = "alpha-wings:client:promoteMember",
            args = {
                wingId = data.wingId,
                citizenid = member.citizenid,
                memberName = member.player_name,
                newRank = "Senior"
            }
        })
        
        table.insert(actionsMenu.options, {
            title = "Promote to Supervisor",
            description = "Promote member to Supervisor rank",
            event = "alpha-wings:client:promoteMember",
            args = {
                wingId = data.wingId,
                citizenid = member.citizenid,
                memberName = member.player_name,
                newRank = "Supervisor"
            }
        })
        
        table.insert(actionsMenu.options, {
            title = "Demote to Member",
            description = "Demote to regular Member rank",
            event = "alpha-wings:client:promoteMember",
            args = {
                wingId = data.wingId,
                citizenid = member.citizenid,
                memberName = member.player_name,
                newRank = "Member"
            }
        })
        
        table.insert(actionsMenu.options, {
            title = "Assign Wing Grade",
            description = "Change member's wing grade",
            event = "alpha-wings:client:assignMemberGradeAsLeader",
            args = {
                wingId = data.wingId,
                citizenid = member.citizenid,
                memberName = member.player_name
            }
        })
        
        table.insert(actionsMenu.options, {
            title = "Remove from Wing",
            description = "Remove member from wing",
            event = "alpha-wings:client:removeMemberAsLeader",
            args = {
                wingId = data.wingId,
                citizenid = member.citizenid,
                memberName = member.player_name
            }
        })
    else
        table.insert(actionsMenu.options, {
            title = "Cannot Manage",
            description = "Cannot manage other leaders",
            disabled = true
        })
    end
    
    table.insert(actionsMenu.options, {
        title = "Back to Members",
        description = "Return to member list",
        event = "alpha-wings:client:manageWingMembers",
        args = {
            wingId = data.wingId,
            wingName = data.wingName
        }
    })
    
    lib.registerContext(actionsMenu)
    lib.showContext('member_actions')
end)

RegisterNetEvent('alpha-wings:client:promoteMember', function(data)
    local alert = lib.alertDialog({
        header = 'Confirm Grade Change',
        content = string.format("Are you sure you want to change %s's grade to level %d?", data.memberName, data.newGrade),
        centered = true,
        cancel = true
    })

    if alert == 'confirm' then
        TriggerServerEvent('alpha-wings:server:updateMemberGrade', {
            wingId = data.wingId,
            citizenid = data.citizenid,
            newGrade = data.newGrade,
            memberName = data.memberName
        })
    end
end)

RegisterNetEvent('alpha-wings:client:removeMemberAsLeader', function(data)
    local alert = lib.alertDialog({
        header = 'Confirm Member Removal',
        content = string.format("Are you sure you want to remove %s from the wing?", data.memberName),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        TriggerServerEvent('alpha-wings:server:removeMemberAsLeader', {
            wingId = data.wingId,
            citizenid = data.citizenid,
            memberName = data.memberName
        })
    end
end)

RegisterNetEvent('alpha-wings:client:leaderAssignGrades', function(data)
    TriggerServerEvent('alpha-wings:server:getWingMembersForGradeAssignment', data.wingId)
end)

RegisterNetEvent('alpha-wings:client:assignMemberGradeAsLeader', function(data)
    TriggerServerEvent('alpha-wings:server:getWingGradesForLeader', data.wingId, data.citizenid, data.memberName)
end)

RegisterNetEvent('alpha-wings:client:receiveWingGradesForLeader', function(grades, wingId, citizenid, memberName)
    if not grades or #grades == 0 then
        QBCore.Functions.Notify("No grades found for this wing!", "error")
        return
    end
    
    local gradeOptions = {}
    for _, grade in pairs(grades) do
        table.insert(gradeOptions, {
            value = grade.grade_level,
            label = string.format("Level %d: %s", grade.grade_level, grade.grade_name)
        })
    end
    
    local input = lib.inputDialog('Assign Wing Grade to ' .. memberName, {
        {type = 'select', label = 'Wing Grade', description = 'Select wing grade level', required = true, options = gradeOptions}
    })
    
    if not input then return end
    
    TriggerServerEvent('alpha-wings:server:assignMemberGradeAsLeader', {
        wingId = wingId,
        citizenid = citizenid,
        gradeLevel = input[1],
        memberName = memberName
    })
end)

RegisterNetEvent('alpha-wings:client:chiefManagement', function()
    if not IsPoliceChief() then
        QBCore.Functions.Notify("Access denied. Police Chief authorization required.", "error")
        return
    end
    
    local chiefMenu = {
        id = 'chief_management_menu',
        title = 'Chief Management',
        position = 'top-right',
        options = {
            {
                title = 'Set Wing Radio',
                description = 'Set radio frequency for any wing',
                event = 'alpha-wings:client:chiefSetWingRadio'
            },
            {
                title = 'Send Announcements',
                description = 'Send announcements to any wing',
                event = 'alpha-wings:client:chiefSendAnnouncement'
            },
            {
                title = 'View Wing Statistics',
                description = 'View statistics for all wings',
                event = 'alpha-wings:client:chiefViewStatistics'
            },
            {
                title = 'Back to Main Menu',
                description = 'Return to Wings System',
                event = 'alpha-wings:client:openMenu'
            }
        }
    }
    
    lib.registerContext(chiefMenu)
    lib.showContext('chief_management_menu')
end)

RegisterNetEvent('alpha-wings:client:chiefSetWingRadio', function()
    TriggerServerEvent('alpha-wings:server:getAllWingsForChief')
end)

RegisterNetEvent('alpha-wings:client:receiveAllWingsForChiefRadio', function(wingsArray)
    if not wingsArray or #wingsArray == 0 then
        QBCore.Functions.Notify("No wings found!", "error")
        return
    end
    
    local wingsMenu = {
        id = 'chief_radio_wings_menu',
        title = 'Select Wing for Radio Setting',
        position = 'top-right',
        options = {}
    }
    
    for _, wing in pairs(wingsArray) do
        table.insert(wingsMenu.options, {
            title = wing.name,
            description = string.format("Current Radio: %s | Leader: %s", 
                wing.radio_frequency or "Not Set", 
                wing.leader_name or "Unknown"
            ),
            event = "alpha-wings:client:chiefSetSpecificWingRadio",
            args = {
                wingId = wing.id,
                wingName = wing.name,
                currentRadio = wing.radio_frequency
            }
        })
    end
    
    table.insert(wingsMenu.options, {
        title = "Back",
        description = "Return to Chief Management",
        event = "alpha-wings:client:chiefManagement"
    })
    
    lib.registerContext(wingsMenu)
    lib.showContext('chief_radio_wings_menu')
end)

RegisterNetEvent('alpha-wings:client:chiefSetSpecificWingRadio', function(data)
    local input = lib.inputDialog('Set Wing Radio Frequency - ' .. data.wingName, {
        {
            type = 'input', 
            label = 'Radio Frequency', 
            description = 'Enter radio frequency (e.g., 123.45)', 
            required = true, 
            default = data.currentRadio ~= "Not Set" and data.currentRadio or ""
        }
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Radio frequency is required!", "error")
        return
    end
    
    local frequency = input[1]
    if not string.match(frequency, "^%d+%.?%d*$") then
        QBCore.Functions.Notify("Invalid radio frequency format! Use numbers only (e.g., 123.45)", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:chiefSetWingRadio', {
        wingId = data.wingId,
        radioFrequency = frequency,
        wingName = data.wingName
    })
end)

RegisterNetEvent('alpha-wings:client:chiefSendAnnouncement', function()
    TriggerServerEvent('alpha-wings:server:getAllWingsForChief')
end)

RegisterNetEvent('alpha-wings:client:receiveAllWingsForChiefAnnouncement', function(wingsArray)
    if not wingsArray or #wingsArray == 0 then
        QBCore.Functions.Notify("No wings found!", "error")
        return
    end
    
    local wingsMenu = {
        id = 'chief_announcement_wings_menu',
        title = 'Select Wing for Announcement',
        position = 'top-right',
        options = {}
    }
    
    for _, wing in pairs(wingsArray) do
        table.insert(wingsMenu.options, {
            title = wing.name,
            description = string.format("Members: %d/%d | Leader: %s", 
                wing.current_members or 0, 
                wing.max_members or 0, 
                wing.leader_name or "Unknown"
            ),
            event = "alpha-wings:client:chiefSendSpecificWingAnnouncement",
            args = {
                wingId = wing.id,
                wingName = wing.name
            }
        })
    end
    
    table.insert(wingsMenu.options, {
        title = "Send to All Wings",
        description = "Send announcement to all wings",
        event = "alpha-wings:client:chiefSendAllWingsAnnouncement"
    })
    
    table.insert(wingsMenu.options, {
        title = "Back",
        description = "Return to Chief Management",
        event = "alpha-wings:client:chiefManagement"
    })
    
    lib.registerContext(wingsMenu)
    lib.showContext('chief_announcement_wings_menu')
end)

RegisterNetEvent('alpha-wings:client:chiefSendSpecificWingAnnouncement', function(data)
    local input = lib.inputDialog('Send Announcement to ' .. data.wingName, {
        {type = 'textarea', label = 'Announcement Message', description = 'Message to send to wing members', required = true, max = 500}
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Announcement message is required!", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:chiefSendWingAnnouncement', {
        wingId = data.wingId,
        wingName = data.wingName,
        message = input[1]
    })
end)

RegisterNetEvent('alpha-wings:client:chiefSendAllWingsAnnouncement', function()
    local input = lib.inputDialog('Send Announcement to All Wings', {
        {type = 'textarea', label = 'Announcement Message', description = 'Message to send to all wing members', required = true, max = 500}
    })
    
    if not input then return end
    
    if not input[1] or input[1] == '' then
        QBCore.Functions.Notify("Announcement message is required!", "error")
        return
    end
    
    TriggerServerEvent('alpha-wings:server:chiefSendAllWingsAnnouncement', {
        message = input[1]
    })
end)

RegisterNetEvent('alpha-wings:client:chiefViewStatistics', function()
    TriggerServerEvent('alpha-wings:server:getChiefStatistics')
end)

RegisterNetEvent('alpha-wings:client:receiveChiefStatistics', function(stats)
    if not stats then
        QBCore.Functions.Notify("Failed to load statistics!", "error")
        return
    end
    
    local statsMenu = {
        id = 'chief_statistics_menu',
        title = 'Wings System Statistics',
        position = 'top-right',
        options = {
            {
                title = "Total Wings",
                description = tostring(stats.totalWings),
                disabled = true
            },
            {
                title = "Total Members",
                description = tostring(stats.totalMembers),
                disabled = true
            },
            {
                title = "Active Wings",
                description = tostring(stats.activeWings),
                disabled = true
            },
            {
                title = "── Wing Details ──",
                description = "Individual wing statistics",
                disabled = true
            }
        }
    }
    
    if stats.wingDetails and #stats.wingDetails > 0 then
        for _, wing in pairs(stats.wingDetails) do
            table.insert(statsMenu.options, {
                title = wing.name,
                description = string.format("Members: %d/%d | Leader: %s | Created: %s", 
                    wing.current_members or 0, 
                    wing.max_members or 0, 
                    wing.leader_name or "Unknown",
                    wing.created_at or "Unknown"
                ),
                disabled = true
            })
        end
    end
    
    table.insert(statsMenu.options, {
        title = "Back",
        description = "Return to Chief Management",
        event = "alpha-wings:client:chiefManagement"
    })
    
    lib.registerContext(statsMenu)
    lib.showContext('chief_statistics_menu')
end)

RegisterNetEvent('alpha-wings:client:viewAnnouncements', function()
    TriggerServerEvent('alpha-wings:server:getPlayerAnnouncements')
end)

RegisterNetEvent('alpha-wings:client:receivePlayerAnnouncements', function(announcements)
    if not announcements or #announcements == 0 then
        lib.alertDialog({
            header = 'Wing Announcements',
            content = 'No announcements found for your wing.',
            centered = true
        })
        return
    end
    
    local announcementsMenu = {
        id = 'player_announcements_menu',
        title = 'Wing Announcements',
        position = 'top-right',
        options = {}
    }
    
    for _, announcement in pairs(announcements) do
        table.insert(announcementsMenu.options, {
            title = string.format("From: %s", announcement.sender_name),
            description = string.format("Date: %s | Wing: %s", 
                announcement.created_at or "Unknown", 
                announcement.wing_name or "Unknown"
            ),
            event = "alpha-wings:client:viewAnnouncementDetails",
            args = {
                announcement = announcement
            }
        })
    end
    
    table.insert(announcementsMenu.options, {
        title = "Back to Main Menu",
        description = "Return to Wings System",
        event = "alpha-wings:client:openMenu"
    })
    
    lib.registerContext(announcementsMenu)
    lib.showContext('player_announcements_menu')
end)

RegisterNetEvent('alpha-wings:client:viewAnnouncementDetails', function(data)
    local announcement = data.announcement
    
    lib.alertDialog({
        header = string.format('Announcement - %s', announcement.wing_name or "Unknown Wing"),
        content = string.format("From: %s\nDate: %s\n\n%s", 
            announcement.sender_name or "Unknown", 
            announcement.created_at or "Unknown",
            announcement.message or "No message"
        ),
        centered = true
    })
end)

RegisterNetEvent('alpha-wings:client:receiveWingAnnouncement', function(data)
    lib.notify({
        title = 'Wing Announcement',
        description = string.format('%s\n\nFrom: %s\nWing: %s', data.message, data.senderName, data.wingName),
        type = 'inform',
        position = 'top',
        duration = 10000
    })
    
    lib.alertDialog({
        header = 'Wing Announcement - ' .. data.wingName,
        content = string.format("From: %s\n\n%s", data.senderName, data.message),
        centered = true
    })
end)

RegisterNetEvent('alpha-wings:client:wingLeadership', function()
    TriggerServerEvent('alpha-wings:server:getWingLeadershipOptions')
end)

RegisterNetEvent('alpha-wings:client:receiveWingLeadershipOptions', function(memberInfo)
    if not memberInfo then
        QBCore.Functions.Notify("You are not in any wing!", "error")
        return
    end
    
    local menuOptions = {}
    
    if memberInfo.wing_grade_level >= 5 then
        table.insert(menuOptions, {
            title = 'Set Radio Frequency',
            description = 'Set wing radio frequency',
            icon = 'radio',
            onSelect = function()
                openWingRadioMenu(memberInfo.wing_id)
            end
        })
    end

    if not IsPoliceChief() and (memberInfo.wing_grade_level >= 5 or memberInfo.parsed_permissions.manage_wing or memberInfo.parsed_permissions.manage_members) then
        table.insert(menuOptions, {
            title = 'Add Members',
            description = 'Add new members to the wing',
            icon = 'user-plus',
            onSelect = function()
                TriggerServerEvent('alpha-wings:server:getPoliceOfficersForWing', memberInfo.wing_id)
            end
        })

        table.insert(menuOptions, {
            title = 'Manage Members',
            description = 'View and manage all wing members',
            icon = 'users-cog',
            onSelect = function()
                TriggerServerEvent('alpha-wings:server:getWingMembersForLeader', memberInfo.wing_id)
            end
        })

        table.insert(menuOptions, {
            title = 'Remove Members',
            description = 'Remove members from the wing',
            icon = 'user-minus',
            onSelect = function()
                TriggerServerEvent('alpha-wings:server:getWingMembersForRemoval', memberInfo.wing_id)
            end
        })
        
        table.insert(menuOptions, {
            title = 'Wing Settings',
            description = 'Update wing settings',
            icon = 'cog',
            onSelect = function()
                openWingSettingsMenu(memberInfo.wing_id)
            end
        })
        
        table.insert(menuOptions, {
            title = 'Send Announcement',
            description = 'Send announcement to wing members',
            icon = 'bullhorn',
            onSelect = function()
                openWingAnnouncementMenu(memberInfo.wing_id)
            end
        })
        
        table.insert(menuOptions, {
            title = 'Manage Permissions',
            description = 'Set grade permissions',
            icon = 'shield-alt',
            onSelect = function()
                TriggerServerEvent('alpha-wings:server:getWingGradePermissions', memberInfo.wing_id)
            end
        })
    end
    
    if #menuOptions == 0 then
        QBCore.Functions.Notify("You don't have any management permissions!", "error")
        return
    end
    
    local leadershipMenu = {
        id = 'wing_leadership_menu',
        title = 'Wing Leadership - ' .. memberInfo.wing_name,
        position = 'top-right',
        options = menuOptions
    }
    
    lib.registerContext(leadershipMenu)
    lib.showContext('wing_leadership_menu')
end)

function openWingRadioMenu(wingId)
    local input = lib.inputDialog('Set Wing Radio Frequency', {
        {type = 'input', label = 'Radio Frequency', placeholder = 'e.g., 123.45', required = true}
    })
    
    if input and input[1] then
        TriggerServerEvent('alpha-wings:server:setWingRadio', {
            wingId = wingId,
            frequency = input[1]
        })
    end
end

function openWingSettingsMenu(wingId)
    local input = lib.inputDialog('Wing Settings', {
        {type = 'input', label = 'Description', placeholder = 'Wing description...', required = true},
        {type = 'number', label = 'Max Members', placeholder = '15', min = 1, max = 50, required = true}
    })
    
    if input then
        local updateData = {
            description = input[1],
            max_members = input[2]
        }
        
        TriggerServerEvent('alpha-wings:server:updateWingByLeader', {
            wingId = wingId,
            updateData = updateData
        })
    end
end

function openWingAnnouncementMenu(wingId)
    local input = lib.inputDialog('Send Wing Announcement', {
        {type = 'textarea', label = 'Message', placeholder = 'Enter your announcement...', required = true}
    })
    
    if input and input[1] then
        TriggerServerEvent('alpha-wings:server:sendWingAnnouncement', {
            wingId = wingId,
            message = input[1]
        })
    end
end

RegisterNetEvent('alpha-wings:client:receivePoliceOfficersForWing', function(officers, wingId)
    if not officers or #officers == 0 then
        QBCore.Functions.Notify("No available police officers found!", "error")
        return
    end
    
    local menuOptions = {}
    
    for _, officer in pairs(officers) do
        if not officer.in_wing then
            table.insert(menuOptions, {
                title = officer.name,
                description = string.format('Grade: %s', officer.grade),
                icon = 'user',
                onSelect = function()
                    TriggerServerEvent('alpha-wings:server:addMemberToWingByLeader', {
                        wingId = wingId,
                        citizenid = officer.citizenid,
                        playerName = officer.name,
                        gradeLevel = 0
                    })
                end
            })
        end
    end
    
    if #menuOptions == 0 then
        QBCore.Functions.Notify("All police officers are already in wings!", "info")
        return
    end
    
    local addMemberMenu = {
        id = 'add_wing_member_menu',
        title = 'Add Wing Member',
        position = 'top-right',
        options = menuOptions
    }
    
    lib.registerContext(addMemberMenu)
    lib.showContext('add_wing_member_menu')
end)

RegisterNetEvent('alpha-wings:client:receiveWingGradePermissions', function(grades, wingId)
    if not grades or #grades == 0 then
        QBCore.Functions.Notify("No wing grades found!", "error")
        return
    end
    
    local menuOptions = {}
    
    for _, grade in pairs(grades) do
        table.insert(menuOptions, {
            title = string.format('%s (Level %d)', grade.grade_name, grade.grade_level),
            description = string.format('Members: %d', grade.member_count),
            icon = 'users',
            onSelect = function()
                openGradePermissionsMenu(wingId, grade)
            end
        })
    end
    
    local gradePermissionsMenu = {
        id = 'wing_grade_permissions_menu',
        title = 'Wing Grade Permissions',
        position = 'top-right',
        options = menuOptions
    }
    
    lib.registerContext(gradePermissionsMenu)
    lib.showContext('wing_grade_permissions_menu')
end)

function openGradePermissionsMenu(wingId, grade)
    local currentPerms = grade.parsed_permissions or {}
    
    local input = lib.inputDialog(string.format('Permissions - %s', grade.grade_name), {
        {type = 'checkbox', label = 'Manage Members', checked = currentPerms.manage_members or false},
        {type = 'checkbox', label = 'Manage Wing Settings', checked = currentPerms.manage_wing or false},
        {type = 'checkbox', label = 'Send Announcements', checked = currentPerms.send_announcements or false},
        {type = 'checkbox', label = 'View Management Options', checked = currentPerms.view_management or false}
    })
    
    if input then
        local permissions = {
            manage_members = input[1],
            manage_wing = input[2],
            send_announcements = input[3],
            view_management = input[4]
        }
        
        TriggerServerEvent('alpha-wings:server:updateWingGradePermissions', {
            wingId = wingId,
            gradeLevel = grade.grade_level,
            permissions = permissions
        })
    end
end

RegisterNetEvent('alpha-wings:client:receiveWingMemberInfo', function(memberInfo)
    if not memberInfo then
        QBCore.Functions.Notify("You are not in any wing!", "error")
        return
    end
    
    local menuOptions = {
        {
            title = 'Wing Information',
            description = string.format('Wing: %s | Grade: %s (Level %d)',
                memberInfo.wing_name,
                memberInfo.grade_name or 'No Grade',
                memberInfo.wing_grade_level or 0
            ),
            icon = 'info-circle'
        }
    }
    
    if not IsPoliceChief() and (memberInfo.parsed_permissions.view_management or
       memberInfo.parsed_permissions.manage_members or
       memberInfo.parsed_permissions.manage_wing or
       memberInfo.wing_grade_level >= 5) then

        table.insert(menuOptions, {
            title = 'Wing Management',
            description = 'Access wing management options',
            icon = 'crown',
            onSelect = function()
                TriggerServerEvent('alpha-wings:server:getWingLeadershipOptions')
            end
        })
    elseif IsPoliceChief() then
        table.insert(menuOptions, {
            title = 'Wing Management (Restricted)',
            description = 'Police Chiefs cannot access wing leadership options. Wing leadership is separate from police rank.',
            icon = 'info-circle',
            disabled = true
        })
    end

    if memberInfo.parsed_permissions.view_all_members then
        table.insert(menuOptions, {
            title = 'View All Members',
            description = 'View all wing members (Leader Grade)',
            icon = 'users',
            event = 'alpha-wings:client:viewWingMembersForLeaderGrade',
            args = {
                wingId = memberInfo.wing_id
            }
        })
    end
    
    table.insert(menuOptions, {
        title = 'View Announcements',
        description = 'View wing announcements',
        icon = 'bullhorn',
        onSelect = function()
            TriggerServerEvent('alpha-wings:server:getPlayerAnnouncements')
        end
    })
    
    local wingInfoMenu = {
        id = 'wing_info_menu',
        title = 'My Wing Information',
        position = 'top-right',
        options = menuOptions
    }
    
    lib.registerContext(wingInfoMenu)
    lib.showContext('wing_info_menu')
end)

RegisterCommand('wings', function()
    if not IsPoliceOfficer() then
        QBCore.Functions.Notify("Access denied. Police personnel only.", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:getPlayerWingInfo')
end, false)

RegisterCommand('wingsadmin', function()
    if not IsPoliceChief() then
        QBCore.Functions.Notify("Access denied. Police Chief authorization required.", "error")
        return
    end

    TriggerEvent('alpha-wings:client:wingGradesManagement')
end, false)

RegisterCommand('winggrade', function()
    if not IsPoliceOfficer() then
        QBCore.Functions.Notify("Access denied. Police personnel only.", "error")
        return
    end

    TriggerServerEvent('alpha-wings:server:checkWingGradeStatus')
end, false)

TriggerEvent('chat:addSuggestion', '/wings', 'View your wing information and access Wings System')
TriggerEvent('chat:addSuggestion', '/wingsadmin', 'Open Wings Administration (Chief Only)')
TriggerEvent('chat:addSuggestion', '/winggrade', 'Check your wing grade and leadership status')