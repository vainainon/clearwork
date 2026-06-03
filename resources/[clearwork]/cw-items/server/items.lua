CWItems = CWItems or {}

-- cw-items — это справочник предметов.
-- Здесь НЕ хранится, у какого персонажа сколько предметов.
-- Реальные экземпляры предметов лежат в БД cw_inventory_items у ресурса cw-inventory.

CWItems.Definitions = {
    bread = {
        label = 'Хлеб',
        description = 'Простой паёк.',
        category = 'food',
        type = 'food',
        width = 1,
        height = 1,
        stack = 5,
        weight = 0.2
    },

    water = {
        label = 'Фляга воды',
        description = 'Можно пить или носить с собой.',
        category = 'drink',
        type = 'drink',
        width = 1,
        height = 2,
        stack = 1,
        weight = 0.8
    },

    bandage = {
        label = 'Бинт',
        description = 'Перевязочный материал.',
        category = 'medical',
        type = 'medical',
        width = 1,
        height = 1,
        stack = 3,
        weight = 0.1
    },

    ammo_revolver = {
        label = 'Патроны револьверные',
        description = 'Боеприпасы для револьвера.',
        category = 'ammo',
        type = 'ammo',
        ammoType = 'AMMO_REVOLVER',
        width = 1,
        height = 1,
        stack = 30,
        weight = 0.02
    },

    revolver_cattleman = {
        label = 'Cattleman Revolver',
        description = 'Револьвер. В кобуре будет связан с оружейным слотом.',
        category = 'weapon',
        type = 'weapon_revolver',
        weaponClass = 'revolver',
        weaponHash = 'WEAPON_REVOLVER_CATTLEMAN',
        width = 2,
        height = 2,
        stack = 1,
        weight = 1.2
    },

    rifle_varmint = {
        label = 'Varmint Rifle',
        description = 'Двуручное оружие. Слот на спине.',
        category = 'weapon',
        type = 'weapon_longarm',
        weaponClass = 'longarm',
        weaponHash = 'WEAPON_RIFLE_VARMINT',
        width = 5,
        height = 2,
        stack = 1,
        weight = 3.4
    },

    basic_hat = {
        label = 'Шляпа',
        description = 'Головной убор.',
        category = 'clothing',
        type = 'clothing_hat',
        width = 2,
        height = 1,
        stack = 1,
        weight = 0.4
    },

    basic_coat = {
        label = 'Пальто',
        description = 'Верхняя одежда с небольшими карманами.',
        category = 'clothing',
        type = 'clothing_coat',
        width = 2,
        height = 3,
        stack = 1,
        weight = 1.5,
        container = {
            id = 'coat',
            label = 'Карманы пальто',
            width = 4,
            height = 3,
            order = 30
        }
    },

    basic_vest = {
        label = 'Разгрузка',
        description = 'Жилет с ячейками под предметы.',
        category = 'clothing',
        type = 'clothing_vest',
        width = 2,
        height = 2,
        stack = 1,
        weight = 1.0,
        container = {
            id = 'vest',
            label = 'Разгрузка',
            width = 5,
            height = 3,
            order = 40
        }
    },

    basic_pants = {
        label = 'Штаны',
        description = 'Обычные штаны.',
        category = 'clothing',
        type = 'clothing_pants',
        width = 2,
        height = 2,
        stack = 1,
        weight = 0.8,
        container = {
            id = 'pants',
            label = 'Карманы штанов',
            width = 3,
            height = 2,
            order = 35
        }
    },

    silver_ring = {
        label = 'Серебряное кольцо',
        description = 'Украшение.',
        category = 'accessory',
        type = 'accessory',
        width = 1,
        height = 1,
        stack = 1,
        weight = 0.05
    },

    -- ClearWork Clothes Shop items.
    -- Визуальная часть конкретной вещи хранится в metadata экземпляра предмета,
    -- который выдаёт cw-clothes. Здесь только размеры, типы и базовые свойства для inventory.

    cw_hat_worn_flat_cap = {
        label = 'Потёртая плоская кепка',
        description = 'Головной убор из лавки одежды.',
        category = 'clothing',
        type = 'clothing_hat',
        width = 2,
        height = 1,
        stack = 1,
        weight = 0.35
    },

    cw_hat_stalker = {
        label = 'Шляпа следопыта',
        description = 'Головной убор из лавки одежды.',
        category = 'clothing',
        type = 'clothing_hat',
        width = 2,
        height = 1,
        stack = 1,
        weight = 0.45
    },

    cw_shirt_union = {
        label = 'Союзная рубаха',
        description = 'Рубаха из лавки одежды.',
        category = 'clothing',
        type = 'clothing_shirt',
        width = 2,
        height = 2,
        stack = 1,
        weight = 0.55
    },

    cw_shirt_work = {
        label = 'Рабочая рубаха',
        description = 'Рубаха из лавки одежды.',
        category = 'clothing',
        type = 'clothing_shirt',
        width = 2,
        height = 2,
        stack = 1,
        weight = 0.65
    },

    cw_coat_duster = {
        label = 'Дорожный дастер',
        description = 'Верхняя одежда из лавки одежды. Даёт дополнительные карманы.',
        category = 'clothing',
        type = 'clothing_coat',
        width = 2,
        height = 3,
        stack = 1,
        weight = 1.8,
        container = {
            id = 'coat',
            label = 'Карманы пальто',
            width = 4,
            height = 3,
            order = 30
        }
    },

    cw_coat_worker = {
        label = 'Рабочая куртка',
        description = 'Верхняя одежда из лавки одежды. Даёт дополнительные карманы.',
        category = 'clothing',
        type = 'clothing_coat',
        width = 2,
        height = 2,
        stack = 1,
        weight = 1.3,
        container = {
            id = 'coat',
            label = 'Карманы куртки',
            width = 3,
            height = 2,
            order = 30
        }
    },

    cw_vest_worker = {
        label = 'Рабочий жилет',
        description = 'Жилет из лавки одежды. Даёт дополнительные карманы.',
        category = 'clothing',
        type = 'clothing_vest',
        width = 2,
        height = 2,
        stack = 1,
        weight = 0.9,
        container = {
            id = 'vest',
            label = 'Карманы жилета',
            width = 4,
            height = 2,
            order = 40
        }
    },

    cw_pants_work = {
        label = 'Рабочие штаны',
        description = 'Штаны из лавки одежды. Даёт карманы штанов.',
        category = 'clothing',
        type = 'clothing_pants',
        width = 2,
        height = 2,
        stack = 1,
        weight = 0.8,
        container = {
            id = 'pants',
            label = 'Карманы штанов',
            width = 3,
            height = 2,
            order = 35
        }
    },

    cw_boots_workman = {
        label = 'Рабочие ботинки',
        description = 'Обувь из лавки одежды.',
        category = 'clothing',
        type = 'clothing_boots',
        width = 2,
        height = 2,
        stack = 1,
        weight = 0.9
    }
}

function CWItems.Get(name)
    return CWItems.Definitions[tostring(name or '')]
end

function CWItems.Exists(name)
    return CWItems.Get(name) ~= nil
end

function CWItems.GetSize(name, rotated)
    local def = CWItems.Get(name)
    if not def then return 1, 1 end

    local w = tonumber(def.width) or 1
    local h = tonumber(def.height) or 1

    if rotated then return h, w end
    return w, h
end

function CWItems.GetAll()
    return CWItems.Definitions
end

function CWItems.GetClientDefinitions()
    local out = {}

    for name, def in pairs(CWItems.Definitions) do
        out[name] = {
            label = def.label or name,
            description = def.description or '',
            category = def.category or 'misc',
            type = def.type or 'item',
            width = tonumber(def.width) or 1,
            height = tonumber(def.height) or 1,
            stack = tonumber(def.stack) or 1,
            weight = tonumber(def.weight) or 0,
            weaponClass = def.weaponClass,
            weaponHash = def.weaponHash,
            ammoType = def.ammoType,
            container = def.container
        }
    end

    return out
end
