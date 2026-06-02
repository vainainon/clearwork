local Config = CWInventoryConfig or {}
local InventoryClientVersion = 'v26-ground-pile-anim'
print(('[cw-inventory:client] loaded %s'):format(InventoryClientVersion))
local uiOpen = false
local lastState = nil
local dropBags = {}

local function playGroundLootAnim(kind)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    CreateThread(function()
        local scenario = Config.GroundLootScenario or 'WORLD_HUMAN_CROUCH_INSPECT'
        local duration = tonumber(Config.GroundLootAnimMs) or 900
        pcall(function()
            TaskStartScenarioInPlace(ped, GetHashKey(scenario), duration, true, false, false, false)
        end)
        Wait(duration)
        pcall(function() ClearPedTasks(ped) end)
    end)
end

local function removeDropBag(pileId)
    pileId = tostring(pileId or '')
    if pileId == '' then return end
    local obj = dropBags[pileId]
    dropBags[pileId] = nil
    if obj and obj ~= 0 then
        pcall(function()
            if DoesEntityExist(obj) then DeleteObject(obj) end
        end)
    end
end


local function currentCoordsPayload()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped)
    }
end

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
    TriggerServerEvent('cw-inventory:server:openInventory', { coords = currentCoordsPayload() })
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

RegisterNetEvent('cw-inventory:client:ensureDropBag', function(data)
    data = type(data) == 'table' and data or {}
    local pileId = tostring(data.pile_id or data.pileId or data.drop_id or data.dropId or 'default')
    if dropBags[pileId] and dropBags[pileId] ~= 0 and DoesEntityExist(dropBags[pileId]) then
        return
    end

    local coords = data.coords
    if type(coords) ~= 'table' then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        coords = { x = c.x, y = c.y, z = c.z }
    end

    local modelName = tostring(data.model or Config.DropBagModel or 'p_bag01x')
    local hash = GetHashKey(modelName)

    if not IsModelValid(hash) then
        if Config.Debug then
            print(('[cw-inventory] drop bag model is not valid: %s'):format(modelName))
        end
        return
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + 2500
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(0)
    end

    if not HasModelLoaded(hash) then
        if Config.Debug then
            print(('[cw-inventory] drop bag model load timeout: %s'):format(modelName))
        end
        return
    end

    local obj = CreateObject(hash, tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0, false, false, false)
    if obj and obj ~= 0 then
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        dropBags[pileId] = obj
    end

    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('cw-inventory:client:spawnDropBag', function(data)
    TriggerEvent('cw-inventory:client:ensureDropBag', data)
end)

RegisterNetEvent('cw-inventory:client:despawnDropBag', function(data)
    data = type(data) == 'table' and data or {}
    removeDropBag(data.pile_id or data.pileId or data.drop_id or data.dropId)
end)

RegisterNUICallback('close', function(_, cb)
    setUI(false)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('cw-inventory:server:requestState', { coords = currentCoordsPayload() })
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

RegisterNUICallback('dropItem', function(data, cb)
    data = type(data) == 'table' and data or {}
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    data.coords = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped)
    }
    playGroundLootAnim('drop')
    TriggerServerEvent('cw-inventory:server:dropItem', data)
    cb({ ok = true })
end)


RegisterNUICallback('pickupDropItem', function(data, cb)
    data = type(data) == 'table' and data or {}
    data.coords = currentCoordsPayload()
    playGroundLootAnim('pickup')
    TriggerServerEvent('cw-inventory:server:pickupDropItem', data)
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
    for pileId in pairs(dropBags) do
        removeDropBag(pileId)
    end
end)
