RegisterNUICallback('characterInventoryOpen', function(data, cb)
    TriggerServerEvent('cw-admin:server:inventory:open', tonumber(data and (data.characterId or data.character_id or data.id)))
    cb({ ok = true })
end)

RegisterNUICallback('characterInventoryAddItem', function(data, cb)
    TriggerServerEvent('cw-admin:server:inventory:addItem', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('characterInventoryRefresh', function(data, cb)
    TriggerServerEvent('cw-admin:server:inventory:open', tonumber(data and (data.characterId or data.character_id or data.id)))
    cb({ ok = true })
end)

RegisterNetEvent('cw-admin:client:inventory:receive', function(payload)
    SendNUIMessage({ action = 'inventory:receive', payload = payload or {} })
end)
