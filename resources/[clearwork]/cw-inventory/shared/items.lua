CWInventoryItems = CWInventoryItems or {}

-- width/height считаются в клетках. type нужен для ограничений слотов.
-- container у одежды открывает отдельную вместимость справа.
CWInventoryItems.Definitions = {
    bread = {
        label = 'Хлеб',
        description = 'Простой паёк.',
        type = 'food',
        width = 1,
        height = 1,
        stack = 5,
        weight = 0.2
    },
    water = {
        label = 'Фляга воды',
        description = 'Можно пить или носить с собой.',
        type = 'drink',
        width = 1,
        height = 2,
        stack = 1,
        weight = 0.8
    },
    bandage = {
        label = 'Бинт',
        description = 'Перевязочный материал.',
        type = 'medical',
        width = 1,
        height = 1,
        stack = 3,
        weight = 0.1
    },
    ammo_revolver = {
        label = 'Патроны револьверные',
        description = 'Боеприпасы для револьвера.',
        type = 'ammo',
        width = 1,
        height = 1,
        stack = 30,
        weight = 0.02
    },
    revolver_cattleman = {
        label = 'Cattleman Revolver',
        description = 'Револьвер. В кобуре появляется как оружейный слот.',
        type = 'weapon_revolver',
        weaponHash = 'WEAPON_REVOLVER_CATTLEMAN',
        width = 2,
        height = 2,
        stack = 1,
        weight = 1.2
    },
    rifle_varmint = {
        label = 'Varmint Rifle',
        description = 'Двуручное оружие. Слот на спине.',
        type = 'weapon_longarm',
        weaponHash = 'WEAPON_RIFLE_VARMINT',
        width = 5,
        height = 2,
        stack = 1,
        weight = 3.4
    },
    basic_hat = {
        label = 'Шляпа',
        description = 'Головной убор.',
        type = 'clothing_hat',
        width = 2,
        height = 1,
        stack = 1,
        weight = 0.4
    },
    basic_coat = {
        label = 'Пальто',
        description = 'Верхняя одежда с небольшими карманами.',
        type = 'clothing_coat',
        width = 2,
        height = 3,
        stack = 1,
        weight = 1.5,
        container = { id = 'coat', label = 'Карманы пальто', width = 4, height = 3, order = 30 }
    },
    basic_vest = {
        label = 'Разгрузка',
        description = 'Жилет с ячейками под предметы.',
        type = 'clothing_vest',
        width = 2,
        height = 2,
        stack = 1,
        weight = 1.0,
        container = { id = 'vest', label = 'Разгрузка', width = 5, height = 3, order = 40 }
    },
    basic_pants = {
        label = 'Штаны',
        description = 'Обычные штаны.',
        type = 'clothing_pants',
        width = 2,
        height = 2,
        stack = 1,
        weight = 0.8,
        container = { id = 'pants', label = 'Карманы штанов', width = 3, height = 2, order = 35 }
    },
    silver_ring = {
        label = 'Серебряное кольцо',
        description = 'Украшение.',
        type = 'accessory',
        width = 1,
        height = 1,
        stack = 1,
        weight = 0.05
    }
}

function CWInventoryItems.Get(name)
    return CWInventoryItems.Definitions[tostring(name or '')]
end

function CWInventoryItems.GetSize(name, rotated)
    local def = CWInventoryItems.Get(name)
    if not def then return 1, 1 end
    local w = tonumber(def.width) or 1
    local h = tonumber(def.height) or 1
    if rotated then return h, w end
    return w, h
end

function CWInventoryItems.GetClientDefinitions()
    local out = {}
    for name, def in pairs(CWInventoryItems.Definitions) do
        out[name] = {
            label = def.label or name,
            description = def.description or '',
            type = def.type or 'item',
            width = tonumber(def.width) or 1,
            height = tonumber(def.height) or 1,
            stack = tonumber(def.stack) or 1,
            weight = tonumber(def.weight) or 0,
            weaponHash = def.weaponHash,
            container = def.container
        }
    end
    return out
end
