local LastEquipped = {}

local ClothingComponents = {
    hair = { component = 2, label = 'Hair' },
    mask = { component = 1, label = 'Mask' },
    top = { component = 11, label = 'Top' },
    gloves = { component = 3, label = 'Gloves' },
    vest = { component = 9, label = 'Vest' },
    bag = { component = 5, label = 'Bag' },
    shoes = { component = 6, label = 'Shoes' },
    pants = { component = 4, label = 'Pants' },
    shirt = { component = 8, label = 'Shirt' },
    neck = { component = 7, label = 'Neck' }
}

local PropComponents = {
    hat = { prop = 0, label = 'Hat' },
    glasses = { prop = 1, label = 'Glasses' },
    ear = { prop = 2, label = 'Ear Piece' },
    watch = { prop = 6, label = 'Watch' },
    bracelet = { prop = 7, label = 'Bracelet' }
}

RegisterNetEvent('codem-radialmenu:client:ToggleClothing', function(data)
    local ped = PlayerPedId()
    local componentName = data.component

    if not componentName then return end

    local clothingData = ClothingComponents[componentName]
    if not clothingData then
        Framework:Notify(nil, 'Invalid clothing component', 'error')
        return
    end

    local component = clothingData.component

    local currentDrawable = GetPedDrawableVariation(ped, component)
    local currentTexture = GetPedTextureVariation(ped, component)

    if LastEquipped[componentName] then
        local gender = GetPedType(ped) == 4 and 'male' or 'female'
        local defaultDrawable = gender == 'male' and 0 or 0
        local defaultTexture = 0

        if componentName == 'top' then
            defaultDrawable = gender == 'male' and 15 or 15
        elseif componentName == 'pants' then
            defaultDrawable = gender == 'male' and 14 or 14
        elseif componentName == 'shoes' then
            defaultDrawable = gender == 'male' and 34 or 35
        end

        SetPedComponentVariation(ped, component, defaultDrawable, defaultTexture, 0)
        LastEquipped[componentName] = nil

        Framework:Notify(nil, clothingData.label .. ' removed', 'success')
    else
        LastEquipped[componentName] = {
            drawable = currentDrawable,
            texture = currentTexture
        }

        Framework:Notify(nil, clothingData.label .. ' equipped', 'success')
    end
end)

RegisterNetEvent('codem-radialmenu:client:ToggleProp', function(data)
    local ped = PlayerPedId()
    local componentName = data.component

    if not componentName then return end

    local propData = PropComponents[componentName]
    if not propData then
        Framework:Notify(nil, 'Invalid prop component', 'error')
        return
    end

    local prop = propData.prop

    local currentProp = GetPedPropIndex(ped, prop)
    local currentTexture = GetPedPropTextureIndex(ped, prop)

    if currentProp ~= -1 and LastEquipped[componentName] then
        ClearPedProp(ped, prop)
        LastEquipped[componentName] = nil

        Framework:Notify(nil, propData.label .. ' removed', 'success')
    else
        if currentProp ~= -1 then
            LastEquipped[componentName] = {
                prop = currentProp,
                texture = currentTexture
            }

            Framework:Notify(nil, propData.label .. ' equipped', 'success')
        else
            Framework:Notify(nil, 'No ' .. propData.label .. ' to toggle', 'error')
        end
    end
end)
