local uiOpen = false
local catalogLoaded = false
local lastInventoryState = nil
local currentPreview = nil

local CATEGORY_HASHES = {
    hat = 'hats',
    shirt = 'shirts_full',
    coat = 'coats',
    vest = 'vests',
    pants = 'pants',
    boots = 'boots'
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

local function updatePedVariation(ped)
    pcall(function()
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    end)
end

local function removeCategory(ped, category)
    local categoryHash = h(CATEGORY_HASHES[category] or category)
    if not categoryHash then return end

    pcall(function()
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, categoryHash, 0)
    end)
end

local function applyComponent(category, component)
    component = component or {}

    local ped = PlayerPedId()
    if not ped or ped == 0 then return false end

    local shopItem = h(component.shopItem)

    if shopItem then
        removeCategory(ped, category)

        pcall(function()
            Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, shopItem, true, true, true)
        end)

        updatePedVariation(ped)
        return true
    end

    local drawable = h(component.drawable)

    if drawable then
        removeCategory(ped, category)

        pcall(function()
            Citizen.InvokeNative(
                0xBC6DF00D7A4A6819,
                ped,
                drawable,
                h(component.albedo) or 0,
                h(component.normal) or 0,
                h(component.material) or 0,
                h(component.palette) or 0,
                tonumber(component.tint0) or 0,
                tonumber(component.tint1) or 0,
                tonumber(component.tint2) or 0
            )
        end)

        updatePedVariation(ped)
        return true
    end

    return false
end

local function applyClothingFromItem(item)
    if type(item) ~= 'table' then return false end
    if type(item.metadata) ~= 'table' then return false end
    if type(item.metadata.clothing) ~= 'table' then return false end

    local clothing = item.metadata.clothing
    return applyComponent(clothing.category, clothing.component or {})
end

local function reapplyEquippedClothes()
    if not lastInventoryState or type(lastInventoryState.equipment) ~= 'table' then
        return
    end

    for _, item in pairs(lastInventoryState.equipment) do
        applyClothingFromItem(item)
    end
end

local function setUI(state)
    uiOpen = state == true
    SetNuiFocus(uiOpen, uiOpen)
    SendNUIMessage({ action = uiOpen and 'open' or 'close' })

    if not uiOpen then
        currentPreview = nil
        reapplyEquippedClothes()
    end
end

RegisterCommand('clothes', function()
    TriggerServerEvent('cw-clothes:server:requestCatalog')
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

RegisterNetEvent('cw-clothes:client:taken', function()
    notify('Одежда забрана. Открой /inventory и перетащи её в нужный слот.')
end)

RegisterNetEvent('cw-inventory:client:setState', function(state)
    lastInventoryState = state
    reapplyEquippedClothes()
end)

RegisterNUICallback('close', function(_, cb)
    setUI(false)
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    data = data or {}
    currentPreview = data

    local applied = applyComponent(data.categoryId, data.component or {})

    if not applied then
        -- Это не ошибка механики. Просто в каталоге пока нет реального shopItem/drawable hash.
        -- Когда заполним каталог из RSG/RDR3 clothes database, превью начнёт менять одежду.
    end

    cb({ ok = true, applied = applied })
end)

RegisterNUICallback('addToVendor', function(data, cb)
    TriggerServerEvent('cw-clothes:server:addToVendor', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('takeFromVendor', function(data, cb)
    TriggerServerEvent('cw-clothes:server:takeFromVendor', data and data.orderId)
    cb({ ok = true })
end)

RegisterNUICallback('clearVendor', function(_, cb)
    TriggerServerEvent('cw-clothes:server:clearVendor')
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
