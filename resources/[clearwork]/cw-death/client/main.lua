local characters = {}
local uiOpen = false
local characterSelected = false
local currentCharacterId = nil

local function Notify(message)
    TriggerEvent('chat:addMessage', {
        color = { 255, 80, 80 },
        args = { 'Персонажи', message }
    })
end

local function SetPedHiddenInCharacterMenu(state)
    local ped = PlayerPedId()

    FreezeEntityPosition(ped, state)
    SetEntityVisible(ped, not state, false)
    SetEntityCollision(ped, not state, not state)

    if state then
        SetEntityAlpha(ped, 0, false)
        ClearPedTasksImmediately(ped)
    else
        if type(ResetEntityAlpha) == 'function' then
            ResetEntityAlpha(ped)
        else
            SetEntityAlpha(ped, 255, false)
        end
    end
end

local function ApplyBasicAppearance(character)
    if not character then return end

    local ped = PlayerPedId()

    if character.scale then
        local scale = tonumber(character.scale)

        if scale then
            SetPedScale(ped, scale)
        end
    end
end

local function OpenUI()
    uiOpen = true

    SetNuiFocus(true, true)
    SetPedHiddenInCharacterMenu(true)

    SendNUIMessage({
        action = 'open',
        characters = characters,
        currentCharacterId = currentCharacterId,
        hasSelectedCharacter = characterSelected
    })
end

local function CloseUI()
    uiOpen = false

    SetNuiFocus(false, false)
    SetPedHiddenInCharacterMenu(false)

    SendNUIMessage({
        action = 'close'
    })
end

local function OpenCharacterMenu()
    DoScreenFadeOut(200)
    Wait(250)

    SetPedHiddenInCharacterMenu(true)
    TriggerServerEvent('cw-characters:server:getCharacters')

    Wait(250)
    DoScreenFadeIn(400)
end

RegisterNetEvent('cw-characters:client:receiveCharacters', function(data, serverCurrentCharacterId)
    characters = data or {}

    if serverCurrentCharacterId ~= nil then
        currentCharacterId = tonumber(serverCurrentCharacterId)
    else
        currentCharacterId = nil

        for _, character in ipairs(characters) do
            if character.is_current == true or character.is_current == 1 or character.is_current == '1' then
                currentCharacterId = tonumber(character.id)
                break
            end
        end
    end

    OpenUI()
end)

RegisterNetEvent('cw-characters:client:characterSelected', function(character)
    if not character then return end

    characterSelected = true
    currentCharacterId = tonumber(character.id)

    CloseUI()
    ApplyBasicAppearance(character)

    TriggerEvent('cw-spawn:client:spawnCharacter', character)
end)

RegisterNetEvent('cw-characters:client:selectFailed', function(message)
    Notify(message or 'Нельзя выбрать этого персонажа.')
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterNetEvent('cw-characters:client:createFailed', function(message)
    Notify(message or 'Не удалось создать персонажа.')
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterNetEvent('cw-characters:client:createSuccess', function()
    Notify('Персонаж создан.')
end)

RegisterNetEvent('cw-characters:client:deleteFailed', function(message)
    Notify(message or 'Не удалось удалить персонажа.')
    TriggerServerEvent('cw-characters:server:getCharacters')
end)

RegisterCommand('chars', function()
    OpenCharacterMenu()
end, false)

RegisterNUICallback('selectCharacter', function(data, cb)
    if data and data.id then
        TriggerServerEvent('cw-characters:server:selectCharacter', tonumber(data.id))
    end

    cb({ ok = true })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent('cw-characters:server:createCharacter', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('requestDeleteCharacter', function(data, cb)
    if data and data.id then
        TriggerServerEvent('cw-characters:server:requestDeleteCharacter', tonumber(data.id))
    end

    cb({ ok = true })
end)

RegisterNUICallback('cancelDeleteCharacter', function(data, cb)
    if data and data.id then
        TriggerServerEvent('cw-characters:server:cancelDeleteCharacter', tonumber(data.id))
    end

    cb({ ok = true })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    -- Если персонаж уже выбран, меню можно закрывать всегда.
    -- Это важно после нокдауна/пермакилла, чтобы не блокировать игрока в NUI.
    if characterSelected then
        CloseUI()
        cb({ ok = true })
        return
    end

    Notify('Сначала выбери или создай персонажа.')
    cb({ ok = false })
end)

CreateThread(function()
    Wait(2500)
    OpenCharacterMenu()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    SetPedHiddenInCharacterMenu(false)
end)