local Config = CWCharactersClientConfig

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
        args = { 'Персонажи', tostring(message or '') }
    })
end

local function IsDeathSwitchBlocked()
    if GetResourceState('cw-death') ~= 'started' then
        return false
    end

    local ok, locked = pcall(function()
        return exports['cw-death']:IsSwitchBlocked()
    end)

    return ok and locked == true
end

local function SetPedHiddenInCharacterMenu(state)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

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

    if hidePedForCurrentMenu then
        SetPedHiddenInCharacterMenu(true)
    end

    SendNUIMessage({
        action = 'open',
        characters = characters,
        currentCharacterId = currentCharacterId,
        activeCharacterId = currentCharacterId,
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
    SendNUIMessage({ action = 'close' })
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

    if characterSelected and IsDeathSwitchBlocked() then
        Notify('Смена персонажа недоступна: текущий персонаж ранен или убит.')
        return
    end

    local firstMenu = not characterSelected
    hidePedForCurrentMenu = firstMenu

    if firstMenu then
        DoScreenFadeOut(200)
        Wait(250)

        TriggerEvent('cw-spawn:client:prepareCharacterMenu', true)
        Wait(600)
        SetPedHiddenInCharacterMenu(true)

        RequestCharacters(false)
        Wait(250)
        DoScreenFadeIn(400)
        return
    end

    RequestCharacters(true)
end

CreateThread(function()
    DisableSpawnManagerAutoSpawn()

    Wait(tonumber(Config.AutoOpenDelay) or 5000)

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

    if accountRetryCount > (tonumber(Config.AccountRetryLimit) or 20) then
        Notify('Аккаунт не загрузился. Перезайди на сервер.')
        return
    end

    SetTimeout(tonumber(Config.AccountRetryDelay) or 1000, function()
        RequestCharacters(false)
    end)
end)

RegisterNetEvent('cw-characters:client:receiveCharacters', function(data, serverCurrentCharacterId)
    accountRetryCount = 0
    characters = data or {}
    currentCharacterId = serverCurrentCharacterId and tonumber(serverCurrentCharacterId) or nil

    if not currentCharacterId then
        for _, character in ipairs(characters) do
            if character.is_current == true or character.is_current == 1 or character.is_current == '1' or character.active_character == true then
                currentCharacterId = tonumber(character.id)
                break
            end
        end
    end

    characterSelected = currentCharacterId ~= nil
    OpenUI()
end)

RegisterNetEvent('cw-characters:client:characterSelected', function(character)
    if not character then return end

    characterSelected = true
    currentCharacterId = tonumber(character.id)

    CloseUI(false)
    ApplyBasicAppearance(character)
    TriggerEvent('cw-spawn:client:spawnCharacter', character)
end)

RegisterNetEvent('cw-characters:client:openFailed', function(message)
    Notify(message or 'Сейчас нельзя открыть меню персонажей.')
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
    if IsDeathSwitchBlocked() then
        Notify('Смена персонажа недоступна: текущий персонаж ранен или убит.')
        cb({ ok = false })
        return
    end

    if data and data.id then
        TriggerServerEvent('cw-characters:server:selectCharacter', {
            id = tonumber(data.id),
            currentPosition = characterSelected and GetCurrentCoords() or nil
        })
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
