CWInventoryConfig = CWInventoryConfig or {}

-- Обычная игровая команда. Админские команды в проекте начинаются с cw,
-- но инвентарь игрока должен быть без cw-префикса.
CWInventoryConfig.OpenCommand = 'inventory'

-- ВРЕМЕННО НА ВРЕМЯ РАЗРАБОТКИ.
-- После фикса drag-and-drop и payload можно вернуть false.
CWInventoryConfig.Debug = true

CWInventoryConfig.BaseContainers = {
    pockets = {
        label = 'Карманы',
        width = 4,
        height = 2,
        order = 10
    },
    belt = {
        label = 'Пояс',
        width = 3,
        height = 1,
        order = 20
    }
}

CWInventoryConfig.EquipmentSlots = {
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

CWInventoryConfig.DefaultStarterItems = CWInventoryConfig.DefaultStarterItems or {}

-- Временный локальный мешок при выбросе предмета из /inventory.
-- Позже это лучше вынести в полноценный cw-worlditems/cw-drops.
CWInventoryConfig.DropBagModel = CWInventoryConfig.DropBagModel or 'p_bag01x'
