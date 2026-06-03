local uiOpen = false
local catalogLoaded = false
local lastEquipment = {}
local currentPreview = nil
local currentGender = 'male'
local fittingCam = nil
local fittingHeading = nil
local fittingStartCoords = nil
local baseApplied = false
local previewActive = false

local CATEGORY_HASHES = {
    hat = 'HATS',
    shirt = 'SHIRTS_FULL',
    coat = 'COATS',
    vest = 'VESTS',
    pants = 'PANTS',
    boots = 'BOOTS'
}

local BASE_ITEMS = {
    male = {
        'CLOTHING_ITEM_M_HEAD_001_V_001',
        'CLOTHING_ITEM_M_BODIES_UPPER_001_V_001',
        'CLOTHING_ITEM_M_BODIES_LOWER_001_V_001',
        'CLOTHING_ITEM_M_EYES_001_TINT_001',
        'CLOTHING_ITEM_M_TEETH_000',
        'CLOTHING_ITEM_M_HAIR_001_BLONDE'
    },
    female = {
        'CLOTHING_ITEM_F_HEAD_001_V_001',
        'CLOTHING_ITEM_F_BODIES_UPPER_001_V_001',
        'CLOTHING_ITEM_F_BODIES_LOWER_001_V_001',
        'CLOTHING_ITEM_F_EYES_001_TINT_001',
        'CLOTHING_ITEM_F_TEETH_000',
        'CLOTHING_ITEM_F_HAIR_001_BLONDE'
    }
}

local function notify(message)
    TriggerEvent('chat:addMessage', {
        color = { 210, 185, 120 },
        args = { 'cw-clothes', tostring(message or '') }
    })
end

local function h(value)
    if value == nil or value == '' then return nil end
    if type(value) == 'number' then return value end
    return GetHashKey(tostring(value))
end

local function getGenderKey()
    return currentGender == 'female' and 'female' or 'male'
end

local function setGenderFromCharacter(character)
    local gender = tostring(character and character.gender or ''):lower()

    if gender == 'female' or gender == 'f' or gender == 'woman' or gender == 'женщина' then
        currentGender = 'female'
    else
        currentGender = 'male'
    end
end

local function resolveGenderedHash(value)
    if type(value) == 'table' then
        return value[getGenderKey()] or value.male or value.female or value[1]
    end

    return value
end

local function updatePedVariation(ped)
    if not ped or ped == 0 then return end

    pcall(function()
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    end)
end

local function removeCategory(ped, category)
    local categoryHash = h(CATEGORY_HASHES[category] or category)
    if not categoryHash or not ped or ped == 0 then return end

    pcall(function()
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, categoryHash, 0)
    end)
end

local function applyShopItem(ped, shopItem)
    shopItem = resolveGenderedHash(shopItem)
    local shopItemHash = h(shopItem)

    if not shopItemHash then return false end

    local ok = pcall(function()
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, shopItemHash, true, true, true)
    end)

    return ok == true
end

local function applyBaseBody(force)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return false end

    if baseApplied and force ~= true then
        return true
    end

    -- Базовый MP ped часто появляется без тела/лица, если ему не применить metaped outfit/body.
    -- Сначала пробуем базовые shop items, потом fallback на random outfit variation.
    local list = BASE_ITEMS[getGenderKey()] or BASE_ITEMS.male

    for _, itemName in ipairs(list) do
        applyShopItem(ped, itemName)
    end

    pcall(function()
        Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    end)

    updatePedVariation(ped)
    baseApplied = true

    return true
end

local function applyComponent(category, component, isPreview)
    component = component or {}

    local ped = PlayerPedId()
    if not ped or ped == 0 then return false end

    applyBaseBody(false)

    local shopItem = resolveGenderedHash(component.shopItem)

    if shopItem then
        removeCategory(ped, category)
        local ok = applyShopItem(ped, shopItem)
        updatePedVariation(ped)

        if ok then
            return true
        end
    end

    local drawable = h(resolveGenderedHash(component.drawable))

    if drawable then
        removeCategory(ped, category)

        local ok = pcall(function()
            Citizen.InvokeNative(
                0xBC6DF00D7A4A6819,
                ped,
                drawable,
                h(resolveGenderedHash(component.albedo)) or 0,
                h(resolveGenderedHash(component.normal)) or 0,
                h(resolveGenderedHash(component.material)) or 0,
                h(resolveGenderedHash(component.palette)) or 0,
                tonumber(component.tint0) or 0,
                tonumber(component.tint1) or 0,
                tonumber(component.tint2) or 0
            )
        end)

        updatePedVariation(ped)
        return ok == true
    end

    if isPreview then
        SendNUIMessage({
            action = 'visualStatus',
            ok = false,
            text = 'Для этой позиции ещё не задан рабочий hash одежды.'
        })
    end

    return false
end

local function applyClothingFromItem(item)
    if type(item) ~= 'table' then return false end
    if type(item.metadata) ~= 'table' then return false end
    if type(item.metadata.clothing) ~= 'table' then return false end

    local clothing = item.metadata.clothing
    return applyComponent(clothing.category or clothing.slot, clothing.component or {}, false)
end

local function reapplyEquippedClothes()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    applyBaseBody(false)

    for _, categoryName in pairs(CATEGORY_HASHES) do
        -- Не трогаем здесь тело/лицо, только одежду. Категории снимаются точечно ниже при применении предметов.
    end

    if type(lastEquipment) ~= 'table' then
        return
    end

    for _, item in pairs(lastEquipment) do
        applyClothingFromItem(item)
    end
end

local function startFittingCamera()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    fittingStartCoords = GetEntityCoords(ped)
    fittingHeading = GetEntityHeading(ped)

    local forward = GetEntityForwardVector(ped)
    local camX = fittingStartCoords.x + forward.x * 2.0
    local camY = fittingStartCoords.y + forward.y * 2.0
    local camZ = fittingStartCoords.z + 0.85

    if fittingCam then
        DestroyCam(fittingCam, false)
        fittingCam = nil
    end

    fittingCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(fittingCam, camX, camY, camZ)
    PointCamAtEntity(fittingCam, ped, 0.0, 0.0, 0.65, true)
    SetCamFov(fittingCam, 45.0)
    RenderScriptCams(true, true, 450, true, true)

    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
end

local function stopFittingCamera()
    local ped = PlayerPedId()

    if fittingCam then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(fittingCam, false)
        fittingCam = nil
    end

    if ped and ped ~= 0 then
        FreezeEntityPosition(ped, false)

        if fittingHeading then
            SetEntityHeading(ped, fittingHeading)
        end
    end

    fittingHeading = nil
    fittingStartCoords = nil
end

local function setUI(state)
    uiOpen = state == true

    SetNuiFocus(uiOpen, uiOpen)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({ action = uiOpen and 'open' or 'close' })

    if uiOpen then
        applyBaseBody(false)
        reapplyEquippedClothes()
        startFittingCamera()
    else
        currentPreview = nil
        previewActive = false
        stopFittingCamera()
        reapplyEquippedClothes()
    end
end

RegisterCommand('clothes', function()
    TriggerServerEvent('cw-clothes:server:requestCatalog')
    TriggerServerEvent('cw-clothes:server:requestEquipped')
    Wait(150)
    setUI(true)
end, false)

RegisterNetEvent('cw-clothes:client:open', function()
    setUI(true)
end)

RegisterNetEvent('cw-clothes:client:catalog', function(payload)
    catalogLoaded = true
    SendNUIMessage({
        action = 'catalog',
        payload = payload or {}
    })
end)

RegisterNetEvent('cw-clothes:client:basket', function(basket)
    SendNUIMessage({
        action = 'basket',
        basket = basket or {}
    })
end)

RegisterNetEvent('cw-clothes:client:equipped', function(equipment)
    lastEquipment = equipment or {}
    reapplyEquippedClothes()
end)

RegisterNetEvent('cw-clothes:client:taken', function()
    notify('Одежда положена в твой инвентарь.')
end)

RegisterNetEvent('cw-inventory:client:setState', function(state)
    if type(state) == 'table' and type(state.equipment) == 'table' then
        lastEquipment = state.equipment
        reapplyEquippedClothes()
    end
end)

AddEventHandler('cw-spawn:client:spawnFinished', function(character)
    setGenderFromCharacter(character)
    baseApplied = false

    Wait(750)
    applyBaseBody(true)
    TriggerServerEvent('cw-clothes:server:requestEquipped')

    Wait(500)
    reapplyEquippedClothes()
end)

RegisterNUICallback('close', function(_, cb)
    setUI(false)
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    data = data or {}
    currentPreview = data
    previewActive = true

    local applied = applyComponent(data.categoryId, data.component or {}, true)

    SendNUIMessage({
        action = 'visualStatus',
        ok = applied,
        text = applied and 'Примерка применена на персонаже.' or 'Hash не сработал или не задан. Вещь купить можно, визуал появится после замены hash.'
    })

    cb({ ok = true, applied = applied })
end)

RegisterNUICallback('revertPreview', function(_, cb)
    previewActive = false
    reapplyEquippedClothes()
    cb({ ok = true })
end)

RegisterNUICallback('rotatePed', function(data, cb)
    data = data or {}
    local ped = PlayerPedId()

    if ped and ped ~= 0 then
        local delta = tonumber(data.delta) or 0.0
        SetEntityHeading(ped, GetEntityHeading(ped) + delta)
    end

    cb({ ok = true })
end)

RegisterNUICallback('addToVendor', function(data, cb)
    TriggerServerEvent('cw-clothes:server:addToVendor', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('buySelectedNow', function(data, cb)
    TriggerServerEvent('cw-clothes:server:buySelectedNow', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('takeFromVendor', function(data, cb)
    TriggerServerEvent('cw-clothes:server:takeFromVendor', data and data.orderId)
    cb({ ok = true })
end)

RegisterNUICallback('takeAllFromVendor', function(_, cb)
    TriggerServerEvent('cw-clothes:server:takeAllFromVendor')
    cb({ ok = true })
end)

RegisterNUICallback('clearVendor', function(_, cb)
    TriggerServerEvent('cw-clothes:server:clearVendor')
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if uiOpen then
            DisableControlAction(0, 0x07CE1E61, true) -- attack
            DisableControlAction(0, 0xF84FA74F, true) -- aim
            Wait(0)
        else
            Wait(750)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Wait(1500)
    applyBaseBody(false)
    TriggerServerEvent('cw-clothes:server:requestEquipped')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    stopFittingCamera()
end)
