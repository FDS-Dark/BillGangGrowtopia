local world = {
    name = "OPAISDKOPWA",
    id = "TESTWORLD",
    items = {
        ["1796"] = 53,
        ["7188"] = 1
    },
    positions = {
        ["1796"] = 558,
        ["7188"] = 568
    }
}

local bot = getBot()

local function count_dropped_locks()
    local items = {
        [1796] = 0,
        [7188] = 0
    }

    for _, object in pairs(bot:getWorld():getObjects()) do
        if object.id == 1796 then
            items[1796] = items[1796] + object.count
        elseif object.id == 7188 then
            items[7188] = items[7188] + object.count
        end
    end

    return items
end

    function divide_locks(world, target)
        local DLS = world.items["1796"]
        local BGLS = world.items["7188"]

        local world_objects = count_dropped_locks()

        if DLS ~= world_objects[1796] or BGLS ~= world_objects[7188] then
            response:setContent(json.encode({error_code = "MISMATCH_IN_SAVE_WORLD", error = "Observed lock count did not match up with saved lock count in save world "..bot:getWorld().name}), 'application/json')
            response.status = 404
            return false
        end

        -- world_objects is whats in the world
        -- target is the target amount of DLs to get

        -- Assume that world_objects is correct

        -- while bot:getInventory():getItemCount(1796) ~= target % 100 do
        --     if bot:getInventory():getItemCount(1796) < target % 100 then
        --         local dropped_locks = count_dropped_locks()

        --         if dropped_locks[1796] == 0 then
        --             for _, object in pairs(bot:getWorld():getObjects()) do
        --                 if object.id == 7188 then
        --                     o_x = math.floor((object.x + 6) / 32)
        --                     o_y = math.floor(object.y / 32)
        --                     bot:findPath(o_x, o_y)
        --                     sleep(500)
        --                     bot:collectObject(object.oid, 2)
        --                     sleep(1000)
        --                     break
        --                 end
        --             end
        --         else
        --             for _, object in pairs(bot:getWorld():getObjects()) do
        --                 if object.id == 1796 then
        --                     o_x = math.floor((object.x + 6) / 32)
        --                     o_y = math.floor(object.y / 32)
        --                     bot:findPath(o_x, o_y)
        --                     sleep(500)
        --                     bot:collectObject(object.oid, 2)
        --                     sleep(1000)
        --                     break
        --                 end
        --             end
        --         end
        --     elseif bot:getInventory():getItemCount(1796) > target % 100 then
        --         local DL_TILE_FOUND = false
        --         for _, tile in pairs(bot:getWorld():getTiles()) do
        --             if tile.bg == world.positions["1796"] then
        --                 for x = -1, 1, 2 do
        --                     local FIND_PATH = false

        --                     if #bot:getPath(tile.x+x, tile.y) > 0 then
        --                         DL_TILE_FOUND = true
        --                         bot:findPath(tile.x+x, tile.y)

        --                         sleep(500)
    
        --                         if x == -1 then
        --                             bot:setDirection(false)
        --                         elseif x == 1 then
        --                             bot:setDirection(true)
        --                         end
        --                         FIND_PATH = true
        --                         break
        --                     end
        --                 end
        --             end
        --         end

        --         if not DL_TILE_FOUND then
        --             response:setContent(json.encode({error_code = "ITEM_TILE_NOT_FOUND", error = "Diamond Lock tile not found in "..bot:getWorld().name}), 'application/json')
        --             response.status = 404
        --             return false
        --         end

        --         local drop_attempts = 0

        --         local before = bot:getInventory():getItemCount(1796)
        --         while bot:getInventory():getItemCount(1796) == before do
        --             if drop_attempts >= 5 then
        --                 response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
        --                 response.status = 404
        --                 return false
        --             else
        --                 bot:drop(1796, before-(target % 100))
        --                 sleep(500)
        --                 drop_attempts = drop_attempts + 1
        --             end
        --         end
        --     end
        -- end

        local BGL_TILE
        local BGL_DIRECTION
        local DL_TILE
        local DL_DIRECTION

        if not BGL_TILE then
            for _, tile in pairs(bot:getWorld():getTiles()) do
                if tile.bg == world.positions["7188"] then
                    for x = -1, 1, 2 do
                        if #bot:getPath(tile.x+x, tile.y) > 0 then
                            BGL_TILE = bot:getWorld():getTile(tile.x+x, tile.y)
                            
                            if x == -1 then
                                BGL_DIRECTION = false
                            elseif x == 1 then
                                BGL_DIRECTION = true
                            end
                            
                            -- bot:findPath(tile.x+x, tile.y)

                            -- sleep(500)

                            -- if x == -1 then
                                -- bot:setDirection(false)
                            -- elseif x == 1 then
                                -- bot:setDirection(true)
                            -- end

                            break
                        end
                    end
                end

                if BGL_TILE then
                    break
                end
            end
        end

        if not DL_TILE then
            for _, tile in pairs(bot:getWorld():getTiles()) do
                if tile.bg == world.positions["1796"] then
                    for x = -1, 1, 2 do
                        if #bot:getPath(tile.x+x, tile.y) > 0 then
                            DL_TILE = bot:getWorld():getTile(tile.x+x, tile.y)

                            if x == -1 then
                                BGL_DIRECTION = false
                            elseif x == 1 then
                                BGL_DIRECTION = true
                            end

                            -- bot:findPath(tile.x+x, tile.y)

                            -- sleep(500)

                            -- if x == -1 then
                                -- bot:setDirection(false)
                            -- elseif x == 1 then
                                -- bot:setDirection(true)
                            -- end

                            break
                        end
                    end
                end

                if DL_TILE then
                    break
                end
            end
        end
        
        while bot:getInventory():getItemCount(1796) ~= target % 100 do
            local counted_locks = count_dropped_locks()

            if not DL_TILE then
                response:setContent(json.encode({error_code = "ITEM_TILE_NOT_FOUND", error = "Blue Gem Lock tile not found in "..bot:getWorld().name}), 'application/json')
                response.status = 404
                return false
            end

            if counted_locks[1796] == 0 then
                bot:findPath(BGL_TILE.x, BGL_TILE.y)
                sleep(500)
                for _, object in pairs(bot:getWorld():getObjects()) do
                    if object.id == 7188 then
                        bot:collectObject(object.oid, 3)
                        sleep(500)
                        break
                    end
                end

                if bot:getInventory():getItemCount(7188) >= 1 then
                    local packet = GameUpdatePacket.new()
                    packet.type = 10
                    packet.int_data = 7188
                    packet.netid = bot:getWorld():getLocal().netid

                    bot:sendRaw(packet)
                    sleep(500)
                end

                local drop_attempts = 0

                if bot:getInventory():getItemCount(7188) >= 1 then
                    while bot:getInventory():getItemCount(7188) >= 0 do
                        if drop_attempts >= 5 then
                            response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
                            response.status = 404
                            return false
                        else
                            bot:drop(7188, bot:getInventory():getItemCount(7188))
                            sleep(500)
                            drop_attempts = drop_attempts + 1
                        end
                    end
                end
            end

            bot:findPath(DL_TILE.x, DL_TILE.y)
            sleep(500)
            bot:setDirection(DL_DIRECTION)
            sleep(150)

            if bot:getInventory():getItemCount(1796) < target % 100 then
                for _, object in pairs(bot:getWorld():getObjects()) do
                    if object.id == 1796 then
                        bot:collectObject(object.oid, 3)
                        sleep(250)
                        break
                    end
                end
            elseif bot:getInventory():getItemCount(1796) > target % 100 then
                local drop_attempts = 0

                local before = bot:getInventory():getItemCount(1796)
                while bot:getInventory():getItemCount(1796) == before do
                    if drop_attempts >= 5 then
                        response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
                        response.status = 404
                        return false
                    else
                        bot:drop(1796, before-(target % 100))
                        sleep(500)
                        drop_attempts = drop_attempts + 1
                    end
                end
            end
        end

        local BGL_TILE
        
        while bot:getInventory():getItemCount(7188) ~= math.floor(target / 100) do
            if not BGL_TILE then
                response:setContent(json.encode({error_code = "ITEM_TILE_NOT_FOUND", error = "Blue Gem Lock tile not found in "..bot:getWorld().name}), 'application/json')
                response.status = 404
                return false
            end

            local counted_locks = count_dropped_locks()

            if counter_locks[7188] == 0 then
                response:setContent(json.encode({error_code = "RAN_OUT_OF_BGLS", error = "Somehow ran out of BGLs"}), 'application/json')
                response.status = 404
                return false
            end

            bot:findPath(BGL_TILE.x, BGL_TILE.y)
            sleep(500)
            bot:setDirection(BGL_DIRECTION)
            sleep(150)

            if bot:getInventory():getItemCount(7188) < math.floor(target / 100) then
                for _, object in pairs(bot:getWorld():getObjects()) do
                    if object.id == 7188 then
                        bot:collectObject(object.oid, 3)
                        sleep(250)
                        break
                    end
                end
            elseif bot:getInventory():getItemCount(7188) > math.floor(target / 100) then
                local drop_attempts = 0

                local before = bot:getInventory():getItemCount(7188)
                while bot:getInventory():getItemCount(7188) == before do
                    if drop_attempts >= 5 then
                        response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
                        response.status = 404
                        return false
                    else
                        bot:drop(7188, before-(math.floor(target / 100)))
                        sleep(500)
                        drop_attempts = drop_attempts + 1
                    end
                end
            end
        end

                    -- if bot:getInventory():getItemCount(7188) < math.floor(target / 100) then
            --     for _, object in pairs(bot:getWorld():getObjects()) do
            --         if object.id == 7188 then
            --             o_x = math.floor((object.x + 6) / 32)
            --             o_y = math.floor(object.y / 32)
            --             bot:findPath(o_x, o_y)
            --             sleep(500)
            --             bot:collectObject(object.oid, 2)
            --             sleep(1000)
            --             break
            --         end
            --     end
            -- elseif bot:getInventory():getItemCount(7188) > math.floor(target / 100) then
            --     local BGL_TILE_FOUND = false
            --     for _, tile in pairs(bot:getWorld():getTiles()) do
            --         if tile.bg == world.positions["7188"] then
            --             for x = -1, 1, 2 do
            --                 local FIND_PATH = false

            --                 for y = -1, 1, 2 do
            --                     if #bot:getPath(tile.x+x, tile.y+y) > 0 then
            --                         BGL_TILE_FOUND = true
            --                         bot:findPath(tile.x+x, tile.y+y)

            --                         sleep(500)
        
            --                         if x == -1 then
            --                             bot:setDirection(false)
            --                         elseif x == 1 then
            --                             bot:setDirection(true)
            --                         end
            --                         FIND_PATH = true
            --                         break
            --                     end
            --                 end

            --                 if FIND_PATH then
            --                     break
            --                 end
            --             end
            --         end
            --     end

            --     if not BGL_TILE_FOUND then
            --         response:setContent(json.encode({error_code = "ITEM_TILE_NOT_FOUND", error = "Blue Gem Lock tile not found in "..bot:getWorld().name}), 'application/json')
            --         response.status = 404
            --         return false
            --     end

            --     local drop_attempts = 0

            --     local before = bot:getInventory():getItemCount(7188)
            --     while bot:getInventory():getItemCount(7188) == before do
            --         if drop_attempts >= 5 then
            --             response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
            --             response.status = 404
            --             return false
            --         else
            --             bot:drop(7188, before-math.floor(target / 100))
            --             sleep(500)
            --             drop_attempts = drop_attempts + 1
            --         end
            --     end
            -- end

        -- Determine how many DLs to drop to reach the target

        -- Final state

        return true
    end

local result = divide_locks(world, 97)

if not result then
    print('error')
end