function distribute_items_to_worlds(worlds, items)
    local num_worlds = #worlds
    local distribution = {}

    for _, world in ipairs(worlds) do
        distribution[world.name] = {id = world.id, items = {}, positions = {}}
        for item_id, total_quantity in pairs(items) do
            local quantity_per_world = math.floor(total_quantity / num_worlds)
            distribution[world.name].items[item_id] = quantity_per_world
            distribution[world.name].positions[item_id] = world.positions[item_id]
        end
    end

    local world_index = 1
    for item_id, total_quantity in pairs(items) do
        local remainder = total_quantity % num_worlds
        for i = 1, remainder do
            local world_name = worlds[world_index].name
            distribution[world_name].items[item_id] = distribution[world_name].items[item_id] + 1
            world_index = world_index + 1
            if world_index > num_worlds then
                world_index = 1
            end
        end
    end

    return distribution
end

-- Example usage:
local worlds = {
    {name = "World1", id = "ID1", positions = {["1796"] = 1, ["7188"] = 2}},
    {name = "World2", id = "ID2", positions = {["1796"] = 3, ["7188"] = 4}},
    {name = "World3", id = "ID3", positions = {["1796"] = 5, ["7188"] = 6}}
}

local items = {
    ["1796"] = 10,
    ["7188"] = 20
}

local result = distribute_items_to_worlds(worlds, items)

-- Example result:
-- result = {
--     World1 = { id = "ID1", items = { [1796] = 3, [7188] = 7 }, positions = { [1796] = 1, [7188] = 2 } },
--     World2 = { id = "ID2", items = { [1796] = 3, [7188] = 7 }, positions = { [1796] = 3, [7188] = 4 } },
--     World3 = { id = "ID3", items = { [1796] = 4, [7188] = 6 }, positions = { [1796] = 5, [7188] = 6 } }
-- }

for world_name, data in pairs(result) do
    print(world_name .. " (ID: " .. data.id .. "):")
    for item_id, quantity in pairs(data.items) do
        print("  Item ID " .. item_id .. ": " .. quantity .. " items at position " .. data.positions[item_id])
    end
end