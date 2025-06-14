playerData = {}
local createdCameras = {}
local cameraProps = {}
local activeCam = nil
local activeCamObj = nil
local camZoom = 70.0
local isNuiFocus = false
local minYaw, maxYaw, minPitch, maxPitch = nil, nil, nil, nil
local monitoring = false
local currentCamIndex = 1 
local totalCameras = #FRKN.Camera
local lastCoords = nil
local teleportedToPlayer = false
local lastCameraCoords = nil


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if NetworkIsPlayerActive(PlayerId()) then 
            playerData = GetPlayerData()
            TriggerServerEvent('frkn-camera:initializeCameras')
            break
        end 
    end
end)

RegisterNetEvent('frkn-camera:createCam')
AddEventHandler('frkn-camera:createCam', function(serverCameras)
    for k, v in pairs(serverCameras) do
        local camObj = CreateObject(v.propName, v.coords.x, v.coords.y, v.coords.z, true, false, false)
        SetEntityHeading(camObj, v.heading + 180.0)
        SetEntityAsMissionEntity(camObj, true, true)
        SetEntityInvincible(camObj, true)
        SetEntityCollision(camObj, true, true)
        SetEntityAlpha(camObj, 255, false)
        SetEntityVisible(camObj, true, false)
        SetEntityDynamic(camObj, true)
        FreezeEntityPosition(camObj, true)
        SetModelAsNoLongerNeeded(v.propName)
        createdCameras[k] = {obj = camObj, image=v.image, broken = v.broken, code=v.code, name=v.name, street=v.street, coords=v.coords}  
        table.insert(cameraProps, camObj)
    end
end)

RegisterNetEvent('frkn-camera:updateCamera')
AddEventHandler('frkn-camera:updateCamera', function(index, camData)
    if createdCameras[index] then
        createdCameras[index].broken = camData.broken
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() == resource then
        for _, prop in ipairs(cameraProps) do
            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
        end
    end
end)



RegisterNetEvent('frkn-camera:signalcutter')
AddEventHandler('frkn-camera:signalcutter', function()

    playTabletAnimation()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local foundCamera = false

    for k, camData in pairs(createdCameras) do
        local camCoords = GetEntityCoords(camData.obj)
        if #(playerCoords - camCoords) < 5.0 and not camData.broken then 
            foundCamera = true
            FRKN.MinigameConfig["stickGame"](function(result)
                if result then
                    TriggerServerEvent('frkn-camera:breakCamera', k)
                    Notify(FRKN.Notify['signalCutter']['success'])
                else
                    Notify(FRKN.Notify['signalCutter']['error'])
                end
                Wait(2000)
                stopTabletAnimation()
            end)
            break 
        end
    end

    if not foundCamera then
        Notify(FRKN.Notify['signalCutter']['nearby'])
        Wait(2000)
        stopTabletAnimation()
    end
end)



function playTabletAnimation()
    local ped = PlayerPedId()
    RequestAnimDict("amb@world_human_seat_wall_tablet@female@base")
    while not HasAnimDictLoaded("amb@world_human_seat_wall_tablet@female@base") do
        Citizen.Wait(0)
    end

    TaskPlayAnim(ped, "amb@world_human_seat_wall_tablet@female@base", "base", 8.0, -8.0, -1, 49, 0, false, false, false)

    spawnTabletProp(ped)
end

function spawnTabletProp(ped)
    local tabletModel = GetHashKey("prop_cs_tablet")

    RequestModel(tabletModel)
    while not HasModelLoaded(tabletModel) do
        Citizen.Wait(0)
    end
    tabletProp = CreateObject(tabletModel, 0, 0, 0, true, true, false)
    local boneIndex = GetPedBoneIndex(ped, 60309)
    
    AttachEntityToEntity(tabletProp, ped, boneIndex, 0.03, 0.002, -0.01, 180.0, 0.0, 180.0, true, true, false, true, 1, true)
end

function stopTabletAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    removeTabletProp()
end

function removeTabletProp()
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
        tabletProp = nil
    end
end

RegisterNUICallback('openCam', function(data, cb)
    monitoring = false
    SetNuiFocus(false, false)
    DoScreenFadeOut(500)
    Wait(1000)
    local camIndex = tonumber(data.id)
    local camData = createdCameras[camIndex]
    DoScreenFadeIn(500)
    currentCamIndex = camIndex
    local playerPed = PlayerPedId() 
    lastCoords = GetEntityCoords(playerPed)

    if camData and not camData.broken then
        local camCoords = GetEntityCoords(camData.obj)
        local camHeading = FRKN.Camera[camIndex].heading
        local camPitch = FRKN.Camera[camIndex].pitch
        local camYaw = FRKN.Camera[camIndex].yaw
        local rangeYaw = FRKN.Camera[camIndex].rangeYaw
        local rangePitch = FRKN.Camera[camIndex].rangePitch

        minYaw = (camYaw - rangeYaw + 360) % 360
        maxYaw = (camYaw + rangeYaw) % 360
        minPitch = math.max(-89.0, camPitch - rangePitch)
        maxPitch = math.min(89.0, camPitch + rangePitch)

        activeCamObj = camData.obj
        activeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(activeCam, camCoords.x, camCoords.y, camCoords.z + 1.0)
        SetCamRot(activeCam, camPitch, 0.0, camYaw, 2)
        SetCamFov(activeCam, camZoom)
        SetCamActive(activeCam, true)
        RenderScriptCams(true, false, 0, true, true)

        SetEntityCoords(playerPed, camCoords.x, camCoords.y, camCoords.z)
        SetEntityHeading(playerPed, camHeading)
        SetEntityVisible(playerPed, false, false) 
        SetEntityInvincible(playerPed, true)

        SendNUIMessage({action = "openCam", camData = FRKN.Camera[camIndex]})
        SetTimecycleModifier("heliGunCam")
        SetNuiFocus(false, false)
    elseif camData and camData.broken then
        -- print("Bu kamera bozuk durumda ve görüntülenemez.")
    else
        -- print("Geçerli bir kamera ID'si giriniz.")
    end
end)

RegisterNUICallback('switchCamera', function(data, cb)
    if #FRKN.Camera < 1 then return end 

    if data.direction == "next" then
        currentCamIndex = currentCamIndex + 1
        if currentCamIndex > #FRKN.Camera then
            currentCamIndex = 1 
        end
    elseif data.direction == "prev" then
        currentCamIndex = currentCamIndex - 1
        if currentCamIndex < 1 then
            currentCamIndex = #FRKN.Camera
        end
    end

    local camData = FRKN.Camera[currentCamIndex]
    if camData and not camData.broken then
        local camCoords = GetEntityCoords(createdCameras[currentCamIndex].obj)
        local camYaw = camData.yaw
        local camPitch = camData.pitch

        if activeCam then
            DestroyCam(activeCam, true)
        end

        activeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(activeCam, camCoords.x, camCoords.y, camCoords.z + 1.0)
        SetCamRot(activeCam, camPitch, 0.0, camYaw, 2)
        SetCamFov(activeCam, camZoom)
        SetCamActive(activeCam, true)
        RenderScriptCams(true, false, 0, true, true)

        SendNUIMessage({action = "updateCam", camData = camData})
    end
end)


Citizen.CreateThread(function()
    local camCoords = FRKN.OpenCameraCoords

    local targetOptions = {
        {
            event = "frkn-camera:camList",
            icon = FRKN.Interaction.Icon,
            label = FRKN.Interaction.Text,
            canInteract = function(entity, distance)
                if IsPedInAnyVehicle(PlayerPedId(), true) then return false end

                local job = GetPlayerJob()
                for _, allowedJob in pairs(FRKN.Job) do
                    if job == allowedJob then
                        return true
                    end
                end
                return false
            end
        }
    }

    if FRKN.Interaction.Target == "qb-target" then
        exports["qb-target"]:AddBoxZone("frkn_camera", vector3(camCoords.x, camCoords.y, camCoords.z), 1.0, 1.0, {
            name = "frkn_camera",
            heading = camCoords.w or 0.0,
            debugPoly = false,
            minZ = camCoords.z - 1.0,
            maxZ = camCoords.z + 1.0,
        }, {
            options = targetOptions,
            distance = 2.0
        })

    elseif FRKN.Interaction.Target == "ox_target" then
        exports["ox_target"]:addSphereZone({
            coords = vector3(camCoords.x, camCoords.y, camCoords.z),
            radius = 2.0,
            options = targetOptions
        })
    end
end)


local alarmActive = false

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local camCoords = FRKN.OpenCameraCoords
        local distance = #(playerCoords - camCoords)
        local sleep = 2000

        if distance < 50.0 then
            sleep = 500
            local isWearingMask = GetPedDrawableVariation(playerPed, 1) ~= 0
            local isArmed = IsPedArmed(playerPed, 7)

            if isWearingMask and isArmed and distance < 10.0 and not alarmActive then
                alarmActive = true
                TriggerServerEvent("frkn-camera:triggerAlarm", camCoords)
                Citizen.SetTimeout(15000, function() 
                    alarmActive = false
                end)
            end
        end

        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local sleep = 2000

        for k, camData in pairs(createdCameras) do
            if not camData.broken then
                local camCoords = camData.coords
                local distance = #(playerCoords - camCoords)

                if distance < 30.0 then
                    sleep = 1

                    if IsPedShooting(playerPed) then
                        local impact, impactCoords = GetPedLastWeaponImpactCoord(playerPed)
                        if impact then
                            local hitDistance = #(impactCoords - camCoords)
                            if hitDistance < 0.7 then 
                                camData.hitCount = (camData.hitCount or 0) + 1

                                if camData.hitCount >= 3 then
                                    TriggerServerEvent('frkn-camera:breakCamera', k)
                                    camData.hitCount = 0
                                    AddExplosion(camCoords.x, camCoords.y, camCoords.z, 2, 1.0, true, false, 0.0)
                                    Notify(FRKN.Notify['camera']['success'])
                                end
                            end
                        end
                    end
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)


-- Command to open camera menu
RegisterCommand('cameras', function()
    local job = GetPlayerJob()
    local hasAccess = false
    
    for _, allowedJob in pairs(FRKN.Job) do
        if job == allowedJob then
            hasAccess = true
            break
        end
    end
    
    if hasAccess then
        TriggerEvent('frkn-camera:camList')
    else
        Notify(FRKN.Notify['access']['denied'], 'error', 5000)
    end
end, false)

-- Add command suggestion for easier use
TriggerEvent('chat:addSuggestion', '/cameras', 'Open the security camera system', {})

RegisterNetEvent('frkn-camera:camList')
AddEventHandler('frkn-camera:camList', function()
    
    SetNuiFocus(true, true)
    monitoring = true

    Citizen.CreateThread(function()
        while monitoring do
            Citizen.Wait(1000)

            local camDetectionData = {}

            for camIndex, camData in pairs(createdCameras) do
                if camData and DoesEntityExist(camData.obj) and not camData.broken then
                    local camCoords = GetEntityCoords(camData.obj)
                    local detectedPlayers = {}
                    local playersInView = 0

                    for _, player in ipairs(GetActivePlayers()) do
                        local ped = GetPlayerPed(player)
                        if ped and DoesEntityExist(ped) then
                            local pedCoords = GetEntityCoords(ped)
                            local distance = #(pedCoords - camCoords)

                            if distance < 50.0 then
                                playersInView = playersInView + 1

                                local isWearingMask = GetPedDrawableVariation(ped, 1) ~= 0
                                local isArmed = IsPedArmed(ped, 7)
                                local playerName = GetPlayerName(player)
                                local displayName = isWearingMask and "Anonymous" or playerName

                                if isWearingMask or isArmed then
                                    table.insert(detectedPlayers, {
                                        player = displayName,
                                        weaponDetected = isArmed,
                                        maskDetected = isWearingMask
                                    })
                                end
                            end
                        end
                    end

                    local grouping = playersInView > 5

                    camDetectionData[camIndex] = {
                        detected = detectedPlayers,
                        grouping = grouping
                    }
                end
            end

            SendNUIMessage({
                action = "openCamList",
                camData = createdCameras,
                camDetectionData = camDetectionData
            })
        end
        SendNUIMessage({action = "closeCam"})
        lastCameraCoords = NetworkIsLocalPlayerInvincible()
        teleportedToPlayer = false
    end)
end)


RegisterNetEvent("frkn-camera:playAlarm")
AddEventHandler("frkn-camera:playAlarm", function(coords)
    local alarmSound = "VEHICLES_HORNS_POLICE_WARNING"
    local alarmDuration = 5000

    PlaySoundFromCoord(-1, alarmSound, coords.x, coords.y, coords.z, "DLC_XM_HEIST_HACKING_SOUNDS", true, 0, false)
    
    Citizen.SetTimeout(alarmDuration, function()
        StopSound(-1)
    end)
end)


RegisterNUICallback('closeNui', function(data, cb)
    monitoring = false
    SetNuiFocus(false, false)
end)

RegisterNUICallback('closeFocus', function(data, cb)
    SetNuiFocus(false, false)
end)

function GetForwardVector(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

RegisterNUICallback('changeCamMode', function(data, cb)
    currentCamMode = data.mode
    SetCamEffect(activeCam, currentCamMode)
    cb("ok")
end)


function SetCamEffect(cam, mode)
    if mode == "nrm" then
        SetTimecycleModifier("default")
        SetSeethrough(false)
    elseif mode == "ngtv" then
        SetTimecycleModifier("heliGunCam")
        SetSeethrough(false)
    elseif mode == "thrml" then
        SetSeethrough(true)
    elseif mode == "draw" then
        SetSeethrough(false)
        Citizen.CreateThread(function()
            while currentCamMode == "draw" and activeCam do
                local entities = GetGamePool('CPed')
                for _, entity in ipairs(entities) do
                    if DoesEntityExist(entity) then
                        local pos = GetEntityCoords(entity)
                        DrawMarker(0, pos.x, pos.y, pos.z + 1.0, 0, 0, 0, 0, 0, 0, 0.3, 0.3, 0.3, 0, 255, 0, 150, false, false, 2, nil, nil, false)
                    end
                end
                Citizen.Wait(0)
            end
        end)
    end
end


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if activeCam then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)

            local mouseX = GetDisabledControlNormal(0, 1)
            local mouseY = GetDisabledControlNormal(0, 2)
            local currentRot = GetCamRot(activeCam, 2)

            SendNUIMessage({
                action = "updateMousePosition",
                mouseX = mouseX,
            })

            local newYaw = (currentRot.z - mouseX * 5) % 360
            if minYaw < maxYaw then
                newYaw = math.min(math.max(newYaw, minYaw), maxYaw)
            else
                if newYaw > maxYaw and newYaw < minYaw then
                    if math.abs(newYaw - minYaw) < math.abs(newYaw - maxYaw) then
                        newYaw = minYaw
                    else
                        newYaw = maxYaw
                    end
                end
            end

            local newPitch = math.min(math.max(currentRot.x - (mouseY * 5), minPitch), maxPitch)

            SetCamRot(activeCam, newPitch, 0.0, newYaw, 2)

            local playerPed = PlayerPedId()
            local camCoords = GetCamCoord(activeCam)
            local forwardVector = GetForwardVector(GetCamRot(activeCam, 2))
            local endCoords = camCoords + (forwardVector * 50.0)
            local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, endCoords.x, endCoords.y, endCoords.z, 8, activeCam, 0)
            local _, hit, hitCoords, _, entityHit = GetShapeTestResult(rayHandle)
            



            local playersInView = 0
            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)
                local pedCoords = GetEntityCoords(ped)
                local toPed = pedCoords - camCoords
                local dot = toPed.x * forwardVector.x + toPed.y * forwardVector.y + toPed.z * forwardVector.z
                if dot > 0 and #(pedCoords - camCoords) < 50.0 then
                    playersInView = playersInView + 1
                end
            end


            local grouping = playersInView > 5


            if hit == 1 and IsEntityAPed(entityHit) and IsPedAPlayer(entityHit) then
                if not teleportedToPlayer and pedCoords then
                    lastCameraCoords = GetEntityCoords(PlayerPedId()) 
                    SetEntityCoords(PlayerPedId(), pedCoords.x, pedCoords.y, pedCoords.z + 1.0, 0, 0, 0, false)
                    teleportedToPlayer = true
                end

                if teleportedToPlayer and lastCameraCoords then
                    SetEntityCoords(PlayerPedId(), lastCameraCoords.x, lastCameraCoords.y, lastCameraCoords.z, 0, 0, 0, false)
                    teleportedToPlayer = false
                end
                

                for _, player in ipairs(GetActivePlayers()) do
                    local ped = GetPlayerPed(player)
                    if ped == entityHit and ped ~= PlayerPedId() then
                        local playerName = GetPlayerName(player)
                        local isWearingMask = GetPedDrawableVariation(entityHit, 1) ~= 0
                        local isArmed = IsPedArmed(entityHit, 7)
                        local displayName = isWearingMask and "Anonymous" or playerName
            
                        SendNUIMessage({
                            action = "playerDetected",
                            player = displayName,
                            weaponDetected = isArmed,
                            maskDetected = isWearingMask,
                            signal = false
                        })
                        break
                    end
                end
            else
                SendNUIMessage({action = "playerNotDetected"})
            end
            

            if IsDisabledControlPressed(0, 241) then 
                camZoom = math.max(camZoom - 1.0, 10.0)
                SetCamFov(activeCam, camZoom)
            elseif IsDisabledControlPressed(0, 242) then 
                camZoom = math.min(camZoom + 1.0, 70.0)
                SetCamFov(activeCam, camZoom)
            end

            if IsDisabledControlJustPressed(0, 174) or IsDisabledControlJustPressed(0, 34) then 
                currentCamIndex = currentCamIndex - 1
                if currentCamIndex < 1 then
                    currentCamIndex = totalCameras 
                end
                SwitchToCamera(currentCamIndex)
            elseif IsDisabledControlJustPressed(0, 175) or IsDisabledControlJustPressed(0, 35) then 
                currentCamIndex = currentCamIndex + 1
                if currentCamIndex > totalCameras then
                    currentCamIndex = 1 
                end
                SwitchToCamera(currentCamIndex)
            end

            if IsDisabledControlJustPressed(0, 36) then
                isNuiFocus = not isNuiFocus
                SetNuiFocus(true, true)
            end
            
            if IsDisabledControlJustPressed(0, 202) then
                DoScreenFadeOut(500) 
                Wait(700) 

                RenderScriptCams(false, false, 0, true, true)
                DestroyAllCams(true)
                SetNuiFocus(false, false)
                SendNUIMessage({action = "closeCam"})
                SetTimecycleModifier("default")
                SetCamEffect(activeCam, "nrm")
                activeCam = nil
                activeCamObj = nil
                SetEntityVisible(PlayerPedId(), true, false)
                SetEntityCoords(PlayerPedId(), lastCoords.x, lastCoords.y, lastCoords.z)
                SetEntityInvincible(PlayerPedId(), false)
                DoScreenFadeIn(500) 
            
            end
            
        end
    end
end)


function SwitchToCamera(camIndex)
    local camData = FRKN.Camera[camIndex]
    if camData and not camData.broken then
        local camCoords = GetEntityCoords(createdCameras[camIndex].obj)
        local camYaw = camData.yaw
        local camPitch = camData.pitch

        if activeCam then
            DestroyCam(activeCam, true)
            Citizen.Wait(50)
        end

        DestroyAllCams(true)
        Citizen.Wait(50)

        activeCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(activeCam, camCoords.x, camCoords.y, camCoords.z + 1.0)
        SetCamRot(activeCam, camPitch, 0.0, camYaw, 2)
        SetCamFov(activeCam, camZoom)
        SetCamActive(activeCam, true)
        RenderScriptCams(true, false, 0, true, true)

        SetEntityVisible(PlayerPedId(), false, false)
        SetEntityHeading(PlayerPedId(), camData.heading)
        SetEntityCoords(PlayerPedId(), camCoords.x, camCoords.y, camCoords.z)

        SendNUIMessage({
            action = "updateCam",
            camData = camData,
            camIndex = camIndex
        })
    end
end
