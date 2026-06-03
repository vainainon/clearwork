local PlayerBaskets = {}

local CategoryOrder = {
    { id = 'hat', label = 'Головные уборы', slot = 'hat' },
    { id = 'shirt', label = 'Рубахи', slot = 'shirt' },
    { id = 'coat', label = 'Верхняя одежда', slot = 'coat' },
    { id = 'vest', label = 'Жилеты', slot = 'vest' },
    { id = 'pants', label = 'Штаны', slot = 'pants' },
    { id = 'boots', label = 'Обувь', slot = 'boots' }
}

-- ВАЖНО:
-- component.shopItem можно заполнять реальными shop item hash names из RDR2/RSG catalog.
-- Код клиента уже умеет применять их через _APPLY_SHOP_ITEM_TO_PED.
-- Пока оставлены понятные позиции ассортимента и вариации, чтобы механика магазина/инвентаря работала.
local Catalog = {
    hat = {
        {
            id = 'hat_worn_flat_cap',
            label = 'Потёртая плоская кепка',
            itemName = 'cw_hat_worn_flat_cap',
            slot = 'hat',
            description = 'Дешёвая рабочая кепка для улиц Сен-Дени.',
            variations = {
                { id = 'dark', label = 'Тёмная', tint = 0, component = { shopItem = nil } },
                { id = 'dusty', label = 'Пыльная', tint = 1, component = { shopItem = nil } }
            }
        },
        {
            id = 'hat_stalker',
            label = 'Шляпа следопыта',
            itemName = 'cw_hat_stalker',
            slot = 'hat',
            description = 'Широкополая шляпа для дорог и охоты.',
            variations = {
                { id = 'brown', label = 'Коричневая', tint = 0, component = { shopItem = nil } },
                { id = 'black', label = 'Чёрная', tint = 1, component = { shopItem = nil } }
            }
        }
    },

    shirt = {
        {
            id = 'shirt_union',
            label = 'Союзная рубаха',
            itemName = 'cw_shirt_union',
            slot = 'shirt',
            description = 'Простая нижняя рубаха без лишнего шика.',
            variations = {
                { id = 'white', label = 'Светлая', tint = 0, component = { shopItem = nil } },
                { id = 'grey', label = 'Серая', tint = 1, component = { shopItem = nil } }
            }
        },
        {
            id = 'shirt_work',
            label = 'Рабочая рубаха',
            itemName = 'cw_shirt_work',
            slot = 'shirt',
            description = 'Плотная рубаха для работы и дороги.',
            variations = {
                { id = 'blue', label = 'Синяя', tint = 0, component = { shopItem = nil } },
                { id = 'red', label = 'Красная', tint = 1, component = { shopItem = nil } }
            }
        }
    },

    coat = {
        {
            id = 'coat_duster',
            label = 'Дорожный дастер',
            itemName = 'cw_coat_duster',
            slot = 'coat',
            description = 'Длинное пальто от дождя и грязи.',
            variations = {
                { id = 'tan', label = 'Песочное', tint = 0, component = { shopItem = nil } },
                { id = 'dark', label = 'Тёмное', tint = 1, component = { shopItem = nil } }
            }
        },
        {
            id = 'coat_worker',
            label = 'Рабочая куртка',
            itemName = 'cw_coat_worker',
            slot = 'coat',
            description = 'Короткая куртка для города и порта.',
            variations = {
                { id = 'brown', label = 'Коричневая', tint = 0, component = { shopItem = nil } },
                { id = 'black', label = 'Чёрная', tint = 1, component = { shopItem = nil } }
            }
        }
    },

    vest = {
        {
            id = 'vest_worker',
            label = 'Рабочий жилет',
            itemName = 'cw_vest_worker',
            slot = 'vest',
            description = 'Жилет с карманами под мелочь.',
            variations = {
                { id = 'cloth', label = 'Тканевый', tint = 0, component = { shopItem = nil } },
                { id = 'leather', label = 'Кожаный', tint = 1, component = { shopItem = nil } }
            }
        }
    },

    pants = {
        {
            id = 'pants_work',
            label = 'Рабочие штаны',
            itemName = 'cw_pants_work',
            slot = 'pants',
            description = 'Обычные штаны для повседневной жизни.',
            variations = {
                { id = 'brown', label = 'Коричневые', tint = 0, component = { shopItem = nil } },
                { id = 'dark', label = 'Тёмные', tint = 1, component = { shopItem = nil } }
            }
        }
    },

    boots = {
        {
            id = 'boots_workman',
            label = 'Рабочие ботинки',
            itemName = 'cw_boots_workman',
            slot = 'boots',
            description = 'Надёжные ботинки для грязи и мостовой.',
            variations = {
                { id = 'worn', label = 'Потёртые', tint = 0, component = { shopItem = nil } },
                { id = 'clean', label = 'Чищеные', tint = 1, component = { shopItem = nil } }
            }
        }
    }
}

local function notify(src, message)
    TriggerClientEvent('chat:addMessage', src, {
        color = { 210, 185, 120 },
        args = { 'cw-clothes', tostring(message or '') }
    })
end

local function copy(value)
    local ok, encoded = pcall(json.encode, value or {})
    if not ok then return {} end

    local ok2, decoded = pcall(json.decode, encoded)
    if ok2 and type(decoded) == 'table' then return decoded end

    return {}
end

local function getPlayer(src)
    local ok, player = pcall(function()
        return exports['cw-core']:GetPlayer(src)
    end)

    if ok then return player end
    return nil
end

local function getCharacter(src)
    local player = getPlayer(src)

    if not player or type(player.character) ~= 'table' then
        return nil, nil, 'Сначала выбери персонажа.'
    end

    local characterId = tonumber(player.character.id)
    if not characterId then
        return nil, nil, 'Сначала выбери персонажа.'
    end

    return player, characterId, nil
end

local function buildCatalogPayload()
    return {
        categories = copy(CategoryOrder),
        catalog = copy(Catalog)
    }
end

local function findCatalogItem(categoryId, itemId, variationId)
    categoryId = tostring(categoryId or '')
    itemId = tostring(itemId or '')
    variationId = tostring(variationId or '')

    local items = Catalog[categoryId]
    if type(items) ~= 'table' then return nil, nil end

    for _, item in ipairs(items) do
        if item.id == itemId then
            local variations = item.variations or {}
            local selected = variations[1]

            for _, variation in ipairs(variations) do
                if variation.id == variationId then
                    selected = variation
                    break
                end
            end

            return item, selected
        end
    end

    return nil, nil
end

local function getBasket(src)
    src = tonumber(src) or 0
    PlayerBaskets[src] = PlayerBaskets[src] or {}
    return PlayerBaskets[src]
end

local function sendBasket(src)
    TriggerClientEvent('cw-clothes:client:basket', src, copy(getBasket(src)))
end

local function sendCatalog(src)
    TriggerClientEvent('cw-clothes:client:catalog', src, buildCatalogPayload())
    sendBasket(src)
end

RegisterCommand('clothes', function(src)
    if src <= 0 then return end

    local _, _, err = getCharacter(src)
    if err then
        notify(src, err)
        return
    end

    sendCatalog(src)
    TriggerClientEvent('cw-clothes:client:open', src)
end, false)

RegisterNetEvent('cw-clothes:server:requestCatalog', function()
    sendCatalog(source)
end)

RegisterNetEvent('cw-clothes:server:addToVendor', function(payload)
    local src = source
    local _, _, err = getCharacter(src)
    if err then
        notify(src, err)
        return
    end

    payload = payload or {}

    local item, variation = findCatalogItem(payload.categoryId, payload.itemId, payload.variationId)
    if not item or not variation then
        notify(src, 'Такой одежды нет в ассортименте.')
        return
    end

    local orderId = ('%s_%s_%s'):format(item.id, variation.id or 'default', GetGameTimer())
    local basket = getBasket(src)

    basket[#basket + 1] = {
        orderId = orderId,
        categoryId = tostring(payload.categoryId or ''),
        itemId = item.id,
        variationId = variation.id,
        itemName = item.itemName,
        label = item.label,
        variationLabel = variation.label or 'Обычная',
        slot = item.slot,
        description = item.description or '',
        component = copy(variation.component or {}),
        tint = tonumber(variation.tint) or 0
    }

    sendBasket(src)
    notify(src, 'Одежда отложена у продавца справа.')
end)

RegisterNetEvent('cw-clothes:server:takeFromVendor', function(orderId)
    local src = source
    local player, characterId, err = getCharacter(src)
    if err then
        notify(src, err)
        return
    end

    orderId = tostring(orderId or '')
    local basket = getBasket(src)
    local selectedIndex = nil
    local selected = nil

    for index, entry in ipairs(basket) do
        if entry.orderId == orderId then
            selectedIndex = index
            selected = entry
            break
        end
    end

    if not selected then
        notify(src, 'Эта одежда уже забрана или недоступна.')
        sendBasket(src)
        return
    end

    local metadata = {
        label = selected.label,
        source = 'cw-clothes',
        clothing = {
            category = selected.categoryId,
            slot = selected.slot,
            itemId = selected.itemId,
            variationId = selected.variationId,
            label = selected.label,
            variationLabel = selected.variationLabel,
            component = selected.component or {},
            tint = selected.tint or 0
        }
    }

    local ok, msg = exports['cw-inventory']:AddItemToCharacter(
        characterId,
        selected.itemName,
        1,
        metadata,
        src,
        player.account_id,
        'clothes_vendor_take'
    )

    if not ok then
        notify(src, msg or 'Не удалось положить одежду в инвентарь.')
        return
    end

    table.remove(basket, selectedIndex)
    sendBasket(src)

    notify(src, ('%s (%s) положено в твой инвентарь.'):format(selected.label, selected.variationLabel))
    TriggerClientEvent('cw-clothes:client:taken', src)
end)

RegisterNetEvent('cw-clothes:server:clearVendor', function()
    PlayerBaskets[source] = {}
    sendBasket(source)
end)

AddEventHandler('playerDropped', function()
    PlayerBaskets[source] = nil
end)
