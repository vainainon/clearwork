local characters = {}

CreateThread(function()
    Wait(5000)
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterNetEvent('cw-characters:client:receiveCharacters', function(list)
    characters = list or {}

    print('[cw-characters] Characters received: ' .. tostring(#characters))

    if #characters == 0 then
        print('[cw-characters] No characters. Creating test character...')

        TriggerServerEvent('cw-characters:server:createCharacter', {
            slot = 1,
            firstname = 'John',
            lastname = 'Marston',
            gender = 'male',
            age = 30
        })
    else
        print('[cw-characters] Selecting first character...')
        TriggerServerEvent('cw-characters:server:selectCharacter', characters[1].id)
    end
end)

RegisterNetEvent('cw-characters:client:createSuccess', function(characterId)
    print('[cw-characters] Character created: ' .. tostring(characterId))
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterNetEvent('cw-characters:client:createFailed', function(reason)
    print('[cw-characters] Create failed: ' .. tostring(reason))
end)

RegisterNetEvent('cw-characters:client:selectFailed', function(reason)
    print('[cw-characters] Select failed: ' .. tostring(reason))
end)

RegisterNetEvent('cw-characters:client:characterSelected', function(character)
    print(('[cw-characters] Character selected: %s %s'):format(
        character.firstname,
        character.lastname
    ))
end)