local characters = {}
local uiOpen = false
local characterSelected = false
local currentCharacterId = nil
local firstOpenDone = false
local accountRetryCount = 0
local hidePedForCurrentMenu = false

local function DisableSpawnManagerAutoSpawn()
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function()
            exports.spawnmanager:setAutoSpawn(false)
        end)
    end
end

local function Notify(message)
    TriggerEvent('chat:addMessage', {
        color = { 255, 80, 80 },
        args = { 'Персонажи', message }
    })
end

local function SetPedHiddenInCharacterMenu(state)
    local ped = PlayerPedId()

    if not ped or ped == 0 then
        return
    end

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

        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetEntityVisible(ped, true, false)
    end
end

local function GetCurrentCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped)
    }
end

local function ApplyBasicAppearance(character)
    if not character then return end

    local skin = nil

    if character.skin then
        local ok, decoded = pcall(json.decode, character.skin)

        if ok and type(decoded) == 'table' then
            skin = decoded
        end
    end

    local ped = PlayerPedId()
    local scale = nil

    if skin and skin.scale then
        scale = tonumber(skin.scale)
    elseif character.scale then
        scale = tonumber(character.scale)
    end

    if scale and SetPedScale then
        SetPedScale(ped, scale)
    end
end

local function OpenUI()
    uiOpen = true

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)

    -- На первом входе ped-заглушка скрыта за меню.
    -- При обычном /chars во время игры ped НЕ прячем и НЕ телепортируем.
    if hidePedForCurrentMenu then
        SetPedHiddenInCharacterMenu(true)
    end

    SendNUIMessage({
        action = 'open',
        characters = characters,
        currentCharacterId = currentCharacterId,
        hasSelectedCharacter = characterSelected
    })
end

local function CloseUI(unhidePed)
    uiOpen = false

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    if hidePedForCurrentMenu and unhidePed ~= false then
        SetPedHiddenInCharacterMenu(false)
    end

    hidePedForCurrentMenu = false

    SendNUIMessage({
        action = 'close'
    })
end

local function RequestCharacters(saveCurrentPosition)
    if saveCurrentPosition then
        TriggerServerEvent('cw-characters:server:openCharacterMenu', GetCurrentCoords())
    else
        TriggerServerEvent('cw-characters:server:getCharacters')
    end
end

local function OpenCharacterMenu()
    DisableSpawnManagerAutoSpawn()

    local firstMenu = not characterSelected
    hidePedForCurrentMenu = firstMenu

    if firstMenu then
        DoScreenFadeOut(200)
        Wait(250)

        -- Только первый вход: создаём ped-заглушку через spawnmanager на земле.
        TriggerEvent('cw-spawn:client:prepareCharacterMenu', true)
        Wait(600)

        SetPedHiddenInCharacterMenu(true)
        RequestCharacters(false)

        Wait(250)
        DoScreenFadeIn(400)
        return
    end

    -- Обычный /chars во время игры:
    -- не вызываем prepareCharacterMenu, не прячем ped, не переносим его в menu-spawn.
    RequestCharacters(true)
end

CreateThread(function()
    DisableSpawnManagerAutoSpawn()

    Wait(5000)

    if not firstOpenDone then
        firstOpenDone = true
        OpenCharacterMenu()
    end
end)

RegisterCommand('chars', function()
    OpenCharacterMenu()
end, false)

RegisterCommand('char', function()
    OpenCharacterMenu()
end, false)

RegisterCommand('changechar', function()
    OpenCharacterMenu()
end, false)

RegisterNetEvent('cw-characters:client:accountNotReady', function()
    accountRetryCount = accountRetryCount + 1

    if accountRetryCount > 20 then
        Notify('Аккаунт не загрузился. Перезайди на сервер.')
        return
    end

    SetTimeout(1000, function()
        RequestCharacters(false)
    end)
end)

RegisterNetEvent('cw-characters:client:receiveCharacters', function(data, serverCurrentCharacterId)
    accountRetryCount = 0
    characters = data or {}

    currentCharacterId = serverCurrentCharacterId and tonumber(serverCurrentCharacterId) or nil

    if not currentCharacterId then
        for _, character in ipairs(characters) do
            if character.is_current == true or character.is_current == 1 or character.is_current == '1' then
                currentCharacterId = tonumber(character.id)
                break
            end
        end
    end

    if currentCharacterId then
        characterSelected = true
    end

    OpenUI()
end)

RegisterNetEvent('cw-characters:client:characterSelected', function(character)
    if not character then return end

    characterSelected = true
    currentCharacterId = tonumber(character.id)

    -- Не раскрываем menu-ped до завершения cw-spawn.
    -- Если /chars открыт во время игры, текущий ped и так стоит на месте.
    CloseUI(false)
    ApplyBasicAppearance(character)

    TriggerEvent('cw-spawn:client:spawnCharacter', character)
end)

RegisterNetEvent('cw-characters:client:selectFailed', function(message)
    Notify(message or 'Нельзя выбрать этого персонажа.')
    RequestCharacters(false)
end)

RegisterNetEvent('cw-characters:client:createFailed', function(message)
    Notify(message or 'Не удалось создать персонажа.')
    RequestCharacters(false)
end)

RegisterNetEvent('cw-characters:client:createSuccess', function()
    Notify('Персонаж создан.')
    RequestCharacters(false)
end)

RegisterNetEvent('cw-characters:client:deleteFailed', function(message)
    Notify(message or 'Не удалось удалить персонажа.')
    RequestCharacters(false)
end)

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
    if characterSelected then
        CloseUI(true)
        cb({ ok = true })
        return
    end

    Notify('Сначала выбери или создай персонажа.')
    cb({ ok = false })
end)

RegisterCommand('fixfocus', function()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    TriggerEvent('chat:addMessage', {
        color = { 120, 255, 120 },
        args = { 'ClearWork', 'Фокус сброшен.' }
    })
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DisableSpawnManagerAutoSpawn()
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    if hidePedForCurrentMenu then
        SetPedHiddenInCharacterMenu(false)
    end
end)
