local Items = CWItems or {}

local function copy(value)
    local ok, encoded = pcall(json.encode, value or {})
    if not ok then return {} end

    local ok2, decoded = pcall(json.decode, encoded)
    if ok2 and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

exports('GetItem', function(itemName)
    local item = Items.Get and Items.Get(itemName) or nil
    if not item then return nil end
    return copy(item)
end)

exports('ItemExists', function(itemName)
    return Items.Exists and Items.Exists(itemName) or false
end)

exports('GetItemDefinitions', function()
    if not Items.GetAll then return {} end
    return copy(Items.GetAll())
end)

exports('GetClientDefinitions', function()
    if not Items.GetClientDefinitions then return {} end
    return copy(Items.GetClientDefinitions())
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local count = 0
    for _ in pairs(Items.Definitions or {}) do
        count = count + 1
    end

    print(('[cw-items] loaded %s item definitions'):format(count))
end)
