RegisterNUICallback('medicalGetSettings', function(_, cb)
    TriggerServerEvent('cw-admin:server:medical:getSettings')
    cb({ ok = true })
end)

RegisterNUICallback('medicalSetPermadeathChance', function(data, cb)
    TriggerServerEvent('cw-admin:server:medical:setPermadeathChance', data and data.chance)
    cb({ ok = true })
end)

RegisterNUICallback('medicalRevivePlayer', function(data, cb)
    TriggerServerEvent('cw-admin:server:medical:revivePlayer', data and data.source)
    cb({ ok = true })
end)

RegisterNUICallback('medicalReviveCharacter', function(data, cb)
    TriggerServerEvent('cw-admin:server:medical:reviveCharacter', data and data.id)
    cb({ ok = true })
end)

RegisterNetEvent('cw-admin:client:medical:settings', function(settings)
    SendNUIMessage({
        action = 'medical:settings',
        payload = settings or {}
    })
end)