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

local function SetCharacterUI(state)
    uiOpen = state
    SetNuiFocus(state, state)

    if state then
        SetPedHiddenInCharacterMenu(true)
    else
        SetPedHiddenInCharacterMenu(false)
    end

    SendNUIMessage({
        action = 'setVisible',
        visible = state
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

RegisterNetEvent('cw-characters:client:receiveCharacters', function(data)
    characters = data or {}

    SendNUIMessage({
        action = 'setCharacters',
        characters = characters,
        currentCharacterId = currentCharacterId
    })

    SetCharacterUI(true)
end)

RegisterNetEvent('cw-characters:client:characterSelected', function(character)
    if not character then return end

    characterSelected = true
    currentCharacterId = character.id

    SetCharacterUI(false)
    ApplyBasicAppearance(character)

    TriggerEvent('cw-spawn:client:spawnCharacter', character)
end)

RegisterNetEvent('cw-characters:client:selectFailed', function(message)
    Notify(message or 'Нельзя выбрать этого персонажа.')

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
    if not characterSelected then
        Notify('Сначала выбери или создай персонажа.')
        cb({ ok = false })
        return
    end

    SetCharacterUI(false)
    cb({ ok = true })
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