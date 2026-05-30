local uiOpen = false

local function SetAdminUI(state)
    uiOpen = state

    SetNuiFocus(state, state)

    SendNUIMessage({
        action = state and 'open' or 'close'
    })
end

local function NotifyError(message)
    message = tostring(message or 'Ошибка.')

    print(('[cw-admin] %s'):format(message))

    TriggerEvent('chat:addMessage', {
        color = { 255, 80, 80 },
        multiline = true,
        args = { 'cw-admin', message }
    })

    if uiOpen then
        SendNUIMessage({
            action = 'error',
            message = message
        })
    end
end

RegisterCommand('cwadmin', function()
    -- ВАЖНО:
    -- Больше не открываем NUI сразу.
    -- Сначала сервер проверяет доступ.
    -- Если доступ есть, сервер вернет cw-admin:client:receiveCharacters.
    TriggerServerEvent('cw-admin:server:searchCharacters', '')
end, false)

RegisterCommand('adminchars', function()
    ExecuteCommand('cwadmin')
end, false)

RegisterCommand('closeadmin', function()
    SetAdminUI(false)
end, false)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })
end)

CreateThread(function()
    while true do
        if uiOpen then
            Wait(0)

            -- ESC
            if IsControlJustPressed(0, 0x156F7119) then
                SetAdminUI(false)
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('cw-admin:client:receiveCharacters', function(characters)
    -- Открываем окно только после успешной проверки доступа на сервере.
    SetAdminUI(true)

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
    NotifyError(message)
end)

RegisterNUICallback('searchCharacters', function(data, cb)
    TriggerServerEvent('cw-admin:server:searchCharacters', data.query or '')

    cb({
        ok = true
    })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    TriggerServerEvent('cw-admin:server:deleteCharacter', tonumber(data.id))

    cb({
        ok = true
    })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetAdminUI(false)

    cb({
        ok = true
    })
end)