local Config = CWInventoryConfig or {}
local Items = CWInventoryItems or {}
local Locks = {}

local function dbg(message, ...)
    if not Config.Debug then return end
    print(('[cw-inventory] ' .. tostring(message)):format(...))
end

local function enc(value)
    return json.encode(value or {})
end

local function dec(value)
    if not value or value == '' then return {} end
    local ok, data = pcall(json.decode, value)
    if ok and type(data) == 'table' then return data end
    return {}
end


local SchemaReady = false

local function ensureSchema()
    if SchemaReady then return true end

    local ok, err = pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `cw_inventory_state` (
            `character_id` INT NOT NULL,
            `revision` INT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`character_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])

        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `cw_inventory_items` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `character_id` INT NOT NULL,
            `item_name` VARCHAR(64) NOT NULL,
            `amount` INT NOT NULL DEFAULT 1,
            `metadata` LONGTEXT NULL,
            `container_id` VARCHAR(64) NULL,
            `x` INT NULL,
            `y` INT NULL,
            `rotated` TINYINT(1) NOT NULL DEFAULT 0,
            `equip_slot` VARCHAR(64) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_cw_inv_character` (`character_id`),
            KEY `idx_cw_inv_location` (`character_id`, `container_id`),
            KEY `idx_cw_inv_equipment` (`character_id`, `equip_slot`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])

        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `cw_inventory_logs` (
            `id` BIGINT NOT NULL AUTO_INCREMENT,
            `character_id` INT NOT NULL,
            `account_id` INT NULL,
            `actor_source` INT NULL,
            `action` VARCHAR(64) NOT NULL,
            `item_id` INT NULL,
            `item_name` VARCHAR(64) NULL,
            `amount` INT NULL,
            `from_container` VARCHAR(64) NULL,
            `to_container` VARCHAR(64) NULL,
            `from_slot` VARCHAR(64) NULL,
            `to_slot` VARCHAR(64) NULL,
            `before_json` LONGTEXT NULL,
            `after_json` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_cw_inv_logs_character` (`character_id`, `created_at`),
            KEY `idx_cw_inv_logs_action` (`action`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]])
    end)

    if not ok then
        print(('[cw-inventory] database migration failed: %s'):format(tostring(err)))
        return false
    end

    SchemaReady = true
    print('[cw-inventory] database tables checked / migrated')
    return true
end

local function copy(t)
    return dec(enc(t or {}))
end

local function getPlayer(src)
    local ok, player = pcall(function()
        return exports['cw-core']:GetPlayer(src)
    end)
    if not ok then return nil end
    return player
end


-- ВАЖНО: cw-inventory не знает ничего про роли, ACE и /cwadmin.
-- Этот ресурс отвечает только за доменную логику: состояние, валидация, сохранение и логи.
-- Внешние серверные ресурсы могут вызывать exports ниже, но права проверяют у себя.


local function getCharacter(src)
    local player = getPlayer(src)
    if not player or type(player.character) ~= 'table' then return nil, nil, 'Сначала выбери персонажа.' end
    local characterId = tonumber(player.character.id)
    if not characterId then return nil, nil, 'Сначала выбери персонажа.' end
    return player, characterId, nil
end

local function withLock(characterId, cb)
    characterId = tonumber(characterId)
    if not characterId then return false, 'Некорректный ID персонажа.' end
    if Locks[characterId] then
        return false, 'Инвентарь занят другим действием. Повтори через секунду.'
    end
    Locks[characterId] = true
    local ok, a, b, c = pcall(cb)
    Locks[characterId] = nil
    if not ok then
        print(('[cw-inventory] lock action failed for character %s: %s'):format(characterId, tostring(a)))
        return false, 'Ошибка инвентаря.'
    end
    return a, b, c
end

local function ensureState(characterId)
    if not ensureSchema() then error('database schema is not ready') end
    local exists = MySQL.scalar.await('SELECT character_id FROM cw_inventory_state WHERE character_id = ? LIMIT 1', { characterId })
    if exists then return end
    MySQL.insert.await('INSERT INTO cw_inventory_state (character_id, revision) VALUES (?, 0)', { characterId })

    for _, starter in ipairs(Config.DefaultStarterItems or {}) do
        local name = tostring(starter.name or '')
        local def = Items.Get(name)
        if def then
            MySQL.insert.await([[INSERT INTO cw_inventory_items
                (character_id, item_name, amount, metadata, container_id, x, y, rotated, equip_slot)
                VALUES (?, ?, ?, ?, 'pockets', ?, ?, 0, NULL)]],
                { characterId, name, tonumber(starter.amount) or 1, enc(starter.metadata or {}), 0, 0 })
        end
    end
end

local function bumpRevision(characterId)
    MySQL.update.await('UPDATE cw_inventory_state SET revision = revision + 1 WHERE character_id = ?', { characterId })
end

local function getRevision(characterId)
    ensureState(characterId)
    return tonumber(MySQL.scalar.await('SELECT revision FROM cw_inventory_state WHERE character_id = ? LIMIT 1', { characterId })) or 0
end

local function logAction(characterId, accountId, action, data)
    if not ensureSchema() then return end
    data = data or {}
    MySQL.insert.await([[INSERT INTO cw_inventory_logs
        (character_id, account_id, actor_source, action, item_id, item_name, amount, from_container, to_container, from_slot, to_slot, before_json, after_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        characterId,
        accountId,
        data.actor_source,
        tostring(action or 'unknown'),
        data.item_id,
        data.item_name,
        data.amount,
        data.from_container,
        data.to_container,
        data.from_slot,
        data.to_slot,
        data.before_json and enc(data.before_json) or nil,
        data.after_json and enc(data.after_json) or nil
    })
end

local function normalizeItem(row)
    if not row then return nil end
    local def = Items.Get(row.item_name) or {}
    local rotated = tonumber(row.rotated) == 1 or row.rotated == true
    local w, h = Items.GetSize(row.item_name, rotated)
    return {
        id = tonumber(row.id),
        character_id = tonumber(row.character_id),
        item_name = row.item_name,
        label = def.label or row.item_name,
        description = def.description or '',
        type = def.type or 'item',
        amount = tonumber(row.amount) or 1,
        metadata = dec(row.metadata),
        container_id = row.container_id,
        x = row.x ~= nil and tonumber(row.x) or nil,
        y = row.y ~= nil and tonumber(row.y) or nil,
        rotated = rotated,
        equip_slot = row.equip_slot,
        width = w,
        height = h,
        base_width = tonumber(def.width) or 1,
        base_height = tonumber(def.height) or 1,
        stack = tonumber(def.stack) or 1,
        weight = tonumber(def.weight) or 0,
        weaponHash = def.weaponHash,
        container = def.container
    }
end

local function getItems(characterId)
    if not ensureSchema() then error('database schema is not ready') end
    local rows = MySQL.query.await('SELECT * FROM cw_inventory_items WHERE character_id = ? ORDER BY id ASC', { characterId }) or {}
    local out = {}
    for _, row in ipairs(rows) do
        local item = normalizeItem(row)
        if item and Items.Get(item.item_name) then
            out[#out + 1] = item
        end
    end
    return out
end

local function getItem(characterId, itemId)
    if not ensureSchema() then error('database schema is not ready') end
    local row = MySQL.single.await('SELECT * FROM cw_inventory_items WHERE id = ? AND character_id = ? LIMIT 1', { itemId, characterId })
    return normalizeItem(row)
end

local function buildEquipment(items)
    local equipment = {}
    for _, item in ipairs(items or {}) do
        if item.equip_slot then
            equipment[item.equip_slot] = item
        end
    end
    return equipment
end

local function buildContainers(items)
    local containers = {}
    for id, data in pairs(Config.BaseContainers or {}) do
        containers[id] = {
            id = id,
            label = data.label or id,
            width = tonumber(data.width) or 1,
            height = tonumber(data.height) or 1,
            order = tonumber(data.order) or 999,
            source = 'base'
        }
    end

    local equipment = buildEquipment(items)
    for _, item in pairs(equipment) do
        local def = Items.Get(item.item_name)
        if def and def.container and def.container.id then
            local c = def.container
            containers[c.id] = {
                id = c.id,
                label = c.label or c.id,
                width = tonumber(c.width) or 1,
                height = tonumber(c.height) or 1,
                order = tonumber(c.order) or 500,
                source = item.equip_slot,
                source_item = item.id
            }
        end
    end

    local out = {}
    for _, c in pairs(containers) do out[#out + 1] = c end
    table.sort(out, function(a, b) return (a.order or 999) < (b.order or 999) end)
    return out, containers, equipment
end

local function getEquipmentSlots()
    local slots = copy(Config.EquipmentSlots or {})
    table.sort(slots, function(a, b) return (a.order or 999) < (b.order or 999) end)
    return slots
end

local function slotConfig(slot)
    for _, cfg in ipairs(Config.EquipmentSlots or {}) do
        if cfg.id == slot then return cfg end
    end
    return nil
end

local function canEquipToSlot(item, slot)
    local cfg = slotConfig(slot)
    if not cfg or not item then return false end
    return cfg.accepts and cfg.accepts[item.type] == true
end

local function overlaps(aX, aY, aW, aH, bX, bY, bW, bH)
    return aX < bX + bW and aX + aW > bX and aY < bY + bH and aY + aH > bY
end

local function canPlace(characterId, item, containerId, x, y, rotated, ignoreItemId)
    containerId = tostring(containerId or '')
    x = tonumber(x)
    y = tonumber(y)
    if x == nil or y == nil then return false, 'Некорректная позиция.' end
    x = math.floor(x)
    y = math.floor(y)

    local items = getItems(characterId)
    local _, containers = buildContainers(items)
    local container = containers[containerId]
    if not container then return false, 'Этот контейнер недоступен.' end

    local w, h = Items.GetSize(item.item_name, rotated)
    if x < 0 or y < 0 or x + w > container.width or y + h > container.height then
        return false, 'Предмет не помещается.'
    end

    for _, other in ipairs(items) do
        if other.id ~= tonumber(ignoreItemId) and other.container_id == containerId and other.equip_slot == nil then
            if overlaps(x, y, w, h, tonumber(other.x) or 0, tonumber(other.y) or 0, other.width, other.height) then
                return false, 'Место занято.'
            end
        end
    end

    return true, nil
end

local function firstFreePlace(characterId, itemName)
    local temp = { item_name = itemName }
    local items = getItems(characterId)
    local containers = buildContainers(items)
    for _, container in ipairs(containers) do
        for y = 0, container.height - 1 do
            for x = 0, container.width - 1 do
                local ok = canPlace(characterId, temp, container.id, x, y, false, -1)
                if ok then
                    return container.id, x, y, false
                end
            end
        end
    end
    return nil
end

local function metadataEquals(a, b)
    return enc(a or {}) == enc(b or {})
end

local function getState(characterId)
    ensureState(characterId)
    local items = getItems(characterId)
    local containers, _, equipment = buildContainers(items)
    return {
        character_id = characterId,
        revision = getRevision(characterId),
        containers = containers,
        equipmentSlots = getEquipmentSlots(),
        equipment = equipment,
        items = items,
        definitions = Items.GetClientDefinitions()
    }
end

local function sendState(src, openAfter)
    local _, characterId, err = getCharacter(src)
    if err then
        print(('[cw-inventory] cannot open inventory for source %s: %s'):format(src, tostring(err)))
        TriggerClientEvent('cw-inventory:client:error', src, err)
        return false
    end

    local ok, stateOrErr = pcall(function()
        return getState(characterId)
    end)

    if not ok then
        print(('[cw-inventory] failed to build inventory state for source %s, character %s: %s'):format(src, characterId, tostring(stateOrErr)))
        TriggerClientEvent('cw-inventory:client:error', src, 'Ошибка базы инвентаря. Проверь консоль сервера.')
        return false
    end

    TriggerClientEvent('cw-inventory:client:setState', src, stateOrErr)
    if openAfter then
        TriggerClientEvent('cw-inventory:client:open', src)
    end
    return true
end

local function moveItem(src, payload)
    payload = payload or {}
    local player, characterId, err = getCharacter(src)
    if err then return false, err end

    return withLock(characterId, function()
        local itemId = tonumber(payload.itemId)
        local item = getItem(characterId, itemId)
        if not item then return false, 'Предмет не найден.' end

        local toContainer = tostring(payload.containerId or '')
        local x = tonumber(payload.x)
        local y = tonumber(payload.y)
        local rotated = payload.rotated == true or payload.rotated == 1
        local before = copy(item)

        local ok, msg = canPlace(characterId, item, toContainer, x, y, rotated, item.id)
        if not ok then return false, msg end

        MySQL.update.await([[UPDATE cw_inventory_items
            SET container_id = ?, x = ?, y = ?, rotated = ?, equip_slot = NULL
            WHERE id = ? AND character_id = ?]],
            { toContainer, math.floor(x), math.floor(y), rotated and 1 or 0, item.id, characterId })

        bumpRevision(characterId)
        local after = getItem(characterId, item.id)
        logAction(characterId, player.account_id, 'move', {
            item_id = item.id,
            item_name = item.item_name,
            amount = item.amount,
            from_container = before.container_id,
            to_container = toContainer,
            from_slot = before.equip_slot,
            before_json = before,
            after_json = after
        })
        return true
    end)
end

local function equipItem(src, payload)
    payload = payload or {}
    local player, characterId, err = getCharacter(src)
    if err then return false, err end

    return withLock(characterId, function()
        local itemId = tonumber(payload.itemId)
        local slot = tostring(payload.slot or '')
        local item = getItem(characterId, itemId)
        if not item then return false, 'Предмет не найден.' end
        if not canEquipToSlot(item, slot) then return false, 'Этот предмет нельзя положить в этот слот.' end

        local occupied = MySQL.scalar.await('SELECT id FROM cw_inventory_items WHERE character_id = ? AND equip_slot = ? LIMIT 1', { characterId, slot })
        if occupied and tonumber(occupied) ~= item.id then
            return false, 'Слот уже занят.'
        end

        local before = copy(item)
        MySQL.update.await([[UPDATE cw_inventory_items
            SET container_id = NULL, x = NULL, y = NULL, rotated = 0, equip_slot = ?
            WHERE id = ? AND character_id = ?]], { slot, item.id, characterId })

        bumpRevision(characterId)
        local after = getItem(characterId, item.id)
        logAction(characterId, player.account_id, 'equip', {
            item_id = item.id,
            item_name = item.item_name,
            amount = item.amount,
            from_container = before.container_id,
            to_slot = slot,
            before_json = before,
            after_json = after
        })
        return true
    end)
end

local function unequipItem(src, payload)
    payload = payload or {}
    local player, characterId, err = getCharacter(src)
    if err then return false, err end

    return withLock(characterId, function()
        local itemId = tonumber(payload.itemId)
        local item = getItem(characterId, itemId)
        if not item then return false, 'Предмет не найден.' end
        if not item.equip_slot then return false, 'Предмет не экипирован.' end

        local def = Items.Get(item.item_name)
        if def and def.container and def.container.id then
            local count = tonumber(MySQL.scalar.await(
                'SELECT COUNT(*) FROM cw_inventory_items WHERE character_id = ? AND container_id = ? AND equip_slot IS NULL',
                { characterId, def.container.id }
            )) or 0
            if count > 0 then
                return false, 'Сначала освободи вместимость этой одежды.'
            end
        end

        local toContainer = tostring(payload.containerId or '')
        local x = tonumber(payload.x)
        local y = tonumber(payload.y)
        local rotated = payload.rotated == true or payload.rotated == 1
        local before = copy(item)

        local ok, msg = canPlace(characterId, item, toContainer, x, y, rotated, item.id)
        if not ok then return false, msg end

        MySQL.update.await([[UPDATE cw_inventory_items
            SET container_id = ?, x = ?, y = ?, rotated = ?, equip_slot = NULL
            WHERE id = ? AND character_id = ?]],
            { toContainer, math.floor(x), math.floor(y), rotated and 1 or 0, item.id, characterId })

        bumpRevision(characterId)
        local after = getItem(characterId, item.id)
        logAction(characterId, player.account_id, 'unequip', {
            item_id = item.id,
            item_name = item.item_name,
            amount = item.amount,
            from_slot = before.equip_slot,
            to_container = toContainer,
            before_json = before,
            after_json = after
        })
        return true
    end)
end

local function addItemToCharacter(characterId, itemName, amount, metadata, actorAccountId, actorSource, reason)
    itemName = tostring(itemName or '')
    amount = math.max(1, tonumber(amount) or 1)
    metadata = metadata or {}
    local def = Items.Get(itemName)
    if not def then return false, 'Такого предмета нет в CWInventoryItems.' end

    ensureState(characterId)
    return withLock(characterId, function()
        local remaining = amount
        local stackMax = tonumber(def.stack) or 1

        if stackMax > 1 then
            local rows = MySQL.query.await([[SELECT * FROM cw_inventory_items
                WHERE character_id = ? AND item_name = ? AND equip_slot IS NULL
                ORDER BY id ASC]], { characterId, itemName }) or {}
            for _, row in ipairs(rows) do
                if remaining <= 0 then break end
                local item = normalizeItem(row)
                if item and item.amount < stackMax and metadataEquals(item.metadata, metadata) then
                    local add = math.min(remaining, stackMax - item.amount)
                    MySQL.update.await('UPDATE cw_inventory_items SET amount = amount + ? WHERE id = ?', { add, item.id })
                    remaining = remaining - add
                    logAction(characterId, actorAccountId, 'add_stack', {
                        actor_source = actorSource,
                        item_id = item.id,
                        item_name = itemName,
                        amount = add,
                        to_container = item.container_id,
                        before_json = item,
                        after_json = getItem(characterId, item.id)
                    })
                end
            end
        end

        while remaining > 0 do
            local stackAmount = math.min(remaining, stackMax)
            local containerId, x, y, rotated = firstFreePlace(characterId, itemName)
            if not containerId then
                return false, 'Нет свободного места под предмет.'
            end
            local insertId = MySQL.insert.await([[INSERT INTO cw_inventory_items
                (character_id, item_name, amount, metadata, container_id, x, y, rotated, equip_slot)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)]],
                { characterId, itemName, stackAmount, enc(metadata), containerId, x, y, rotated and 1 or 0 })
            remaining = remaining - stackAmount
            logAction(characterId, actorAccountId, 'add', {
                actor_source = actorSource,
                item_id = insertId,
                item_name = itemName,
                amount = stackAmount,
                to_container = containerId,
                after_json = getItem(characterId, insertId),
                before_json = { reason = reason or 'add' }
            })
        end

        bumpRevision(characterId)
        return true
    end)
end

local function openInventoryForSource(src, reason)
    src = tonumber(src) or 0
    if src <= 0 then return end

    if Config.Debug then
        print(('[cw-inventory] open request from source %s via %s'):format(src, tostring(reason or 'unknown')))
    end

    local ok = sendState(src, true)
    if Config.Debug then
        print(('[cw-inventory] open result for source %s: %s'):format(src, tostring(ok)))
    end
end

-- Команда есть на сервере, чтобы /cwinv из чата гарантированно открывал инвентарь.
-- Client-side команда оставлена как дополнительный путь, но без обязательной RegisterKeyMapping.
RegisterCommand(Config.OpenCommand or 'inventory', function(src)
    openInventoryForSource(src, 'server_command')
end, false)

RegisterNetEvent('cw-inventory:server:openInventory', function()
    openInventoryForSource(source, 'client_event')
end)

RegisterNetEvent('cw-inventory:server:requestState', function()
    sendState(source, false)
end)

RegisterNetEvent('cw-inventory:server:moveItem', function(payload)
    local src = source
    local ok, msg = moveItem(src, payload)
    if not ok then TriggerClientEvent('cw-inventory:client:error', src, msg or 'Не удалось переместить предмет.') end
    sendState(src)
end)

RegisterNetEvent('cw-inventory:server:equipItem', function(payload)
    local src = source
    local ok, msg = equipItem(src, payload)
    if not ok then TriggerClientEvent('cw-inventory:client:error', src, msg or 'Не удалось экипировать предмет.') end
    sendState(src)
end)

RegisterNetEvent('cw-inventory:server:unequipItem', function(payload)
    local src = source
    local ok, msg = unequipItem(src, payload)
    if not ok then TriggerClientEvent('cw-inventory:client:error', src, msg or 'Не удалось снять предмет.') end
    sendState(src)
end)

exports('GetInventoryState', function(characterId)
    characterId = tonumber(characterId)
    if not characterId then return nil end
    return getState(characterId)
end)

exports('GetInventoryLogs', function(characterId, limit)
    if not ensureSchema() then return {} end
    characterId = tonumber(characterId)
    if not characterId then return {} end
    return MySQL.query.await([[SELECT * FROM cw_inventory_logs WHERE character_id = ? ORDER BY id DESC LIMIT ?]], {
        characterId,
        math.min(tonumber(limit) or 50, 200)
    }) or {}
end)

exports('AddItemToCharacter', function(characterId, itemName, amount, metadata, actorSource, actorAccountId, reason)
    -- Только server-side API для доверенных ресурсов. Права здесь не проверяются специально.
    return addItemToCharacter(tonumber(characterId), itemName, amount, metadata or {}, actorAccountId, actorSource, reason or 'resource_export')
end)

exports('GetItemDefinitions', function()
    return Items.GetClientDefinitions()
end)


AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(500)
        ensureSchema()
    end)
end)
