CWInventoryConfig = CWInventoryConfig or {}

CWInventoryConfig.OpenCommand = 'cwinv'
CWInventoryConfig.OpenKey = 'I'
-- Проверок ролей здесь нет. Этот ресурс не управляет /cwadmin.
-- Предметы описываются в отдельном ресурсе cw-items.
-- Внешние серверные ресурсы могут использовать exports ниже, но права проверяют у себя.

CWInventoryConfig.Debug = false

-- Включай после теста конкретных RedM natives для твоего билда.
-- Инвентарь уже хранит оружие в слотах, но автоматическая выдача в TAB-радиалку по умолчанию выключена,
-- чтобы не сломать ванильное оружие на первом запуске.
CWInventoryConfig.EnableWeaponSync = false

CWInventoryConfig.GridCell = 48

CWInventoryConfig.BaseContainers = {
    pockets = { label = 'Карманы', width = 4, height = 2, order = 10 },
    belt = { label = 'Пояс', width = 3, height = 1, order = 20 }
}

CWInventoryConfig.EquipmentSlots = {
    { id = 'hat', label = 'Головной убор', accepts = { clothing_hat = true }, order = 10 },
    { id = 'coat', label = 'Верхняя одежда', accepts = { clothing_coat = true }, order = 20 },
    { id = 'shirt', label = 'Рубаха', accepts = { clothing_shirt = true }, order = 30 },
    { id = 'pants', label = 'Штаны', accepts = { clothing_pants = true }, order = 40 },
    { id = 'boots', label = 'Обувь', accepts = { clothing_boots = true }, order = 50 },
    { id = 'vest', label = 'Разгрузка', accepts = { clothing_vest = true }, order = 60 },
    { id = 'holster_left', label = 'Кобура Л', accepts = { weapon_revolver = true, weapon_pistol = true }, order = 70 },
    { id = 'holster_right', label = 'Кобура П', accepts = { weapon_revolver = true, weapon_pistol = true }, order = 80 },
    { id = 'back_long_1', label = 'Двуручное 1', accepts = { weapon_longarm = true }, order = 90 },
    { id = 'back_long_2', label = 'Двуручное 2', accepts = { weapon_longarm = true }, order = 100 },
    { id = 'accessory_1', label = 'Украшение 1', accepts = { accessory = true }, order = 110 },
    { id = 'accessory_2', label = 'Украшение 2', accepts = { accessory = true }, order = 120 }
}

CWInventoryConfig.DefaultStarterItems = {
    -- Пустой список. Стартовый набор можно включить тут, когда решим, что должен получать новый персонаж.
    -- { name = 'bread', amount = 2 },
    -- { name = 'water', amount = 1 }
}
