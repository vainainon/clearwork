local uiOpen = false

local function SetAdminUI(state)
    uiOpen = state

    SetNuiFocus(state, state)

    SendNUIMessage({
        action = state and 'ui:open' or 'ui:close'
    })
end

local function Notify(message, color)
    TriggerEvent('chat:addMessage', {
        color = color or { 220, 220, 220 },
        multiline = true,
        args = { 'cw-admin', tostring(message or '') }
    })
end

RegisterCommand('cwadmin', function()
    TriggerServerEvent('cw-admin:server:openPanel')
end, false)

RegisterCommand('adminchars', function()
    ExecuteCommand('cwadmin')
end, false)

RegisterCommand('closeadmin', function()
    SetAdminUI(false)
end, false)

RegisterNetEvent('cw-admin:client:openPanel', function(data)
    SetAdminUI(true)

    SendNUIMessage({
        action = 'panel:open',
        payload = data or {}
    })
end)

RegisterNetEvent('cw-admin:client:dashboard:receive', function(data)
    SendNUIMessage({
        action = 'dashboard:set',
        payload = data or {}
    })
end)

RegisterNetEvent('cw-admin:client:characters:receive', function(characters)
    SendNUIMessage({
        action = 'characters:set',
        characters = characters or {}
    })
end)

RegisterNetEvent('cw-admin:client:characters:deleted', function(characterId)
    SendNUIMessage({
        action = 'characters:deleted',
        id = characterId
    })

    TriggerServerEvent('cw-admin:server:characters:search', '')
    TriggerServerEvent('cw-admin:server:dashboard:load')
end)

RegisterNetEvent('cw-admin:client:players:receive', function(players)
    SendNUIMessage({
        action = 'players:set',
        players = players or {}
    })
end)

RegisterNetEvent('cw-admin:client:error', function(message)
    message = tostring(message or 'Ошибка.')

    print(('[cw-admin] %s'):format(message))
    Notify(message, { 255, 80, 80 })

    SendNUIMessage({
        action = 'error',
        message = message
    })
end)

RegisterNetEvent('cw-admin:client:success', function(message)
    message = tostring(message or 'Готово.')

    Notify(message, { 80, 255, 120 })

    SendNUIMessage({
        action = 'success',
        message = message
    })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetAdminUI(false)

    cb({
        ok = true
    })
end)

RegisterNUICallback('dashboardLoad', function(_, cb)
    TriggerServerEvent('cw-admin:server:dashboard:load')

    cb({
        ok = true
    })
end)

RegisterNUICallback('charactersSearch', function(data, cb)
    TriggerServerEvent('cw-admin:server:characters:search', data.query or '')

    cb({
        ok = true
    })
end)

RegisterNUICallback('charactersDelete', function(data, cb)
    TriggerServerEvent('cw-admin:server:characters:delete', tonumber(data.id))

    cb({
        ok = true
    })
end)

RegisterNUICallback('playersList', function(_, cb)
    TriggerServerEvent('cw-admin:server:players:list')

    cb({
        ok = true
    })
end)

RegisterNUICallback('playersAction', function(data, cb)
    TriggerServerEvent(
        'cw-admin:server:players:action',
        data.action,
        tonumber(data.target),
        data.payload or {}
    )

    cb({
        ok = true
    })
end)

RegisterNUICallback('toolsToggle', function(data, cb)
    TriggerServerEvent('cw-admin:server:tools:toggle', data.tool)

    cb({
        ok = true
    })
end)

CreateThread(function()
    while true do
        if uiOpen then
            Wait(0)

            if IsControlJustPressed(0, 0x156F7119) then
                SetAdminUI(false)
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'ui:close'
    })
end)