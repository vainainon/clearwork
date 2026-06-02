local OpenedCharacterInventories = {}

local function canUseCharacterInventory(src)
    if src == 0 then
        return true
    end

    if CWAdmin.IsOwner and CWAdmin.IsOwner(src) then
        return true
    end

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
    characterId = tonumber(characterId)
    if not characterId then
        return nil
    end

    return MySQL.single.await([[
        SELECT id, account_id, firstname, lastname, slot
        FROM characters
        WHERE id = ?
        LIMIT 1
    ]], { characterId })
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
    if raw == nil or raw == '' then
        return {}
    end

    if type(raw) == 'table' then
        return raw
    end

    raw = tostring(raw or '')
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then
        return data
    end

    return nil
end

local function trim(value)
    value = tostring(value or '')
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function normalizeItemName(raw)
    local value = trim(raw)
    if value == '' then
        return ''
    end

    -- Защита от старого UI/кэша, если вместо value прилетает строка вида "Бинт — bandage".
    local afterDash = value:match('[—%-]%s*([%w_%-]+)%s*$')
    if afterDash and afterDash ~= '' then
        value = afterDash
    end

    value = value:gsub('[^%w_%-]', '')
    return value
end

local function resolveCharacterId(src, data)
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

    -- Главный фикс: если NUI/drag-and-drop не прислал characterId,
    -- берём персонажа из последнего открытого окна инвентаря этого админа.
    local opened = tonumber(OpenedCharacterInventories[src])
    if opened and opened > 0 then
        return opened
    end

    return nil
end

local function normalizeTarget(target)
    if type(target) ~= 'table' then
        return nil
    end

    local result = {
        type = tostring(target.type or ''),
        containerId = tostring(target.containerId or target.container_id or ''),
        slot = tostring(target.slot or target.equip_slot or ''),
        rotated = target.rotated == true or target.rotated == 1 or target.rotated == '1',
    }

    if target.x ~= nil then
        result.x = tonumber(target.x)
    end

    if target.y ~= nil then
        result.y = tonumber(target.y)
    end

    if result.type == '' and result.slot ~= '' then
        result.type = 'slot'
    elseif result.type == '' and result.containerId ~= '' then
        result.type = 'container'
    end

    return result
end

local function loadInventoryPayload(characterId)
    characterId = tonumber(characterId)
    if not characterId then
        return nil, 'Некорректный ID персонажа.'
    end

    local okState, stateOrErr = callInventoryExport('GetInventoryState', characterId)
    if not okState then
        return nil, stateOrErr
    end

    local okLogs, logsOrErr = callInventoryExport('GetInventoryLogs', characterId, 80)
    if not okLogs then
        return nil, logsOrErr
    end

    local okDefs, definitionsOrErr = callInventoryExport('GetItemDefinitions')
    if not okDefs then
        return nil, definitionsOrErr
    end

    return {
        characterId = characterId,
        character_id = characterId,
        character = getCharacterInfo(characterId),
        state = stateOrErr or {},
        logs = logsOrErr or {},
        definitions = definitionsOrErr or {},
    }, nil
end

local function sendInventoryPayload(src, characterId)
    characterId = tonumber(characterId)
    if not characterId then
        sendInventoryError(src, 'Некорректный ID персонажа.')
        return false
    end

    local payload, err = loadInventoryPayload(characterId)
    if not payload then
        sendInventoryError(src, 'Не удалось загрузить инвентарь: ' .. tostring(err))
        return false
    end

    OpenedCharacterInventories[src] = characterId
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

    data = type(data) == 'table' and data or {}

    local characterId = resolveCharacterId(src, data)
    local itemName = normalizeItemName(data.itemName or data.item_name or data.name)
    local amount = math.floor(tonumber(data.amount) or 1)
    local reason = tostring(data.reason or 'cw-admin inventory panel')
    local metadata = decodeMetadata(data.metadata)
    local target = normalizeTarget(data.target)

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

    local ok, result, err

    if target then
        ok, result, err = callInventoryExport(
            'AddItemToCharacterAt',
            characterId,
            itemName,
            amount,
            metadata,
            target,
            src,
            getActorAccountId(src),
            reason
        )
    else
        ok, result, err = callInventoryExport(
            'AddItemToCharacter',
            characterId,
            itemName,
            amount,
            metadata,
            src,
            getActorAccountId(src),
            reason
        )
    end

    if not ok then
        sendInventoryError(src, 'Ошибка экспорта инвентаря: ' .. tostring(result))
        return
    end

    if result ~= true then
        sendInventoryError(src, tostring(err or 'Предмет не выдан.'))
        return
    end

    OpenedCharacterInventories[src] = characterId

    CWAdmin.AdminLog(src, 'inventory_add_item', {
        character_id = characterId,
        item_name = itemName,
        amount = amount,
        target = target,
        reason = reason,
    })

    CWAdmin.SendSuccess(src, ('Выдано: %s x%s.'):format(itemName, amount))
    sendInventoryPayload(src, characterId)
end)

AddEventHandler('playerDropped', function()
    OpenedCharacterInventories[source] = nil
end)
