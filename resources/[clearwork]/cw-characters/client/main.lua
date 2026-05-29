local characters = {}
local uiOpen = false

local function SetCharacterUI(state)
    uiOpen = state

    SetNuiFocus(state, state)

    SendNUIMessage({
        action = state and 'open' or 'close',
        characters = characters
    })
end

CreateThread(function()
    Wait(5000)
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterNetEvent('cw-characters:client:receiveCharacters', function(list)
    characters = list or {}

    print('[cw-characters] Characters received: ' .. tostring(#characters))

    SetCharacterUI(true)
end)

RegisterNetEvent('cw-characters:client:createSuccess', function()
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterNetEvent('cw-characters:client:createFailed', function(reason)
    SendNUIMessage({
        action = 'error',
        message = tostring(reason)
    })
end)

RegisterNetEvent('cw-characters:client:selectFailed', function(reason)
    SendNUIMessage({
        action = 'error',
        message = tostring(reason)
    })
end)

RegisterNetEvent('cw-characters:client:characterSelected', function(character)
    print(('[cw-characters] Character selected: %s %s'):format(
        character.firstname,
        character.lastname
    ))

    SetCharacterUI(false)

    TriggerEvent('cw-spawn:client:spawnCharacter', character)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('cw-characters:server:createCharacter', {
        slot = tonumber(data.slot) or 1,
        firstname = data.firstname,
        lastname = data.lastname,
        gender = data.gender,
        age = tonumber(data.age) or 18
    })

    cb({ ok = true })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('cw-characters:server:selectCharacter', tonumber(data.id))
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(60000)

        if not uiOpen then
            local ped = PlayerPedId()

            if DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                local heading = GetEntityHeading(ped)

                TriggerServerEvent('cw-core:server:updateCharacterPosition', {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = heading
                })
            end
        end
    end
end)