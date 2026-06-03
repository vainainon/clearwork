local PlayerBaskets = {}

local CategoryOrder = {
    { id = 'hat', label = 'Головные уборы', slot = 'hat' },
    { id = 'shirt', label = 'Рубахи', slot = 'shirt' },
    { id = 'coat', label = 'Верхняя одежда', slot = 'coat' },
    { id = 'vest', label = 'Жилеты', slot = 'vest' },
    { id = 'pants', label = 'Штаны', slot = 'pants' },
    { id = 'boots', label = 'Обувь', slot = 'boots' }
}

-- Каталог v0.2:
-- 1) itemName обязан существовать в cw-items.
-- 2) component.shopItem может быть строкой или таблицей { male = '...', female = '...' }.
-- 3) Если какой-то shop item hash окажется неверным для твоего билда/пола, механика покупки не сломается:
--    вещь всё равно попадёт в инвентарь, а визуал можно будет поправить заменой hash в этом каталоге.
local Catalog = {
    hat = {
        {
            id = 'hat_worn_flat_cap',
            label = 'Потёртая плоская кепка',
            itemName = 'cw_hat_worn_flat_cap',
            slot = 'hat',
            description = 'Дешёвая рабочая кепка для улиц Сен-Дени.',
            variations = {
                {
                    id = 'dark',
                    label = 'Тёмная',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_HAT_000_TINT_001',
                            female = 'CLOTHING_ITEM_F_HAT_000_TINT_001'
                        }
                    }
                },
                {
                    id = 'dusty',
                    label = 'Пыльная',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_HAT_000_TINT_002',
                            female = 'CLOTHING_ITEM_F_HAT_000_TINT_002'
                        }
                    }
                }
            }
        },
        {
            id = 'hat_stalker',
            label = 'Шляпа следопыта',
            itemName = 'cw_hat_stalker',
            slot = 'hat',
            description = 'Широкополая шляпа для дорог и охоты.',
            variations = {
                {
                    id = 'brown',
                    label = 'Коричневая',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_HAT_001_TINT_001',
                            female = 'CLOTHING_ITEM_F_HAT_001_TINT_001'
                        }
                    }
                },
                {
                    id = 'black',
                    label = 'Чёрная',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_HAT_001_TINT_002',
                            female = 'CLOTHING_ITEM_F_HAT_001_TINT_002'
                        }
                    }
                }
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
                {
                    id = 'white',
                    label = 'Светлая',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_SHIRTS_FULL_001_TINT_001',
                            female = 'CLOTHING_ITEM_F_SHIRTS_FULL_001_TINT_001'
                        }
                    }
                },
                {
                    id = 'grey',
                    label = 'Серая',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_SHIRTS_FULL_001_TINT_002',
                            female = 'CLOTHING_ITEM_F_SHIRTS_FULL_001_TINT_002'
                        }
                    }
                }
            }
        },
        {
            id = 'shirt_work',
            label = 'Рабочая рубаха',
            itemName = 'cw_shirt_work',
            slot = 'shirt',
            description = 'Плотная рубаха для работы и дороги.',
            variations = {
                {
                    id = 'blue',
                    label = 'Синяя',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_SHIRTS_FULL_002_TINT_001',
                            female = 'CLOTHING_ITEM_F_SHIRTS_FULL_002_TINT_001'
                        }
                    }
                },
                {
                    id = 'red',
                    label = 'Красная',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_SHIRTS_FULL_002_TINT_002',
                            female = 'CLOTHING_ITEM_F_SHIRTS_FULL_002_TINT_002'
                        }
                    }
                }
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
                {
                    id = 'tan',
                    label = 'Песочное',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_COAT_001_TINT_001',
                            female = 'CLOTHING_ITEM_F_COAT_001_TINT_001'
                        }
                    }
                },
                {
                    id = 'dark',
                    label = 'Тёмное',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_COAT_001_TINT_002',
                            female = 'CLOTHING_ITEM_F_COAT_001_TINT_002'
                        }
                    }
                }
            }
        },
        {
            id = 'coat_worker',
            label = 'Рабочая куртка',
            itemName = 'cw_coat_worker',
            slot = 'coat',
            description = 'Короткая куртка для города и порта.',
            variations = {
                {
                    id = 'brown',
                    label = 'Коричневая',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_COAT_000_TINT_001',
                            female = 'CLOTHING_ITEM_F_COAT_000_TINT_001'
                        }
                    }
                },
                {
                    id = 'black',
                    label = 'Чёрная',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_COAT_000_TINT_002',
                            female = 'CLOTHING_ITEM_F_COAT_000_TINT_002'
                        }
                    }
                }
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
                {
                    id = 'cloth',
                    label = 'Тканевый',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_VEST_000_TINT_001',
                            female = 'CLOTHING_ITEM_F_VEST_000_TINT_001'
                        }
                    }
                },
                {
                    id = 'leather',
                    label = 'Кожаный',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_VEST_000_TINT_002',
                            female = 'CLOTHING_ITEM_F_VEST_000_TINT_002'
                        }
                    }
                }
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
                {
                    id = 'brown',
                    label = 'Коричневые',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_PANTS_000_TINT_001',
                            female = 'CLOTHING_ITEM_F_PANTS_000_TINT_001'
                        }
                    }
                },
                {
                    id = 'dark',
                    label = 'Тёмные',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_PANTS_000_TINT_002',
                            female = 'CLOTHING_ITEM_F_PANTS_000_TINT_002'
                        }
                    }
                }
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
                {
                    id = 'worn',
                    label = 'Потёртые',
                    tint = 0,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_BOOTS_000_TINT_001',
                            female = 'CLOTHING_ITEM_F_BOOTS_000_TINT_001'
                        }
                    }
                },
                {
                    id = 'clean',
                    label = 'Чищеные',
                    tint = 1,
                    component = {
                        shopItem = {
                            male = 'CLOTHING_ITEM_M_BOOTS_000_TINT_002',
                            female = 'CLOTHING_ITEM_F_BOOTS_000_TINT_002'
                        }
                    }
                }
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

local function enc(value)
    return json.encode(value or {})
end

local function dec(value)
    if not value or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then return decoded end
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

local function sendEquipped(src)
    local _, characterId, err = getCharacter(src)
    if err then return end

    local rows = MySQL.query.await([[
        SELECT id, item_name, metadata, equip_slot
        FROM cw_inventory_items
        WHERE character_id = ?
          AND equip_slot IS NOT NULL
        ORDER BY id ASC
    ]], { characterId }) or {}

    local equipment = {}

    for _, row in ipairs(rows) do
        local metadata = dec(row.metadata)
        local slot = tostring(row.equip_slot or '')

        if slot ~= '' then
            equipment[slot] = {
                id = tonumber(row.id),
                item_name = row.item_name,
                metadata = metadata,
                equip_slot = slot
            }
        end
    end

    TriggerClientEvent('cw-clothes:client:equipped', src, equipment)
end

local function buildMetadata(selected)
    return {
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
end

local function addEntryToInventory(src, player, characterId, selected)
    local metadata = buildMetadata(selected)

    local ok, msg = exports['cw-inventory']:AddItemToCharacter(
        characterId,
        selected.itemName,
        1,
        metadata,
        src,
        player.account_id,
        'clothes_vendor_take'
    )

    return ok, msg
end

local function takeEntry(src, orderId)
    local player, characterId, err = getCharacter(src)
    if err then
        notify(src, err)
        return false
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
        return false
    end

    local ok, msg = addEntryToInventory(src, player, characterId, selected)

    if not ok then
        notify(src, msg or 'Не удалось положить одежду в инвентарь.')
        return false
    end

    table.remove(basket, selectedIndex)
    sendBasket(src)
    sendEquipped(src)

    notify(src, ('%s (%s) положено в твой инвентарь.'):format(selected.label, selected.variationLabel))
    TriggerClientEvent('cw-clothes:client:taken', src)

    return true
end

RegisterCommand('clothes', function(src)
    if src <= 0 then return end

    local _, _, err = getCharacter(src)
    if err then
        notify(src, err)
        return
    end

    sendCatalog(src)
    sendEquipped(src)
    TriggerClientEvent('cw-clothes:client:open', src)
end, false)

RegisterNetEvent('cw-clothes:server:requestCatalog', function()
    local src = source
    sendCatalog(src)
    sendEquipped(src)
end)

RegisterNetEvent('cw-clothes:server:requestEquipped', function()
    sendEquipped(source)
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

    local orderId = ('%s_%s_%s_%s'):format(item.id, variation.id or 'default', os.time(), math.random(1000, 9999))
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
    notify(src, 'Одежда отложена у продавца справа. Можешь забрать её в инвентарь прямо из магазина.')
end)

RegisterNetEvent('cw-clothes:server:takeFromVendor', function(orderId)
    takeEntry(source, orderId)
end)

RegisterNetEvent('cw-clothes:server:takeAllFromVendor', function()
    local src = source
    local basket = getBasket(src)

    if #basket < 1 then
        notify(src, 'У продавца ничего нет.')
        sendBasket(src)
        return
    end

    local copied = copy(basket)
    local taken = 0

    for _, entry in ipairs(copied) do
        if takeEntry(src, entry.orderId) then
            taken = taken + 1
        end
    end

    if taken > 0 then
        notify(src, ('Забрано в инвентарь: %s шт.'):format(taken))
    end

    sendBasket(src)
end)

RegisterNetEvent('cw-clothes:server:buySelectedNow', function(payload)
    local src = source
    local player, characterId, err = getCharacter(src)

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

    local selected = {
        orderId = 'direct',
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

    local ok, msg = addEntryToInventory(src, player, characterId, selected)

    if not ok then
        notify(src, msg or 'Не удалось положить одежду в инвентарь.')
        return
    end

    sendEquipped(src)
    notify(src, ('%s (%s) куплено и положено в твой инвентарь.'):format(selected.label, selected.variationLabel))
    TriggerClientEvent('cw-clothes:client:taken', src)
end)

RegisterNetEvent('cw-clothes:server:clearVendor', function()
    PlayerBaskets[source] = {}
    sendBasket(source)
end)

AddEventHandler('playerDropped', function()
    PlayerBaskets[source] = nil
end)
