local cameras = {}

RegisterNetEvent('frkn-camera:initializeCameras')
AddEventHandler('frkn-camera:initializeCameras', function()
    local src = source
    TriggerClientEvent('frkn-camera:createCam', src, cameras)
end)

CreateThread(function()
    for k, v in pairs(FRKN.Camera) do
        cameras[k] = {
            image = v.image,
            code = v.code,
            name = v.name,
            street = v.street,
            coords = v.coords,
            heading = v.heading,
            propName = v.propName,
            broken = false
        }
    end
end)

RegisterNetEvent('frkn-camera:breakCamera')
AddEventHandler('frkn-camera:breakCamera', function(camIndex)
    if cameras[camIndex] then
        cameras[camIndex].broken = true
        RemoveItem(source, FRKN.SignalCutterItem,1,{})
        TriggerClientEvent('frkn-camera:updateCamera', -1, camIndex, cameras[camIndex])
    end
end)





RegisterNetEvent("frkn-camera:triggerAlarm")
AddEventHandler("frkn-camera:triggerAlarm", function(coords)
    TriggerClientEvent("frkn-camera:playAlarm", -1, coords)
end)

RegisterUsableItem(FRKN.SignalCutterItem)
