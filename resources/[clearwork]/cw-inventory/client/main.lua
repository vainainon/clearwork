local Config = CWInventoryConfig or {}
local uiOpen = false
local lastState = nil

local function notify(message, color)
    TriggerEvent('chat:addMessage', {
        color = color or { 220, 220, 220 },
        multiline = true,
        args = { 'cw-inventory', tostring(message or '') }
    })
end

local function setUI(state)
    uiOpen = state == true
    SetNuiFocus(uiOpen, uiOpen)
    SendNUIMessage({ action = uiOpen and 'open' or 'close' })
end

local function syncWeapons(state)
    if not Config.EnableWeaponSync then return end
    if type(state) ~= 'table' or type(state.equipment) ~= 'table' then return end

    local ped = PlayerPedId()
    for _, item in pairs(state.equipment) do
        if item and item.weaponHash then
            local hash = GetHashKey(item.weaponHash)
            if not HasPedGotWeapon(ped, hash, false) then
                -- Для RedM на некоторых артефактах сигнатура отличается.
                -- Если оружие не выдаётся — оставь EnableWeaponSync=false и позже подберём конкретный native под билд.
                GiveWeaponToPed(ped, hash, 0, false, false)
            end
        end
    end
end

RegisterCommand(Config.OpenCommand or 'inventory', function()
    if Config.Debug then print('[cw-inventory] client command executed') end
    TriggerServerEvent('cw-inventory:server:openInventory')
end, false)

-- На части RedM-артефактов RegisterKeyMapping отсутствует.
-- Не вызываем его напрямую, иначе client/main.lua падает и NUI-события не регистрируются.
if type(RegisterKeyMapping) == 'function' then
    RegisterKeyMapping(Config.OpenCommand or 'inventory', 'Открыть инвентарь', 'keyboard', Config.OpenKey or 'I')
elseif Config.Debug then
    print('[cw-inventory] RegisterKeyMapping is not available on this RedM artifact; use /' .. tostring(Config.OpenCommand or 'inventory'))
end

RegisterNetEvent('cw-inventory:client:open', function()
    setUI(true)
end)

RegisterNetEvent('cw-inventory:client:setState', function(state)
    lastState = state or {}
    SendNUIMessage({ action = 'state', payload = lastState })
    syncWeapons(lastState)
end)

RegisterNetEvent('cw-inventory:client:error', function(message)
    notify(message or 'Ошибка инвентаря.', { 255, 80, 80 })
    SendNUIMessage({ action = 'notice', kind = 'error', message = tostring(message or 'Ошибка инвентаря.') })
end)

RegisterNetEvent('cw-inventory:client:success', function(message)
    notify(message or 'Готово.', { 80, 255, 120 })
    SendNUIMessage({ action = 'notice', kind = 'success', message = tostring(message or 'Готово.') })
end)

RegisterNUICallback('close', function(_, cb)
    setUI(false)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('cw-inventory:server:requestState')
    cb({ ok = true })
end)

RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('cw-inventory:server:moveItem', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('equipItem', function(data, cb)
    TriggerServerEvent('cw-inventory:server:equipItem', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('unequipItem', function(data, cb)
    TriggerServerEvent('cw-inventory:server:unequipItem', data or {})
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if uiOpen then
            Wait(0)
            DisableControlAction(0, 0x07CE1E61, true) -- attack
            DisableControlAction(0, 0xF84FA74F, true) -- aim
            if IsControlJustPressed(0, 0x156F7119) then -- ESC/backspace на многих раскладках
                setUI(false)
            end
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)
