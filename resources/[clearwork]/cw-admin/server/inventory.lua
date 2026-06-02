local InventoryDebug = true
local InventoryIntegrationVersion = 'v22-stack-amount-forward'
local OpenedCharacterInventories = {}
local unpackArgs = table.unpack or unpack

print(('[cw-admin:inventory] loaded %s'):format(InventoryIntegrationVersion))

local function safeJson(value)
    local ok, encoded = pcall(json.encode, value or {})
    if not ok then
        return '<json encode failed>'
    end
    encoded = tostring(encoded or '{}')
    if #encoded > 1600 then
        encoded = encoded:sub(1, 1600) .. '...<cut>'
    end
    return encoded
end

local function dbg(message, ...)
    if not InventoryDebug then return end
    local args = { ... }
    local ok, text = pcall(function()
        return ('[cw-admin:inventory:debug] ' .. tostring(message)):format(unpackArgs(args))
    end)
    print(ok and text or ('[cw-admin:inventory:debug] ' .. tostring(message)))
end

local function errlog(message, ...)
    local args = { ... }
    local ok, text = pcall(function()
        return ('[cw-admin:inventory:error] ' .. tostring(message)):format(unpackArgs(args))
    end)
    print(ok and text or ('[cw-admin:inventory:error] ' .. tostring(message)))
end

local function countMap(value)
    if type(value) ~= 'table' then return 0 end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function summarizeState(state)
    state = type(state) == 'table' and state or {}
    return ('character_id=%s revision=%s containers=%s equipmentSlots=%s equipment=%s items=%s definitions=%s')
        :format(
            tostring(state.character_id or state.characterId),
            tostring(state.revision),
            tostring(type(state.containers) == 'table' and #state.containers or 0),
            tostring(type(state.equipmentSlots) == 'table' and #state.equipmentSlots or 0),
            tostring(countMap(state.equipment)),
            tostring(type(state.items) == 'table' and #state.items or 0),
            tostring(countMap(state.definitions))
        )
end

local function summarizeDefinitions(definitions)
    return tostring(countMap(definitions))
end

local function firstTable(...)
    for i = 1, select('#', ...) do
        local value = select(i, ...)
        if type(value) == 'table' then
            return value
        end
    end
    return nil
end

local function firstNonNil(...)
    for i = 1, select('#', ...) do
        local value = select(i, ...)
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function normalizeAddItemArguments(first, itemNameArg, amountArg, metadataArg, targetArg, reasonArg, rawArg)
    -- Старый формат: TriggerServerEvent(..., dataTable)
    if type(first) == 'table' and itemNameArg == nil then
        return first
    end

    -- Новый формат: TriggerServerEvent(..., characterId, itemName, amount, metadata, target, reason, rawTable)
    local data = type(rawArg) == 'table' and rawArg or {}
    data.characterId = firstNonNil(data.characterId, data.character_id, first)
    data.character_id = data.characterId
    data.itemName = firstNonNil(data.itemName, data.item_name, data.name, itemNameArg)
    data.amount = firstNonNil(data.amount, amountArg, 1)
    data.metadata = firstNonNil(data.metadata, metadataArg, '{}')
    data.target = type(data.target) == 'table' and data.target or (type(targetArg) == 'table' and targetArg or nil)
    data.reason = firstNonNil(data.reason, reasonArg, 'cw-admin inventory panel drag/drop')

    if type(data.target) == 'table' and data.characterId then
        data.target.characterId = firstNonNil(data.target.characterId, data.target.character_id, data.characterId)
        data.target.character_id = data.target.characterId
    end

    return data
end

local function canUseCharacterInventory(src)
    if src == 0 then
        dbg('permission src=console allowed=true')
        return true
    end

    if CWAdmin.IsOwner and CWAdmin.IsOwner(src) then
        dbg('permission src=%s role=owner allowed=true', tostring(src))
        return true
    end

    local role = 'user'
    if CWAdmin.GetAdminRole then
        role = CWAdmin.GetAdminRole(src) or 'user'
    end

    local allowed = role == 'general' or role == 'admin'
    dbg('permission src=%s role=%s allowed=%s', tostring(src), tostring(role), tostring(allowed))
    return allowed
end

local function sendInventoryError(src, message)
    message = tostring(message or 'Ошибка инвентаря.')
    errlog('send error src=%s message=%s', tostring(src), message)

    if CWAdmin.SendError then
        CWAdmin.SendError(src, message)
        return
    end

    TriggerClientEvent('chat:addMessage', src, {
        color = { 190, 40, 40 },
        multiline = true,
        args = { 'cw-admin', message }
    })
end

local function sendInventorySuccess(src, message)
    message = tostring(message or 'Готово.')
    dbg('send success src=%s message=%s', tostring(src), message)

    if CWAdmin.SendSuccess then
        CWAdmin.SendSuccess(src, message)
        return
    end

    TriggerClientEvent('chat:addMessage', src, {
        color = { 40, 190, 80 },
        multiline = true,
        args = { 'cw-admin', message }
    })
end

local function getActorAccountId(src)
    local player = CWAdmin.GetCWPlayer and CWAdmin.GetCWPlayer(src) or nil
    return player and tonumber(player.account_id) or nil
end

local function getCharacterInfo(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end

    return MySQL.single.await([[
        SELECT id, account_id, firstname, lastname, slot
        FROM characters
        WHERE id = ?
        LIMIT 1
    ]], { characterId })
end

local function callInventoryExport(name, ...)
    local args = { ... }
    dbg('calling cw-inventory export=%s args=%s', tostring(name), safeJson(args))

    local ok, a, b, c = pcall(function()
        -- В Cfx Lua export proxy рассчитан на вызов через ':' и получает self первым аргументом.
        -- При динамическом вызове через [name](...) нужно передать proxy вручную, иначе первый
        -- реальный аргумент съедается как self: characterId=36 превращается в nil/смещается.
        local invExports = exports['cw-inventory']
        return invExports[name](invExports, unpackArgs(args))
    end)

    if not ok then
        errlog('export failed name=%s error=%s', tostring(name), tostring(a))
        return false, tostring(a or 'cw-inventory export failed')
    end

    if name == 'GetInventoryState' then
        dbg('export result %s ok=true stateSummary=%s rawType=%s', tostring(name), summarizeState(a), type(a))
    elseif name == 'GetItemDefinitions' then
        dbg('export result %s ok=true definitions=%s', tostring(name), summarizeDefinitions(a))
    else
        dbg('export result %s ok=true a=%s b=%s c=%s', tostring(name), tostring(a), tostring(b), tostring(c))
    end

    return true, a, b, c
end

local function decodeMetadata(raw)
    if raw == nil or raw == '' then return {} end
    if type(raw) == 'table' then return raw end

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
    if value == '' then return '' end

    -- Защита от старого UI/кэша: "Бинт — bandage" -> "bandage".
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
            dbg('resolved characterId=%s from payload for src=%s', tostring(value), tostring(src))
            return value
        end
    end

    local opened = tonumber(OpenedCharacterInventories[src])
    if opened and opened > 0 then
        dbg('resolved characterId=%s from opened window fallback for src=%s', tostring(opened), tostring(src))
        return opened
    end

    errlog('failed to resolve characterId src=%s data=%s opened=%s', tostring(src), safeJson(data), tostring(OpenedCharacterInventories[src]))
    return nil
end

local function normalizeTarget(target)
    if type(target) ~= 'table' then return nil end

    local result = {
        type = tostring(target.type or ''),
        containerId = tostring(target.containerId or target.container_id or ''),
        slot = tostring(target.slot or target.equip_slot or ''),
        rotated = target.rotated == true or target.rotated == 1 or target.rotated == '1',
    }

    if target.x ~= nil then result.x = tonumber(target.x) end
    if target.y ~= nil then result.y = tonumber(target.y) end
    if target.amount ~= nil then result.amount = tonumber(target.amount) end
    if target.split ~= nil then result.split = target.split == true or target.split == 1 or target.split == '1' end

    if result.type == '' and result.slot ~= '' then
        result.type = 'slot'
    elseif result.type == '' and result.containerId ~= '' then
        result.type = 'container'
    end

    if result.type == '' then
        return nil
    end

    return result
end

local function loadInventoryPayload(characterId)
    characterId = tonumber(characterId)
    if not characterId then
        return nil, 'Некорректный ID персонажа.'
    end

    dbg('load payload start characterId=%s', tostring(characterId))

    local okState, stateA, stateB, stateC = callInventoryExport('GetInventoryState', characterId)
    if not okState then
        return nil, stateA
    end

    local okLogs, logsA, logsB, logsC = callInventoryExport('GetInventoryLogs', characterId, 80)
    if not okLogs then
        return nil, logsA
    end

    local okDefs, defsA, defsB, defsC = callInventoryExport('GetItemDefinitions')
    if not okDefs then
        return nil, defsA
    end

    local character = getCharacterInfo(characterId)

    -- v12: поддерживаем оба варианта export API:
    --   return state
    --   return true, state
    -- чтобы cw-admin не показывал пустой state, если API позже будет обёрнут в ok/result.
    local state = firstTable(stateA, stateB, stateC) or {}
    local logs = firstTable(logsA, logsB, logsC) or {}
    local definitions = firstTable(defsA, defsB, defsC) or {}

    if not state.character_id and not state.characterId then
        state.character_id = characterId
        state.characterId = characterId
    end

    dbg(
        'load payload done characterId=%s state={%s} logs=%s definitions=%s characterFound=%s',
        tostring(characterId),
        summarizeState(state),
        tostring(#logs),
        summarizeDefinitions(definitions),
        tostring(character ~= nil)
    )

    return {
        characterId = characterId,
        character_id = characterId,
        character = character,
        state = state,
        logs = logs,
        definitions = definitions,
        debug = {
            from = 'cw-admin/server/inventory.lua',
            stateSummary = summarizeState(state),
            logs = #logs,
            definitions = countMap(definitions),
        }
    }, nil
end

local function sendInventoryPayload(src, characterId)
    characterId = tonumber(characterId)
    if not characterId then
        sendInventoryError(src, 'Некорректный ID персонажа.')
        return false
    end

    dbg('send payload start src=%s characterId=%s', tostring(src), tostring(characterId))

    local payload, err = loadInventoryPayload(characterId)
    if not payload then
        sendInventoryError(src, 'Не удалось загрузить инвентарь: ' .. tostring(err))
        return false
    end

    OpenedCharacterInventories[src] = characterId
    dbg('send payload to client src=%s characterId=%s %s', tostring(src), tostring(characterId), tostring(payload.debug and payload.debug.stateSummary or ''))
    TriggerClientEvent('cw-admin:client:inventory:receive', src, payload)
    return true
end

RegisterNetEvent('cw-admin:server:inventory:open', function(characterId)
    local src = source
    dbg('event open src=%s rawCharacterId=%s openedFallback=%s', tostring(src), tostring(characterId), tostring(OpenedCharacterInventories[src]))

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
    dbg('open character lookup characterId=%s found=%s data=%s', tostring(characterId), tostring(character ~= nil), safeJson(character))
    if not character then
        sendInventoryError(src, 'Персонаж не найден.')
        return
    end

    sendInventoryPayload(src, characterId)
end)

local function handleAddItemEvent(src, data, origin)
    data = type(data) == 'table' and data or {}
    dbg(
        'event addItem %s src=%s raw=%s openedFallback=%s',
        tostring(origin or 'unknown'),
        tostring(src),
        safeJson(data),
        tostring(OpenedCharacterInventories[src])
    )

    if not canUseCharacterInventory(src) then
        sendInventoryError(src, 'Нет доступа к выдаче предметов.')
        return
    end

    local characterId = resolveCharacterId(src, data)
    local itemName = normalizeItemName(data.itemName or data.item_name or data.name)
    local amount = math.floor(tonumber(data.amount) or 1)
    local reason = tostring(data.reason or 'cw-admin inventory panel')
    local metadata = decodeMetadata(data.metadata)
    local target = normalizeTarget(data.target)

    dbg(
        'addItem normalized src=%s characterId=%s item=%s amount=%s target=%s metadataValid=%s reason=%s',
        tostring(src),
        tostring(characterId),
        tostring(itemName),
        tostring(amount),
        safeJson(target),
        tostring(metadata ~= nil),
        tostring(reason)
    )

    if not characterId then
        errlog('addItem abort missing characterId src=%s normalizedData=%s openedFallback=%s', tostring(src), safeJson(data), tostring(OpenedCharacterInventories[src]))
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
    dbg('addItem character lookup characterId=%s found=%s', tostring(characterId), tostring(character ~= nil))
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

    dbg('addItem export finished ok=%s result=%s err=%s', tostring(ok), tostring(result), tostring(err))

    if not ok then
        sendInventoryError(src, 'Ошибка экспорта инвентаря: ' .. tostring(result))
        return
    end

    if result ~= true then
        sendInventoryError(src, tostring(err or 'Предмет не выдан.'))
        return
    end

    OpenedCharacterInventories[src] = characterId

    if CWAdmin.AdminLog then
        CWAdmin.AdminLog(src, 'inventory_add_item', {
            character_id = characterId,
            item_name = itemName,
            amount = amount,
            target = target,
            reason = reason,
        })
    end

    sendInventorySuccess(src, ('Выдано: %s x%s.'):format(itemName, amount))
    sendInventoryPayload(src, characterId)
end


local function handleMoveItemEvent(src, data, origin)
    data = type(data) == 'table' and data or {}
    dbg('event moveItem %s src=%s raw=%s openedFallback=%s', tostring(origin or 'unknown'), tostring(src), safeJson(data), tostring(OpenedCharacterInventories[src]))

    if not canUseCharacterInventory(src) then
        sendInventoryError(src, 'Нет доступа к перемещению предметов.')
        return
    end

    local characterId = resolveCharacterId(src, data)
    local itemId = tonumber(data.itemId or data.item_id or data.id)
    local target = normalizeTarget(data.target)
    local reason = tostring(data.reason or 'cw-admin inventory panel move')

    dbg('moveItem normalized src=%s characterId=%s itemId=%s target=%s reason=%s', tostring(src), tostring(characterId), tostring(itemId), safeJson(target), reason)

    if not characterId then
        sendInventoryError(src, 'Некорректный ID персонажа.')
        return
    end

    if not itemId then
        sendInventoryError(src, 'Некорректный ID предмета.')
        return
    end

    if not target then
        sendInventoryError(src, 'Некорректный слот/позиция.')
        return
    end

    local character = getCharacterInfo(characterId)
    if not character then
        sendInventoryError(src, 'Персонаж не найден.')
        return
    end

    local ok, result, err = callInventoryExport(
        'MoveItemForCharacter',
        characterId,
        itemId,
        target,
        src,
        getActorAccountId(src),
        reason
    )

    dbg('moveItem export finished ok=%s result=%s err=%s', tostring(ok), tostring(result), tostring(err))

    if not ok then
        sendInventoryError(src, 'Ошибка экспорта инвентаря: ' .. tostring(result))
        return
    end

    if result ~= true then
        sendInventoryError(src, tostring(err or 'Предмет не перемещён.'))
        return
    end

    OpenedCharacterInventories[src] = characterId

    if CWAdmin.AdminLog then
        CWAdmin.AdminLog(src, 'inventory_move_item', {
            character_id = characterId,
            item_id = itemId,
            target = target,
            reason = reason,
        })
    end

    sendInventorySuccess(src, 'Предмет перемещён.')
    sendInventoryPayload(src, characterId)
end

local function handleDeleteItemEvent(src, data, origin)
    data = type(data) == 'table' and data or {}
    dbg('event deleteItem %s src=%s raw=%s openedFallback=%s', tostring(origin or 'unknown'), tostring(src), safeJson(data), tostring(OpenedCharacterInventories[src]))

    if not canUseCharacterInventory(src) then
        sendInventoryError(src, 'Нет доступа к удалению предметов.')
        return
    end

    local characterId = resolveCharacterId(src, data)
    local itemId = tonumber(data.itemId or data.item_id or data.id)
    local reason = tostring(data.reason or 'cw-admin inventory panel right click delete')

    dbg('deleteItem normalized src=%s characterId=%s itemId=%s reason=%s', tostring(src), tostring(characterId), tostring(itemId), reason)

    if not characterId then
        sendInventoryError(src, 'Некорректный ID персонажа.')
        return
    end

    if not itemId then
        sendInventoryError(src, 'Некорректный ID предмета.')
        return
    end

    local character = getCharacterInfo(characterId)
    if not character then
        sendInventoryError(src, 'Персонаж не найден.')
        return
    end

    local ok, result, err = callInventoryExport(
        'DeleteItemFromCharacter',
        characterId,
        itemId,
        src,
        getActorAccountId(src),
        reason
    )

    dbg('deleteItem export finished ok=%s result=%s err=%s', tostring(ok), tostring(result), tostring(err))

    if not ok then
        sendInventoryError(src, 'Ошибка экспорта инвентаря: ' .. tostring(result))
        return
    end

    if result ~= true then
        sendInventoryError(src, tostring(err or 'Предмет не удалён.'))
        return
    end

    OpenedCharacterInventories[src] = characterId

    if CWAdmin.AdminLog then
        CWAdmin.AdminLog(src, 'inventory_delete_item', {
            character_id = characterId,
            item_id = itemId,
            reason = reason,
        })
    end

    sendInventorySuccess(src, 'Предмет удалён.')
    sendInventoryPayload(src, characterId)
end

-- v14: основной путь из NUI. Клиент передаёт одну нормализованную таблицу,
-- чтобы не ловить рассыпание аргументов между NUI -> client -> server.
RegisterNetEvent('cw-admin:server:inventory:addItemV14', function(data)
    handleAddItemEvent(source, data, 'v14_table')
end)

-- Совместимость со старыми клиентами/кэшем: поддерживаем старый event и оба формата аргументов.
RegisterNetEvent('cw-admin:server:inventory:addItem', function(first, itemNameArg, amountArg, metadataArg, targetArg, reasonArg, rawArg)
    local data = normalizeAddItemArguments(first, itemNameArg, amountArg, metadataArg, targetArg, reasonArg, rawArg)
    handleAddItemEvent(source, data, 'legacy_compat')
end)


RegisterNetEvent('cw-admin:server:inventory:moveItemV17', function(data)
    handleMoveItemEvent(source, data, 'v17_table')
end)

RegisterNetEvent('cw-admin:server:inventory:deleteItemV17', function(data)
    handleDeleteItemEvent(source, data, 'v17_table')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print(('[cw-admin:inventory] started %s'):format(InventoryIntegrationVersion))
end)

AddEventHandler('playerDropped', function()
    dbg('playerDropped src=%s clear openedCharacter=%s', tostring(source), tostring(OpenedCharacterInventories[source]))
    OpenedCharacterInventories[source] = nil
end)
