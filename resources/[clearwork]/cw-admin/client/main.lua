local uiOpen = false

local function SetAdminUI(state)
    uiOpen = state
    SetNuiFocus(state, state)

    SendNUIMessage({
        action = state and 'open' or 'close'
    })
end

RegisterCommand('cwadmin', function()
    SetAdminUI(true)
    TriggerServerEvent('cw-admin:server:searchCharacters', '')
end, false)

RegisterCommand('adminchars', function()
    ExecuteCommand('cwadmin')
end, false)

RegisterNetEvent('cw-admin:client:receiveCharacters', function(characters)
    SendNUIMessage({
        action = 'characters',
        characters = characters or {}
    })
end)

RegisterNetEvent('cw-admin:client:deletedCharacter', function(characterId)
    SendNUIMessage({
        action = 'deleted',
        id = characterId
    })

    TriggerServerEvent('cw-admin:server:searchCharacters', '')
end)

RegisterNetEvent('cw-admin:client:error', function(message)
    SendNUIMessage({
        action = 'error',
        message = tostring(message)
    })
end)

RegisterNUICallback('searchCharacters', function(data, cb)
    TriggerServerEvent('cw-admin:server:searchCharacters', data.query or '')
    cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('cw-admin:server:deleteCharacter', tonumber(data.id))
    cb({ ok = true })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetAdminUI(false)
    cb({ ok = true })
end)