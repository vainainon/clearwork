local characters = {}
local uiOpen = false
local characterSelected = false
local currentCharacterId = nil
local firstOpen = true

local function SetCharacterUI(state)
    uiOpen = state
    SetNuiFocus(state, state)

    SendNUIMessage({
        action = state and 'open' or 'close',
        characters = characters,
        hasSelectedCharacter = characterSelected,
        currentCharacterId = currentCharacterId
    })
end

local function SaveCurrentPosition()
    if not characterSelected then
        return
    end

    local ped = PlayerPedId()

    if not DoesEntityExist(ped) then
        return
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    TriggerServerEvent('cw-core:server:saveCurrentPosition', {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading
    })
end

local function ApplyBasicAppearance(character)
    if not character or not character.skin then
        return
    end

    local ok, skin = pcall(json.decode, character.skin)

    if not ok or type(skin) ~= 'table' then
        return
    end

    local ped = PlayerPedId()

    if skin.scale and SetPedScale then
        SetPedScale(ped, tonumber(skin.scale) or 1.0)
    end
end

local function OpenCharacterMenu()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    DoScreenFadeOut(300)
    Wait(400)

    FreezeEntityPosition(ped, true)

    TriggerServerEvent('cw-characters:server:openCharacterMenu', {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading
    })

    Wait(300)
    DoScreenFadeIn(500)
end

CreateThread(function()
    Wait(5000)
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterCommand('changechar', function()
    print('[cw-characters] Opening character menu...')
    OpenCharacterMenu()
end, false)

RegisterCommand('char', function()
    ExecuteCommand('changechar')
end, false)

RegisterCommand('chars', function()
    ExecuteCommand('changechar')
end, false)

RegisterNetEvent('cw-characters:client:receiveCharacters', function(list, selectedId)
    characters = list or {}

    print('[cw-characters] Characters received: ' .. tostring(#characters))

    if selectedId ~= nil then
        currentCharacterId = tonumber(selectedId)
    else
        currentCharacterId = nil

        for _, character in ipairs(characters) do
            if character.is_current == true or character.is_current == 1 or character.is_current == '1' then
                currentCharacterId = tonumber(character.id)
                break
            end
        end
    end

    if currentCharacterId ~= nil then
        characterSelected = true
    elseif firstOpen then
        characterSelected = false
    end

    if firstOpen then
        firstOpen = false
    end

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

RegisterNetEvent('cw-characters:client:deleteFailed', function(reason)
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

    characterSelected = true
    currentCharacterId = tonumber(character.id)

    SetCharacterUI(false)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    ApplyBasicAppearance(character)
    TriggerEvent('cw-spawn:client:spawnCharacter', character)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('cw-characters:server:createCharacter', {
        firstname = data.firstname,
        lastname = data.lastname,
        gender = data.gender,
        age = tonumber(data.age) or 18,
        startCity = data.startCity,
        skin = data.skin or {}
    })

    cb({
        ok = true
    })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    local id = tonumber(data.id)

    if currentCharacterId ~= nil and id == currentCharacterId then
        cb({
            ok = false,
            reason = 'already_selected'
        })
        return
    end

    TriggerServerEvent('cw-characters:server:selectCharacter', id)

    cb({
        ok = true
    })
end)

RegisterNUICallback('requestDeleteCharacter', function(data, cb)
    TriggerServerEvent('cw-characters:server:requestDeleteCharacter', tonumber(data.id))

    cb({
        ok = true
    })
end)

RegisterNUICallback('cancelDeleteCharacter', function(data, cb)
    TriggerServerEvent('cw-characters:server:cancelDeleteCharacter', tonumber(data.id))

    cb({
        ok = true
    })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetCharacterUI(false)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    cb({
        ok = true
    })
end)

CreateThread(function()
    while true do
        Wait(60000)

        if not uiOpen and characterSelected then
            SaveCurrentPosition()
        end
    end
end)
