local InventoryClientDebug = true
local InventoryClientVersion = 'v22-stack-amount-forward'
local unpackArgs = table.unpack or unpack

print(('[cw-admin:inventory:client] loaded %s'):format(InventoryClientVersion))

local function jsonDump(value)
    local ok, encoded = pcall(json.encode, value or {})
    if not ok then
        return '<json encode failed>'
    end
    encoded = tostring(encoded or '{}')
    if #encoded > 1200 then
        encoded = encoded:sub(1, 1200) .. '...<cut>'
    end
    return encoded
end

local function dbg(message, ...)
    if not InventoryClientDebug then return end
    local args = { ... }
    local ok, text = pcall(function()
        return ('[cw-admin:inventory:client:debug] ' .. tostring(message)):format(unpackArgs(args))
    end)
    print(ok and text or ('[cw-admin:inventory:client:debug] ' .. tostring(message)))
end

local function resolveCharacterId(data)
    data = type(data) == 'table' and data or {}

    local candidates = {
        data.characterId,
        data.character_id,
        data.id,
        data.character,
    }

    if type(data.target) == 'table' then
        candidates[#candidates + 1] = data.target.characterId
        candidates[#candidates + 1] = data.target.character_id
    end

    for _, candidate in ipairs(candidates) do
        local value = tonumber(candidate)
        if value and value > 0 then
            return value
        end
    end

    return nil
end

RegisterNUICallback('characterInventoryOpen', function(data, cb)
    local characterId = resolveCharacterId(data)
    dbg('NUI open data=%s resolvedCharacterId=%s', jsonDump(data), tostring(characterId))
    TriggerServerEvent('cw-admin:server:inventory:open', characterId)
    cb({ ok = true })
end)

local function normalizeAddItemPayload(data)
    data = type(data) == 'table' and data or {}
    local characterId = resolveCharacterId(data)
    local target = type(data.target) == 'table' and data.target or {}

    if characterId then
        data.characterId = characterId
        data.character_id = characterId
        target.characterId = characterId
        target.character_id = characterId
    end

    data.target = target
    data.itemName = data.itemName or data.item_name or data.name
    data.amount = data.amount or 1
    data.metadata = data.metadata or '{}'
    data.reason = data.reason or 'cw-admin inventory panel drag/drop'

    return data, characterId
end

local function handleAddItemNui(data, cb, origin)
    local payload, characterId = normalizeAddItemPayload(data)
    dbg(
        'NUI addItem %s payload=%s resolvedCharacterId=%s item=%s amount=%s target=%s',
        tostring(origin or 'unknown'),
        jsonDump(payload),
        tostring(characterId),
        tostring(payload.itemName),
        tostring(payload.amount),
        jsonDump(payload.target)
    )

    -- v14: передаём на сервер одну таблицу. Так проще отследить и меньше шанс,
    -- что RedM/NUI потеряет часть аргументов при drag/drop.
    TriggerServerEvent('cw-admin:server:inventory:addItemV14', payload)

    cb({ ok = true })
end

RegisterNUICallback('characterInventoryAddItemV14', function(data, cb)
    handleAddItemNui(data, cb, 'v14')
end)

-- Совместимость со старым JS-кэшем.
RegisterNUICallback('characterInventoryAddItem', function(data, cb)
    handleAddItemNui(data, cb, 'legacy_callback')
end)

local function normalizeInventoryActionPayload(data)
    data = type(data) == 'table' and data or {}
    local characterId = resolveCharacterId(data)
    local target = type(data.target) == 'table' and data.target or {}

    if characterId then
        data.characterId = characterId
        data.character_id = characterId
        target.characterId = characterId
        target.character_id = characterId
    end

    data.target = target
    data.itemId = data.itemId or data.item_id or data.id
    data.reason = data.reason or 'cw-admin inventory panel'
    return data, characterId
end

RegisterNUICallback('characterInventoryMoveItemV17', function(data, cb)
    local payload, characterId = normalizeInventoryActionPayload(data)
    dbg(
        'NUI moveItem v17 payload=%s resolvedCharacterId=%s itemId=%s target=%s',
        jsonDump(payload),
        tostring(characterId),
        tostring(payload.itemId),
        jsonDump(payload.target)
    )
    TriggerServerEvent('cw-admin:server:inventory:moveItemV17', payload)
    cb({ ok = true })
end)

RegisterNUICallback('characterInventoryDeleteItemV17', function(data, cb)
    local payload, characterId = normalizeInventoryActionPayload(data)
    dbg(
        'NUI deleteItem v17 payload=%s resolvedCharacterId=%s itemId=%s',
        jsonDump(payload),
        tostring(characterId),
        tostring(payload.itemId)
    )
    TriggerServerEvent('cw-admin:server:inventory:deleteItemV17', payload)
    cb({ ok = true })
end)

RegisterNUICallback('characterInventoryRefresh', function(data, cb)
    local characterId = resolveCharacterId(data)
    dbg('NUI refresh data=%s resolvedCharacterId=%s', jsonDump(data), tostring(characterId))
    TriggerServerEvent('cw-admin:server:inventory:open', characterId)
    cb({ ok = true })
end)

RegisterNetEvent('cw-admin:client:inventory:receive', function(payload)
    payload = type(payload) == 'table' and payload or {}
    local state = type(payload.state) == 'table' and payload.state or {}
    local definitions = type(payload.definitions) == 'table' and payload.definitions or (type(state.definitions) == 'table' and state.definitions or {})

    local containerCount = type(state.containers) == 'table' and #state.containers or 0
    local slotCount = type(state.equipmentSlots) == 'table' and #state.equipmentSlots or 0
    local itemCount = type(state.items) == 'table' and #state.items or 0
    local definitionCount = 0
    for _ in pairs(definitions) do definitionCount = definitionCount + 1 end

    dbg(
        'receive payload characterId=%s stateCharacterId=%s revision=%s containers=%s slots=%s items=%s definitions=%s',
        tostring(payload.characterId or payload.character_id),
        tostring(state.character_id or state.characterId),
        tostring(state.revision),
        tostring(containerCount),
        tostring(slotCount),
        tostring(itemCount),
        tostring(definitionCount)
    )

    SendNUIMessage({
        action = 'inventory:receive',
        payload = payload or {}
    })
end)
