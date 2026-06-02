local function canUseCharacterInventory(src)
    if src == 0 then return true end
    if CWAdmin.IsOwner and CWAdmin.IsOwner(src) then return true end

    local role = 'user'
    if CWAdmin.GetAdminRole then
        role = CWAdmin.GetAdminRole(src) or 'user'
    end

    return role == 'general' or role == 'admin'
end

local function sendInventoryError(src, message)
    CWAdmin.SendError(src, message or 'Ошибка инвентаря.')
end

local function getActorAccountId(src)
    local player = CWAdmin.GetCWPlayer and CWAdmin.GetCWPlayer(src) or nil
    return player and tonumber(player.account_id) or nil
end

local function getCharacterInfo(characterId)
    return MySQL.single.await([[SELECT id, account_id, firstname, lastname, slot
        FROM characters WHERE id = ? LIMIT 1]], { characterId })
end

local unpackArgs = table.unpack or unpack

local function callInventoryExport(name, ...)
    local args = { ... }
    local ok, a, b, c = pcall(function()
        return exports['cw-inventory'][name](unpackArgs(args))
    end)

    if not ok then
        return false, tostring(a or 'cw-inventory export failed')
    end

    return true, a, b, c
end

local function decodeMetadata(raw)
    if raw == nil or raw == '' then return {} end
    if type(raw) == 'table' then return raw end
    raw = tostring(raw or '')
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return nil
end

local function loadInventoryPayload(characterId)
    local okState, stateOrErr = callInventoryExport('GetInventoryState', characterId)
    if not okState then return nil, stateOrErr end

    local okLogs, logsOrErr = callInventoryExport('GetInventoryLogs', characterId, 80)
    if not okLogs then return nil, logsOrErr end

    local okDefs, definitionsOrErr = callInventoryExport('GetItemDefinitions')
    if not okDefs then return nil, definitionsOrErr end

    return {
        character = getCharacterInfo(characterId),
        state = stateOrErr or {},
        logs = logsOrErr or {},
        definitions = definitionsOrErr or {}
    }, nil
end

local function sendInventoryPayload(src, characterId)
    local payload, err = loadInventoryPayload(characterId)
    if not payload then
        sendInventoryError(src, 'Не удалось загрузить инвентарь: ' .. tostring(err))
        return false
    end

    TriggerClientEvent('cw-admin:client:inventory:receive', src, payload)
    return true
end

RegisterNetEvent('cw-admin:server:inventory:open', function(characterId)
    local src = source

    if not canUseCharacterInventory(src) then
        sendInventoryError(src, 'Нет доступа к инвентарю персонажей.')
        return
    end

    characterId = tonumber(characterId)
    if not characterId then
        sendInventoryError(src, 'Некорректный ID персонажа.')
        return
    end

    local character = getCharacterInfo(characterId)
    if not character then
        sendInventoryError(src, 'Персонаж не найден.')
        return
    end

    sendInventoryPayload(src, characterId)
end)

RegisterNetEvent('cw-admin:server:inventory:addItem', function(data)
    local src = source

    if not canUseCharacterInventory(src) then
        sendInventoryError(src, 'Нет доступа к выдаче предметов.')
        return
    end

    data = data or {}
    local characterId = tonumber(data.characterId)
    local itemName = tostring(data.itemName or '')
    local amount = math.floor(tonumber(data.amount) or 1)
    local reason = tostring(data.reason or 'cw-admin')
    local metadata = decodeMetadata(data.metadata)

    if not characterId then
        sendInventoryError(src, 'Некорректный ID персонажа.')
        return
    end

    if itemName == '' then
        sendInventoryError(src, 'Выбери предмет.')
        return
    end

    if amount < 1 or amount > 500 then
        sendInventoryError(src, 'Количество должно быть от 1 до 500.')
        return
    end

    if not metadata then
        sendInventoryError(src, 'Metadata должен быть пустым или валидным JSON-объектом.')
        return
    end

    local character = getCharacterInfo(characterId)
    if not character then
        sendInventoryError(src, 'Персонаж не найден.')
        return
    end

    local ok, result, err = callInventoryExport(
        'AddItemToCharacter',
        characterId,
        itemName,
        amount,
        metadata,
        src,
        getActorAccountId(src),
        reason
    )

    if not ok then
        sendInventoryError(src, 'Ошибка экспорта инвентаря: ' .. tostring(result))
        return
    end

    if result ~= true then
        sendInventoryError(src, tostring(err or 'Предмет не выдан.'))
        return
    end

    CWAdmin.AdminLog(src, 'inventory_add_item', {
        character_id = characterId,
        item_name = itemName,
        amount = amount,
        reason = reason
    })

    CWAdmin.SendSuccess(src, ('Выдано: %s x%s.'):format(itemName, amount))
    sendInventoryPayload(src, characterId)
end)
