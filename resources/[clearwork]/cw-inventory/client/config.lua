CWInventoryConfig = CWInventoryConfig or {}

CWInventoryConfig.OpenCommand = 'inventory'
CWInventoryConfig.OpenKey = 'I'
CWInventoryConfig.Debug = false

-- Пока выключено. Синхронизацию оружия с ванильным TAB-меню будем делать отдельным шагом.
CWInventoryConfig.EnableWeaponSync = false

-- Временный локальный мешок при выбросе предмета из /inventory.
CWInventoryConfig.DropBagModel = CWInventoryConfig.DropBagModel or 'p_bag01x'
