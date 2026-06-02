local Config = CWInventoryConfig or {}
local InventoryServerVersion = 'v25-ground-loot-delete-contents'

print(('[cw-inventory] loaded %s'):format(InventoryServerVersion))

-- Защитный fallback: инвентарь должен иметь базовые контейнеры/слоты даже если
-- RedM не подхватил server/config.lua после копирования файлов без refresh.
Config.OpenCommand = Config.OpenCommand or 'inventory'
Config.Debug = Config.Debug == true

if type(Config.BaseContainers) ~= 'table' then
    Config.BaseContainers = {
        pockets = { label = 'Карманы', width = 4, height = 2, order = 10 },
        belt = { label = 'Пояс', width = 3, height = 1, order = 20 }
    }
end

if type(Config.EquipmentSlots) ~= 'table' then
    Config.EquipmentSlots = {
        { id = 'hat', label = 'Головной убор', accepts = { clothing_hat = true }, order = 10 },
        { id = 'coat', label = 'Верхняя одежда', accepts = { clothing_coat = true }, order = 20 },
        { id = 'shirt', label = 'Рубаха', accepts = { clothing_shirt = true }, order = 25 },
        { id = 'pants', label = 'Штаны', accepts = { clothing_pants = true }, order = 30 },
        { id = 'boots', label = 'Обувь', accepts = { clothing_boots = true }, order = 40 },
        { id = 'vest', label = 'Разгрузка', accepts = { clothing_vest = true }, order = 50 },
        { id = 'holster_left', label = 'Кобура Л', accepts = { weapon_revolver = true, weapon_pistol = true }, order = 60 },
        { id = 'holster_right', label = 'Кобура П', accepts = { weapon_revolver = true, weapon_pistol = true }, order = 70 },
        { id = 'back_long_1', label = 'Двуручное 1', accepts = { weapon_longarm = true }, order = 80 },
        { id = 'back_long_2', label = 'Двуручное 2', accepts = { weapon_longarm = true }, order = 90 },
        { id = 'accessory_1', label = 'Украшение 1', accepts = { accessory = true }, order = 100 },
        { id = 'accessory_2', label = 'Украшение 2', accepts = { accessory = true }, order = 110 }
    }
end

if type(Config.DefaultStarterItems) ~= 'table' then
    Config.DefaultStarterItems = {}
end

local Locks = {}

-- Временная серверная куча предметов на земле.
-- Позже это можно вынести в отдельный cw-drops/cw-worlditems и сохранять в БД.
local GroundDrops = {}
local NextGroundDropId = 1
Config.GroundLootRadius = tonumber(Config.GroundLootRadius) or 1.5
Config.GroundLootWidth = tonumber(Config.GroundLootWidth) or 6
Config.GroundLootHeight = tonumber(Config.GroundLootHeight) or 8

-- cw-inventory не использует общий скрипт. Справочник предметов живёт отдельно в cw-items,
-- а инвентарь получает данные только через server exports.
local Items = {}

local function safeItemExport(exportName, a, b, c)
    local ok, result = pcall(function()
        -- В Cfx Lua export proxy рассчитан на вызов через ':' и получает self первым аргументом.
        -- При динамическом вызове через [exportName](...) нужно передать proxy вручную,
        -- иначе первый реальный аргумент съедается как self.
        -- Без этого GetClientDefinitions() работал, а GetItem('bread') приходил в cw-items как nil.
        local itemExports = exports['cw-items']
        local fn = itemExports and itemExports[exportName]
        if type(fn) ~= 'function' then
            return nil
        end

        return fn(itemExports, a, b, c)
    end)

    if not ok then
        print(('[cw-inventory] cw-items export %s failed: %s'):format(tostring(exportName), tostring(result)))
        return nil
    end

    return result
end

function Items.Get(name)
    return safeItemExport('GetItem', name)
end

function Items.Exists(name)
    return safeItemExport('ItemExists', name) == true
end

function Items.GetClientDefinitions()
    return safeItemExport('GetClientDefinitions') or {}
end

function Items.GetSize(name, rotated)
    local def = Items.Get(name)
    if not def then return 1, 1 end

    local w = tonumber(def.width) or 1
    local h = tonumber(def.height) or 1

    if rotated then
        return h, w
    end

    return w, h
end

local function dbg(message, ...)
    if not Config.Debug then return end
    print(('[cw-inventory:debug] ' .. tostring(message)):format(...))
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


local function vectorDistance(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return 999999.0 end
    local ax, ay, az = tonumber(a.x) or 0.0, tonumber(a.y) or 0.0, tonumber(a.z) or 0.0
    local bx, by, bz = tonumber(b.x) or 0.0, tonumber(b.y) or 0.0, tonumber(b.z) or 0.0
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function getSourceCoords(src)
    src = tonumber(src) or 0
    if src <= 0 then return nil end

    local ok, ped = pcall(GetPlayerPed, src)
    if ok and ped and ped ~= 0 then
        local okCoords, coords = pcall(GetEntityCoords, ped)
        if okCoords and coords then
            return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
        end
    end

    return nil
end

local function packGroundDropsForCoords(coords)
    local width = math.max(1, tonumber(Config.GroundLootWidth) or 6)
    local height = math.max(1, tonumber(Config.GroundLootHeight) or 8)
    local nearby = {}

    for _, drop in pairs(GroundDrops) do
        if drop and type(drop.item) == 'table' and vectorDistance(coords, drop.coords) <= (Config.GroundLootRadius or 1.5) then
            nearby[#nearby + 1] = drop
        end
    end

    table.sort(nearby, function(a, b) return (a.id or 0) < (b.id or 0) end)

    local occupied = {}
    local out = {}

    local function isFree(x, y, w, h)
        if x < 0 or y < 0 or x + w > width or y + h > height then return false end
        for yy = y, y + h - 1 do
            for xx = x, x + w - 1 do
                if occupied[yy .. ':' .. xx] then return false end
            end
        end
        return true
    end

    local function occupy(x, y, w, h)
        for yy = y, y + h - 1 do
            for xx = x, x + w - 1 do
                occupied[yy .. ':' .. xx] = true
            end
        end
    end

    for _, drop in ipairs(nearby) do
        local item = copy(drop.item)
        local w = tonumber(item.width) or 1
        local h = tonumber(item.height) or 1
        local placed = false
        for y = 0, height - 1 do
            if placed then break end
            for x = 0, width - 1 do
                if isFree(x, y, w, h) then
                    item.drop_id = drop.id
                    item.ground_id = drop.id
                    item.id = 'drop_' .. tostring(drop.id)
                    item.x = x
                    item.y = y
                    item.container_id = 'ground'
                    item.equip_slot = nil
                    item.is_ground = true
                    item.from_ground = true
                    out[#out + 1] = item
                    occupy(x, y, w, h)
                    placed = true
                    break
                end
            end
        end
    end

    return {
        id = 'ground',
        label = 'Земля рядом',
        width = width,
        height = height,
        radius = Config.GroundLootRadius or 1.5,
        items = out
    }
end

local function addGroundDropFromItem(item, coords, src, characterId)
    if type(item) ~= 'table' then return nil end
    coords = type(coords) == 'table' and coords or getSourceCoords(src) or { x = 0.0, y = 0.0, z = 0.0 }
    local dropId = NextGroundDropId
    NextGroundDropId = NextGroundDropId + 1

    GroundDrops[dropId] = {
        id = dropId,
        item = copy(item),
        coords = { x = tonumber(coords.x) or 0.0, y = tonumber(coords.y) or 0.0, z = tonumber(coords.z) or 0.0 },
        dropped_by = tonumber(characterId),
        dropped_source = tonumber(src) or 0,
        created_at = os.time()
    }

    return GroundDrops[dropId]
end

local function characterExists(characterId)
    characterId = tonumber(characterId)
    if not characterId then return false end
    local id = MySQL.scalar.await('SELECT id FROM characters WHERE id = ? LIMIT 1', { characterId })
    return tonumber(id) ~= nil
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

local bumpRevision
local logAction
local getItem
local firstFreePlace

local function ensureState(characterId)
    if not ensureSchema() then error('database schema is not ready') end
    local exists = MySQL.scalar.await('SELECT character_id FROM cw_inventory_state WHERE character_id = ? LIMIT 1', { characterId })
    if exists then return end
    MySQL.insert.await('INSERT INTO cw_inventory_state (character_id, revision) VALUES (?, 0)', { characterId })

    for _, starter in ipairs(Config.DefaultStarterItems or {}) do
        local name = tostring(starter.name or '')
        local def = Items.Get(name)
        if def then
            local containerId, x, y, rotated = firstFreePlace(characterId, name)
            if containerId then
                local insertId = MySQL.insert.await([[INSERT INTO cw_inventory_items
                    (character_id, item_name, amount, metadata, container_id, x, y, rotated, equip_slot)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)]],
                    { characterId, name, tonumber(starter.amount) or 1, enc(starter.metadata or {}), containerId, x, y, rotated and 1 or 0 })

                logAction(characterId, nil, 'starter', {
                    item_id = insertId,
                    item_name = name,
                    amount = tonumber(starter.amount) or 1,
                    to_container = containerId,
                    after_json = getItem(characterId, insertId)
                })
            end
        end
    end

    bumpRevision(characterId)
end

bumpRevision = function(characterId)
    MySQL.update.await('UPDATE cw_inventory_state SET revision = revision + 1 WHERE character_id = ?', { characterId })
end

local function getRevision(characterId)
    ensureState(characterId)
    return tonumber(MySQL.scalar.await('SELECT revision FROM cw_inventory_state WHERE character_id = ? LIMIT 1', { characterId })) or 0
end

logAction = function(characterId, accountId, action, data)
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

getItem = function(characterId, itemId)
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

    -- Нельзя убрать предмет в контейнер, который создан этим же предметом.
    -- Пример бага: снять штаны и положить их в карманы этих же штанов, затем надеть другие штаны
    -- и увидеть старые штаны внутри новых карманов. Любой контейнер одежды имеет source_item,
    -- поэтому проверка работает не только для штанов, но и для разгрузки/пальто/будущих сумок.
    if item and item.id and container.source_item and tonumber(container.source_item) == tonumber(item.id) then
        return false, 'Нельзя положить предмет в его собственную вместимость.'
    end

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

firstFreePlace = function(characterId, itemName)
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

local function stackMaxForItemName(itemName)
    local def = Items.Get(itemName) or {}
    return math.max(1, tonumber(def.stack) or 1)
end

local function findStackAt(characterId, containerId, x, y, ignoreItemId, itemName, metadata)
    containerId = tostring(containerId or '')
    x = tonumber(x)
    y = tonumber(y)
    if containerId == '' or x == nil or y == nil then return nil end

    local stackMax = stackMaxForItemName(itemName)
    if stackMax <= 1 then return nil end

    for _, other in ipairs(getItems(characterId)) do
        if other.id ~= tonumber(ignoreItemId) and other.equip_slot == nil and other.container_id == containerId then
            local ox = tonumber(other.x) or 0
            local oy = tonumber(other.y) or 0
            if x >= ox and x < ox + (tonumber(other.width) or 1) and y >= oy and y < oy + (tonumber(other.height) or 1) then
                if other.item_name == itemName and metadataEquals(other.metadata, metadata) and (tonumber(other.amount) or 1) < stackMax then
                    return other, stackMax
                end
                return nil, stackMax, 'Место занято.'
            end
        end
    end

    return nil, stackMax
end

local function updateSourceStackAfterTake(characterId, sourceItem, takeAmount)
    takeAmount = math.floor(tonumber(takeAmount) or 0)
    local current = tonumber(sourceItem and sourceItem.amount) or 0
    if takeAmount <= 0 or current <= 0 then return false, 'Некорректное количество.' end

    if takeAmount >= current then
        MySQL.update.await('DELETE FROM cw_inventory_items WHERE id = ? AND character_id = ?', { sourceItem.id, characterId })
        return true, 'deleted'
    end

    MySQL.update.await('UPDATE cw_inventory_items SET amount = amount - ? WHERE id = ? AND character_id = ?', { takeAmount, sourceItem.id, characterId })
    return true, 'decremented'
end

local function getState(characterId, src)
    characterId = tonumber(characterId)
    ensureState(characterId)
    local items = getItems(characterId)
    local containers, _, equipment = buildContainers(items)
    local equipmentSlots = getEquipmentSlots()
    local definitions = Items.GetClientDefinitions()
    local ground = nil
    if src then
        local coords = getSourceCoords(src)
        if coords then
            ground = packGroundDropsForCoords(coords)
        end
    end
    local state = {
        character_id = characterId,
        characterId = characterId,
        revision = getRevision(characterId),
        containers = containers,
        equipmentSlots = equipmentSlots,
        equipment = equipment,
        items = items,
        definitions = definitions,
        ground = ground
    }
    dbg('getState characterId=%s revision=%s containers=%s equipmentSlots=%s items=%s definitions=%s',
        tostring(characterId), tostring(state.revision), tostring(#containers), tostring(#equipmentSlots), tostring(#items), tostring((function(t) local c=0 for _ in pairs(t or {}) do c=c+1 end return c end)(definitions)))
    return state
end

local function sendState(src, openAfter)
    local _, characterId, err = getCharacter(src)
    if err then
        print(('[cw-inventory] cannot open inventory for source %s: %s'):format(src, tostring(err)))
        TriggerClientEvent('cw-inventory:client:error', src, err)
        return false
    end

    local ok, stateOrErr = pcall(function()
        return getState(characterId, src)
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
        local requestedAmount = tonumber(payload.amount)
        local amountToMove = math.floor(requestedAmount or item.amount or 1)
        if payload.split == true or payload.split == 1 then
            amountToMove = math.max(1, (tonumber(item.amount) or 1) - 1)
        end
        if amountToMove < 1 then return false, 'Некорректное количество.' end
        if amountToMove > (tonumber(item.amount) or 1) then return false, 'Нельзя перенести больше, чем есть в стаке.' end

        local before = copy(item)

        local stackTarget, _, stackErr = findStackAt(characterId, toContainer, x, y, item.id, item.item_name, item.metadata)
        if stackTarget then
            local stackMax = stackMaxForItemName(item.item_name)
            local free = stackMax - (tonumber(stackTarget.amount) or 1)
            if amountToMove > free then
                return false, ('В этом стаке свободно только %s.'):format(free)
            end

            local targetBefore = copy(stackTarget)
            MySQL.update.await('UPDATE cw_inventory_items SET amount = amount + ? WHERE id = ? AND character_id = ?', { amountToMove, stackTarget.id, characterId })
            updateSourceStackAfterTake(characterId, item, amountToMove)
            bumpRevision(characterId)

            logAction(characterId, player.account_id, 'stack_move', {
                item_id = stackTarget.id,
                item_name = item.item_name,
                amount = amountToMove,
                from_container = before.container_id,
                to_container = toContainer,
                from_slot = before.equip_slot,
                before_json = { source = before, target = targetBefore },
                after_json = { source = getItem(characterId, item.id), target = getItem(characterId, stackTarget.id) }
            })
            return true
        elseif stackErr then
            return false, stackErr
        end

        local ignoreForPlace = amountToMove >= (tonumber(item.amount) or 1) and item.id or -1
        local ok, msg = canPlace(characterId, item, toContainer, x, y, rotated, ignoreForPlace)
        if not ok then return false, msg end

        if amountToMove < (tonumber(item.amount) or 1) then
            MySQL.update.await('UPDATE cw_inventory_items SET amount = amount - ? WHERE id = ? AND character_id = ?', { amountToMove, item.id, characterId })
            local insertId = MySQL.insert.await([[INSERT INTO cw_inventory_items
                (character_id, item_name, amount, metadata, container_id, x, y, rotated, equip_slot)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)]],
                { characterId, item.item_name, amountToMove, enc(item.metadata), toContainer, math.floor(x), math.floor(y), rotated and 1 or 0 })

            bumpRevision(characterId)
            logAction(characterId, player.account_id, 'split_move', {
                item_id = insertId,
                item_name = item.item_name,
                amount = amountToMove,
                from_container = before.container_id,
                to_container = toContainer,
                from_slot = before.equip_slot,
                before_json = before,
                after_json = { source = getItem(characterId, item.id), created = getItem(characterId, insertId) }
            })
            return true
        end

        MySQL.update.await([[UPDATE cw_inventory_items
            SET container_id = ?, x = ?, y = ?, rotated = ?, equip_slot = NULL
            WHERE id = ? AND character_id = ?]],
            { toContainer, math.floor(x), math.floor(y), rotated and 1 or 0, item.id, characterId })

        bumpRevision(characterId)
        local after = getItem(characterId, item.id)
        logAction(characterId, player.account_id, 'move', {
            item_id = item.id,
            item_name = item.item_name,
            amount = amountToMove,
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
    if not def then return false, ('Такого предмета нет в cw-items: %s.'):format(itemName) end
    if not characterExists(characterId) then return false, 'Персонаж не найден.' end

    dbg('AddItemToCharacter characterId=%s item=%s amount=%s', tostring(characterId), tostring(itemName), tostring(amount))
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


local function addItemToCharacterAt(characterId, itemName, amount, metadata, target, actorAccountId, actorSource, reason)
    characterId = tonumber(characterId)
    itemName = tostring(itemName or '')
    amount = math.floor(tonumber(amount) or 1)
    metadata = metadata or {}
    target = type(target) == 'table' and target or {}

    if not characterId then return false, 'Некорректный ID персонажа.' end
    if amount < 1 then amount = 1 end

    local def = Items.Get(itemName)
    if not def then return false, ('Такого предмета нет в cw-items: %s.'):format(itemName) end
    if not characterExists(characterId) then return false, 'Персонаж не найден.' end

    dbg('AddItemToCharacterAt characterId=%s item=%s amount=%s rawTarget=%s', tostring(characterId), tostring(itemName), tostring(amount), enc(target))
    ensureState(characterId)

    local targetType = tostring(target.type or '')
    local slot = tostring(target.slot or target.equip_slot or '')
    local containerId = tostring(target.containerId or target.container_id or '')
    local x = tonumber(target.x)
    local y = tonumber(target.y)

    if targetType ~= 'slot' and slot == '' and (containerId == '' or x == nil or y == nil) then
        return addItemToCharacter(characterId, itemName, amount, metadata, actorAccountId, actorSource, reason)
    end

    return withLock(characterId, function()
        local stackMax = math.max(1, tonumber(def.stack) or 1)

        if targetType == 'slot' or slot ~= '' then
            if slot == '' then return false, 'Некорректный слот экипировки.' end
            if amount ~= 1 then return false, 'В слот экипировки можно выдать только 1 предмет.' end

            local tempItem = {
                item_name = itemName,
                type = def.type or 'item',
                amount = 1
            }

            if not canEquipToSlot(tempItem, slot) then
                return false, 'Этот предмет нельзя положить в этот слот.'
            end

            local occupied = MySQL.scalar.await('SELECT id FROM cw_inventory_items WHERE character_id = ? AND equip_slot = ? LIMIT 1', { characterId, slot })
            if occupied then
                return false, 'Слот уже занят.'
            end

            local insertId = MySQL.insert.await([[INSERT INTO cw_inventory_items
                (character_id, item_name, amount, metadata, container_id, x, y, rotated, equip_slot)
                VALUES (?, ?, 1, ?, NULL, NULL, NULL, 0, ?)]],
                { characterId, itemName, enc(metadata), slot })

            bumpRevision(characterId)
            logAction(characterId, actorAccountId, reason == 'ground_pickup' and 'pickup_ground_equip' or 'admin_add_equip', {
                actor_source = actorSource,
                item_id = insertId,
                item_name = itemName,
                amount = 1,
                to_slot = slot,
                from_container = reason == 'ground_pickup' and 'Земля' or (reason or 'admin'),
                before_json = { reason = reason or 'admin_add' },
                after_json = getItem(characterId, insertId)
            })

            return true
        end

        local rotated = target.rotated == true or target.rotated == 1

        if amount > stackMax then
            return false, ('Максимум для одного слота: %s.'):format(stackMax)
        end

        local stackTarget, _, stackErr = findStackAt(characterId, containerId, x, y, -1, itemName, metadata)
        if stackTarget then
            local free = stackMax - (tonumber(stackTarget.amount) or 1)
            if amount > free then
                return false, ('В этом стаке свободно только %s.'):format(free)
            end

            local before = copy(stackTarget)
            MySQL.update.await('UPDATE cw_inventory_items SET amount = amount + ? WHERE id = ? AND character_id = ?', { amount, stackTarget.id, characterId })
            bumpRevision(characterId)
            logAction(characterId, actorAccountId, reason == 'ground_pickup' and 'pickup_ground_stack' or 'admin_add_stack', {
                actor_source = actorSource,
                item_id = stackTarget.id,
                item_name = itemName,
                amount = amount,
                to_container = containerId,
                from_container = reason == 'ground_pickup' and 'Земля' or (reason or 'admin'),
                before_json = before,
                after_json = getItem(characterId, stackTarget.id)
            })

            return true
        elseif stackErr then
            return false, stackErr
        end

        local tempItem = { item_name = itemName }
        dbg('AddItemToCharacterAt container target characterId=%s item=%s container=%s x=%s y=%s rotated=%s', tostring(characterId), tostring(itemName), tostring(containerId), tostring(x), tostring(y), tostring(rotated))
        local ok, msg = canPlace(characterId, tempItem, containerId, x, y, rotated, -1)
        if not ok then
            dbg('AddItemToCharacterAt canPlace failed characterId=%s item=%s reason=%s', tostring(characterId), tostring(itemName), tostring(msg))
            return false, msg
        end

        local insertId = MySQL.insert.await([[INSERT INTO cw_inventory_items
            (character_id, item_name, amount, metadata, container_id, x, y, rotated, equip_slot)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)]],
            { characterId, itemName, amount, enc(metadata), containerId, math.floor(x), math.floor(y), rotated and 1 or 0 })

        bumpRevision(characterId)
        logAction(characterId, actorAccountId, reason == 'ground_pickup' and 'pickup_ground' or 'admin_add', {
            actor_source = actorSource,
            item_id = insertId,
            item_name = itemName,
            amount = amount,
            to_container = containerId,
            before_json = { reason = reason or 'admin_add' },
            after_json = getItem(characterId, insertId)
        })

        return true
    end)
end

local function moveItemForCharacter(characterId, itemId, target, actorAccountId, actorSource, reason)
    characterId = tonumber(characterId)
    itemId = tonumber(itemId)
    target = type(target) == 'table' and target or {}

    if not characterId then return false, 'Некорректный ID персонажа.' end
    if not itemId then return false, 'Некорректный ID предмета.' end
    if not characterExists(characterId) then return false, 'Персонаж не найден.' end

    ensureState(characterId)

    return withLock(characterId, function()
        local item = getItem(characterId, itemId)
        if not item then return false, 'Предмет не найден.' end

        local targetType = tostring(target.type or '')
        local slot = tostring(target.slot or target.equip_slot or '')
        local containerId = tostring(target.containerId or target.container_id or '')
        local x = tonumber(target.x)
        local y = tonumber(target.y)
        local rotated = target.rotated == true or target.rotated == 1 or target.rotated == '1'
        local amountToMove = math.floor(tonumber(target.amount) or tonumber(item.amount) or 1)
        if target.split == true or target.split == 1 then
            amountToMove = math.max(1, (tonumber(item.amount) or 1) - 1)
        end
        if amountToMove < 1 then return false, 'Некорректное количество.' end
        if amountToMove > (tonumber(item.amount) or 1) then return false, 'Нельзя перенести больше, чем есть в стаке.' end
        local before = copy(item)

        if targetType == 'slot' or slot ~= '' then
            if amountToMove ~= (tonumber(item.amount) or 1) then return false, 'Часть стака нельзя положить в слот экипировки.' end
            if slot == '' then return false, 'Некорректный слот экипировки.' end
            if not canEquipToSlot(item, slot) then return false, 'Этот предмет нельзя положить в этот слот.' end

            local occupied = MySQL.scalar.await('SELECT id FROM cw_inventory_items WHERE character_id = ? AND equip_slot = ? LIMIT 1', { characterId, slot })
            if occupied and tonumber(occupied) ~= item.id then
                return false, 'Слот уже занят.'
            end

            MySQL.update.await([[UPDATE cw_inventory_items
                SET container_id = NULL, x = NULL, y = NULL, rotated = 0, equip_slot = ?
                WHERE id = ? AND character_id = ?]], { slot, item.id, characterId })

            bumpRevision(characterId)
            local after = getItem(characterId, item.id)
            logAction(characterId, actorAccountId, 'admin_move_equip', {
                actor_source = actorSource,
                item_id = item.id,
                item_name = item.item_name,
                amount = item.amount,
                from_container = before.container_id,
                from_slot = before.equip_slot,
                to_slot = slot,
                from_container = reason == 'ground_pickup' and 'Земля' or (reason or 'admin'),
                before_json = before,
                after_json = after
            })
            return true
        end

        if containerId == '' or x == nil or y == nil then
            return false, 'Некорректная позиция.'
        end

        local stackTarget, _, stackErr = findStackAt(characterId, containerId, x, y, item.id, item.item_name, item.metadata)
        if stackTarget then
            local stackMax = stackMaxForItemName(item.item_name)
            local free = stackMax - (tonumber(stackTarget.amount) or 1)
            if amountToMove > free then
                return false, ('В этом стаке свободно только %s.'):format(free)
            end

            local targetBefore = copy(stackTarget)
            MySQL.update.await('UPDATE cw_inventory_items SET amount = amount + ? WHERE id = ? AND character_id = ?', { amountToMove, stackTarget.id, characterId })
            updateSourceStackAfterTake(characterId, item, amountToMove)
            bumpRevision(characterId)

            logAction(characterId, actorAccountId, 'admin_stack_move', {
                actor_source = actorSource,
                item_id = stackTarget.id,
                item_name = item.item_name,
                amount = amountToMove,
                from_container = before.container_id,
                to_container = containerId,
                from_slot = before.equip_slot,
                before_json = { source = before, target = targetBefore },
                after_json = { source = getItem(characterId, item.id), target = getItem(characterId, stackTarget.id) }
            })
            return true
        elseif stackErr then
            return false, stackErr
        end

        local ignoreForPlace = amountToMove >= (tonumber(item.amount) or 1) and item.id or -1
        local ok, msg = canPlace(characterId, item, containerId, x, y, rotated, ignoreForPlace)
        if not ok then return false, msg end

        if amountToMove < (tonumber(item.amount) or 1) then
            MySQL.update.await('UPDATE cw_inventory_items SET amount = amount - ? WHERE id = ? AND character_id = ?', { amountToMove, item.id, characterId })
            local insertId = MySQL.insert.await([[INSERT INTO cw_inventory_items
                (character_id, item_name, amount, metadata, container_id, x, y, rotated, equip_slot)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)]],
                { characterId, item.item_name, amountToMove, enc(item.metadata), containerId, math.floor(x), math.floor(y), rotated and 1 or 0 })

            bumpRevision(characterId)
            logAction(characterId, actorAccountId, 'admin_split_move', {
                actor_source = actorSource,
                item_id = insertId,
                item_name = item.item_name,
                amount = amountToMove,
                from_container = before.container_id,
                to_container = containerId,
                from_slot = before.equip_slot,
                before_json = before,
                after_json = { source = getItem(characterId, item.id), created = getItem(characterId, insertId) }
            })
            return true
        end

        MySQL.update.await([[UPDATE cw_inventory_items
            SET container_id = ?, x = ?, y = ?, rotated = ?, equip_slot = NULL
            WHERE id = ? AND character_id = ?]],
            { containerId, math.floor(x), math.floor(y), rotated and 1 or 0, item.id, characterId })

        bumpRevision(characterId)
        local after = getItem(characterId, item.id)
        logAction(characterId, actorAccountId, item.equip_slot and 'admin_unequip_move' or 'admin_move', {
            actor_source = actorSource,
            item_id = item.id,
            item_name = item.item_name,
            amount = amountToMove,
            from_container = before.container_id,
            to_container = containerId,
            from_slot = before.equip_slot,
            before_json = before,
            after_json = after
        })
        return true
    end)
end

local function deleteItemFromCharacter(characterId, itemId, actorAccountId, actorSource, reason, action)
    characterId = tonumber(characterId)
    itemId = tonumber(itemId)

    if not characterId then return false, 'Некорректный ID персонажа.' end
    if not itemId then return false, 'Некорректный ID предмета.' end
    if not characterExists(characterId) then return false, 'Персонаж не найден.' end

    ensureState(characterId)

    return withLock(characterId, function()
        local item = getItem(characterId, itemId)
        if not item then return false, 'Предмет не найден.' end

        local before = copy(item)
        local deletedContents = {}
        local def = Items.Get(item.item_name) or {}
        local sourceContainerId = nil

        if item.equip_slot and def.container and def.container.id then
            sourceContainerId = tostring(def.container.id)
        end

        if sourceContainerId and sourceContainerId ~= '' then
            local rows = MySQL.query.await('SELECT * FROM cw_inventory_items WHERE character_id = ? AND container_id = ? ORDER BY id ASC', { characterId, sourceContainerId }) or {}
            for _, row in ipairs(rows) do
                local nested = normalizeItem(row)
                if nested then
                    deletedContents[#deletedContents + 1] = nested
                end
            end
        end

        if #deletedContents > 0 then
            for _, nested in ipairs(deletedContents) do
                MySQL.update.await('DELETE FROM cw_inventory_items WHERE id = ? AND character_id = ?', { nested.id, characterId })
            end
        end

        MySQL.update.await('DELETE FROM cw_inventory_items WHERE id = ? AND character_id = ?', { item.id, characterId })
        bumpRevision(characterId)

        logAction(characterId, actorAccountId, action or 'admin_delete', {
            actor_source = actorSource,
            item_id = item.id,
            item_name = item.item_name,
            amount = item.amount,
            from_container = before.container_id,
            from_slot = before.equip_slot,
            before_json = {
                item = before,
                container_id = sourceContainerId,
                contents = deletedContents
            },
            after_json = {
                deleted = true,
                reason = reason or 'delete',
                contents_deleted = #deletedContents
            }
        })

        item.deleted_contents = deletedContents
        return true, item
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

-- Обычная игровая команда без префикса cw. Админские команды остаются в cw-admin.
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

RegisterNetEvent('cw-inventory:server:dropItem', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local player, characterId, err = getCharacter(src)
    if err then
        TriggerClientEvent('cw-inventory:client:error', src, err)
        return
    end

    local itemId = tonumber(payload.itemId)
    local coords = type(payload.coords) == 'table' and payload.coords or getSourceCoords(src) or {}
    local reason = 'player drop to ground'
    local ok, resultOrMsg = deleteItemFromCharacter(characterId, itemId, player and player.account_id or nil, src, reason, 'drop_ground')

    if not ok then
        TriggerClientEvent('cw-inventory:client:error', src, resultOrMsg or 'Не удалось выбросить предмет.')
        sendState(src)
        return
    end

    local drop = addGroundDropFromItem(resultOrMsg, coords, src, characterId)
    TriggerClientEvent('cw-inventory:client:success', src, 'Предмет выброшен на землю.')
    TriggerClientEvent('cw-inventory:client:spawnDropBag', src, {
        item = resultOrMsg,
        drop_id = drop and drop.id,
        coords = coords,
        model = Config.DropBagModel or 'p_bag01x'
    })
    sendState(src)
end)


RegisterNetEvent('cw-inventory:server:pickupDropItem', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    local player, characterId, err = getCharacter(src)
    if err then
        TriggerClientEvent('cw-inventory:client:error', src, err)
        return
    end

    local dropId = tonumber(payload.dropId or payload.drop_id or payload.id)
    if not dropId or not GroundDrops[dropId] then
        TriggerClientEvent('cw-inventory:client:error', src, 'Предмета на земле уже нет.')
        sendState(src)
        return
    end

    local coords = getSourceCoords(src)
    local drop = GroundDrops[dropId]
    if coords and vectorDistance(coords, drop.coords) > (Config.GroundLootRadius or 1.5) + 0.35 then
        TriggerClientEvent('cw-inventory:client:error', src, 'Предмет слишком далеко.')
        sendState(src)
        return
    end

    local target = type(payload.target) == 'table' and payload.target or {}
    local item = drop.item or {}
    local available = math.max(1, math.floor(tonumber(item.amount) or 1))
    local amount = math.max(1, math.floor(tonumber(payload.amount) or available))
    if amount > available then amount = available end

    local itemCopy = copy(item)
    itemCopy.amount = amount

    local ok, resultOrMsg = addItemToCharacterAt(
        characterId,
        itemCopy.item_name,
        amount,
        itemCopy.metadata or {},
        target,
        player and player.account_id or nil,
        src,
        'ground_pickup'
    )

    if not ok then
        TriggerClientEvent('cw-inventory:client:error', src, resultOrMsg or 'Не удалось поднять предмет.')
        sendState(src)
        return
    end

    if amount >= available then
        GroundDrops[dropId] = nil
    else
        drop.item.amount = available - amount
    end

    TriggerClientEvent('cw-inventory:client:success', src, 'Предмет поднят.')
    sendState(src)
end)

exports('GetInventoryState', function(characterId)
    characterId = tonumber(characterId)
    if not characterId then
        dbg('GetInventoryState invalid characterId=%s', tostring(characterId))
        return nil
    end
    dbg('GetInventoryState export characterId=%s', tostring(characterId))
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

exports('AddItemToCharacterAt', function(characterId, itemName, amount, metadata, target, actorSource, actorAccountId, reason)
    -- Только server-side API для доверенных ресурсов. Права здесь не проверяются специально.
    return addItemToCharacterAt(tonumber(characterId), itemName, amount, metadata or {}, target or {}, actorAccountId, actorSource, reason or 'resource_export')
end)


exports('MoveItemForCharacter', function(characterId, itemId, target, actorSource, actorAccountId, reason)
    -- Только server-side API для доверенных ресурсов. Права здесь не проверяются специально.
    return moveItemForCharacter(tonumber(characterId), tonumber(itemId), target or {}, actorAccountId, actorSource, reason or 'resource_export')
end)

exports('DeleteItemFromCharacter', function(characterId, itemId, actorSource, actorAccountId, reason)
    -- Только server-side API для доверенных ресурсов. Права здесь не проверяются специально.
    return deleteItemFromCharacter(tonumber(characterId), tonumber(itemId), actorAccountId, actorSource, reason or 'resource_export', 'admin_delete')
end)

exports('GetItemDefinitions', function()
    return Items.GetClientDefinitions()
end)


AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    print(('[cw-inventory] started %s'):format(InventoryServerVersion))
    CreateThread(function()
        Wait(500)
        ensureSchema()
    end)
end)
