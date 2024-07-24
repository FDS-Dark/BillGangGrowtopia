server = HttpServer.new()

server:post("/delivery", function(request, response)

    local json = require('json')
	authorization = "REDACTED"

    params = json.decode(request.body)

	local client_authorization = params.authorization

	if client_authorization ~= authorization then
		response.status = 403
		response:setContent("Access Denied")
		return
	end
    
    local account_details = params.account_details
    local world_data = params.world_data
    local output_world = params.output_world
    local quantity = params.quantity

    local function POST(url, data)
    	local json_payload = data
        
        local json_payload_str = json.encode(json_payload)
    
        local client = HttpClient.new()
        client:setMethod(Method.post)
        client.url = url
        client.headers = {["Content-Type"] = "application/json"}
        client.content = json_payload_str
        local result = client:request()
    end

    local bot

    if account_details.type == "UBICONNECT" then
        if not getBot(account_details.name) then
            addUbiBot(account_details.username, account_details.password, account_details.secret)
            local bots = getBots()
            bot = bots[#bots]
        else
            bot = getBot(account_details.name)
        end
    elseif account_details.type == "LEGACY" then
        if not getBot(account_details.name) then
            addBot(account_details.username, account_details.password)
            local bots = getBots()
            bot = bots[#bots]
        else
            bot = getBot(account_details.name)
        end
    end

    local function count_locks()
        local items = {
            [1796] = 0,
            [7188] = 0
        }

        for _, item in pairs(bot:getInventory():getItems()) do
            if item.id == 1796 then
                items[1796] = items[1796] + item.count
            elseif item.id == 7188 then
                items[7188] = items[7188] + item.count
            end
        end

        return items
    end

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

    local function find_tile(id)
        for _, tile in pairs(bot:getWorld():getTiles()) do
            if tile.fg == id or tile.bg == id then
                return tile
            end
        end

        return false
    end

        -- Function to achieve the target count of diamond locks
    -- Know while running this:
    -- Bot is in save world

    -- items is given via POST request in world_data (world_data.items)
    local function divide_locks(world, target, start_counts)
        print('target: ', target)
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
        
        print('target dls: ', bot:getInventory():getItemCount(1796) ~= (target % 100) + start_counts[1796])
        while bot:getInventory():getItemCount(1796) ~= (target % 100) + start_counts[1796] do
            local counted_locks = count_dropped_locks()

            if not DL_TILE then
                response:setContent(json.encode({error_code = "ITEM_TILE_NOT_FOUND", error = "Blue Gem Lock tile not found in "..bot:getWorld().name}), 'application/json')
                response.status = 404
                return false
            end

            if counted_locks[1796] == 0 and bot:getInventory():getItemCount(1796) < (target % 100) + start_counts[1796] then
                bot:findPath(BGL_TILE.x, BGL_TILE.y)
                sleep(500)
                for _, object in pairs(bot:getWorld():getObjects()) do
                    if object.id == 7188 then
                        bot:collectObject(object.oid, 3)
                        sleep(500)
                        break
                    end
                end

                if bot:getInventory():getItemCount(7188) >= 1 + start_counts[7188] then
                    local packet = GameUpdatePacket.new()
                    packet.type = 10
                    packet.int_data = 7188
                    packet.netid = bot:getWorld():getLocal().netid

                    bot:sendRaw(packet)
                    sleep(500)
                end

                local drop_attempts = 0

                if bot:getInventory():getItemCount(7188) >= 1 + start_counts[7188] then
                    while bot:getInventory():getItemCount(7188) >= 0 + start_counts[7188] do
                        if drop_attempts >= 5 then
                            response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
                            response.status = 404
                            return false
                        else
                            bot:drop(7188, bot:getInventory():getItemCount(7188)-start_counts[7188])
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

            if bot:getInventory():getItemCount(1796) < (target % 100) + start_counts[1796] then
                for _, object in pairs(bot:getWorld():getObjects()) do
                    if object.id == 1796 then
                        bot:collectObject(object.oid, 3)
                        sleep(250)
                        break
                    end
                end
            elseif bot:getInventory():getItemCount(1796) > (target % 100) + start_counts[1796] then
                local drop_attempts = 0

                local before = bot:getInventory():getItemCount(1796)
                while bot:getInventory():getItemCount(1796) == before do
                    if drop_attempts >= 5 then
                        response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
                        response.status = 404
                        return false
                    else
                        bot:drop(1796, before-(target % 100)-start_counts[1796])
                        sleep(500)
                        drop_attempts = drop_attempts + 1
                    end
                end
            end
        end

        local BGL_TILE
        
        print('target bgls: ', bot:getInventory():getItemCount(1796) ~= (target % 100) + start_counts[1796])
        while bot:getInventory():getItemCount(7188) ~= math.floor(target / 100) + start_counts[7188] do
            if not BGL_TILE then
                response:setContent(json.encode({error_code = "ITEM_TILE_NOT_FOUND", error = "Blue Gem Lock tile not found in "..bot:getWorld().name}), 'application/json')
                response.status = 404
                return false
            end

            local counted_locks = count_dropped_locks()

            if counted_locks[7188] == 0 then
                response:setContent(json.encode({error_code = "RAN_OUT_OF_BGLS", error = "Somehow ran out of BGLs"}), 'application/json')
                response.status = 404
                return false
            end

            bot:findPath(BGL_TILE.x, BGL_TILE.y)
            sleep(500)
            bot:setDirection(BGL_DIRECTION)
            sleep(150)

            if bot:getInventory():getItemCount(7188) < math.floor(target / 100) + start_counts[7188] then
                for _, object in pairs(bot:getWorld():getObjects()) do
                    if object.id == 7188 then
                        bot:collectObject(object.oid, 3)
                        sleep(250)
                        break
                    end
                end
            elseif bot:getInventory():getItemCount(7188) > math.floor(target / 100) + start_counts[7188] then
                local drop_attempts = 0

                local before = bot:getInventory():getItemCount(7188)
                while bot:getInventory():getItemCount(7188) == before do
                    if drop_attempts >= 5 then
                        response:setContent(json.encode({error_code = "FAILED_TO_DROP_BACK", error = bot.name.." failed to drop extra locks back to deposit world "..bot:getWorld().name}), 'application/json')
                        response.status = 404
                        return false
                    else
                        bot:drop(7188, before-(math.floor(target / 100))-start_counts[7188])
                        sleep(500)
                        drop_attempts = drop_attempts + 1
                    end
                end
            end
        end

        local new_locks = count_dropped_locks()

        POST("http://73.247.130.199:3730/update_amount", {world = world.name, amounts = new_locks})
        -- print("POSTED NEW LOCK DATA")
        return true
    end

    -- Evenly distributes count_locks() over the worlds in the world_data array

    -- Example:

    -- items = { [1796] = 10, [7188] = 20 }

    -- worlds = {
    --     {name = "World1", id = "ID1", positions = {[1796] = 1, [7188] = 2}},
    --     {name = "World2", id = "ID2", positions = {[1796] = 3, [7188] = 4}},
    --     {name = "World3", id = "ID3", positions = {[1796] = 5, [7188] = 6}}
    -- }

    -- Example result:
    -- result = {
    --     World1 = { id = "ID1", items = { [1796] = 3, [7188] = 7 }, positions = { [1796] = 1, [7188] = 2 } },
    --     World2 = { id = "ID2", items = { [1796] = 3, [7188] = 7 }, positions = { [1796] = 3, [7188] = 4 } },
    --     World3 = { id = "ID3", items = { [1796] = 4, [7188] = 6 }, positions = { [1796] = 5, [7188] = 6 } }
    -- }

    local function distribute_locks(worlds, items)
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

    function return_to_saves()
        local items = count_locks()
        
        local distributed = distribute_locks(world_data, items)
    end

    sleep(1500)

    local retry_count = 0
    local login_fail_count = 0

    while bot.status ~= BotStatus.online do
        if retry_count >= 5 or login_fail_count >= 8 then
            response:setContent(json.encode({error_code = "ERROR_CONNECTING", error = "Failed to log on to bot account "..account_details.username..". Proxy "..bot:getProxy().ip.." might be shadowbanned.", username = account_details.username}), 'application/json')
            response.status = 404
            return
        elseif bot.status == BotStatus.account_banned then
            response:setContent(json.encode({error_code = "BAN", error = "Bot account "..account_details.username.." has been suspended.", username = account_details.username}), 'application/json')
            response.status = 404
            return
        elseif bot.status == BotStatus.logon_fail then
            bot:connect()
            sleep(5000)
            login_fail_count = login_fail_count + 1
        elseif bot.status == BotStatus.offline and bot:getPing() == 0 then
            sleep(1500)
            if bot.status == BotStatus.offline and bot:getPing() == 0 then
                bot:connect()
                sleep(8000)
                retry_count = retry_count + 1
            end
        else
            sleep(2000)
        end
    end

    local join_count = 0

    while bot:getWorld().name:lower() ~= output_world:lower() do
        if join_count >= 5 then
            response:setContent(json.encode({error_code = "OUTPUT_WORLD_CHECK_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to check world "..output_world.." for unknown reasons."}), 'application/json')
            response.status = 404
            return
        else
            bot:warp(output_world)
            sleep(8000)
            join_count = join_count + 1
        end
    end

    local donation_box
    local donation_box_coordinates

    local display_box
    local display_box_coordinates

    -- Find and pathfind to donation box

    for _, tile in pairs(bot:getWorld():getTiles()) do
        if tile.fg == 1452 then
            for x = -1, 1 do
                for y = -1, 1 do
                    if #bot:getPath(tile.x+x, tile.y+y) > 0 then
                        donation_box = tile
                        donation_box_coordinates = {x = tile.x+x, y = tile.y+y}
                        break
                    end
                end

                if donation_box then
                    break
                end
            end
        end
    end

    for _, tile in pairs(bot:getWorld():getTiles()) do
        if tile.fg == 1422 or tile.fg == 2488 then
            for x = -1, 1, 2 do
                if #bot:getPath(tile.x+x, tile.y) > 0 then
                    display_box = tile
                    display_box_coordinates = {x = tile.x+x, y = tile.y}

                    if x == -1 then
                        display_box_coordinates.left = false
                    elseif x == 1 then
                        display_box_coordinates.left = true
                    end
                    break
                end
            end
        end
    end

    -- If donation box isn't found, find a display box

    if not donation_box and not display_box then
        response:setContent(json.encode({error_code = "DELIVERY_FAIL", error = "Bot account "..account_details.username.." could not find a delivery location for world "..output_world.."."}), 'application/json')
        response.status = 404
        return
    end

    local amounts = {
        [7188] = math.floor(quantity / 100), -- Blue Gem Locks
        [1796] = quantity % 100 -- Diamond Locks
    }

    for _, world in pairs(world_data) do
        local amount = world.amount

        local join_count = 0

        while bot:getWorld().name:lower() ~= world.name:lower() do
            if join_count >= 5 then
                response:setContent(json.encode({error_code = "SAVE_WORLD_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to join save world "..output_world.." for unknown reasons. Please check if it has been nuked!"}), 'application/json')
                response.status = 404
                return
            else
                bot:warp(world.name, world.id)
                sleep(8000)
                join_count = join_count + 1
            end
        end

        local start_counts = count_locks()
        
        local result = divide_locks(world, amount, start_counts)

        if not result then
            return
        end

        if bot:getInventory():getItemCount(1796) >= 100 then
            local telephone = find_tile(3898)

            if not telephone then
                response:setContent(json.encode({error_code = "SAVE_WORLD_TELEPHONE_NOT_FOUND", error = "Failed to find telephone in save world "..output_world}), 'application/json')
                response.status = 404
                return
            end

            local PATH_FOUND = false

            for x = -1, 1 do
                for y = 1, -1, -2 do
                    if #bot:getPath(telephone.x+x, telephone.y+y) > 0 then
                        PATH_FOUND = true
                        bot:findPath(telephone.x+x, telephone.y+y)
                        sleep(500)
                        break
                    end
                end

                if PATH_FOUND then
                    break
                end
            end

            if not PATH_FOUND then
                response:setContent(json.encode({error_code = "SAVE_WORLD_TELEPHONE_PATHFINDING_ERROR", error = "Failed to pathfind to telephone in save world "..output_world}), 'application/json')
                response.status = 404
                return
            end

            bot:wrench(telephone.x, telephone.y)
            sleep(500)
            bot:sendPacket(2, "action|dialog_return\ndialog_name|phonecall\ntilex|"..telephone.x.."|\ntiley|"..telephone.y.."|\nnum|-2|\ndial|53785")
            sleep(500)
            bot:sendPacket(2, "action|dialog_return\ndialog_name|phonecall\ntilex|"..telephone.x.."|\ntiley|"..telephone.y.."|\nnum|53785|\nbuttonClicked|chc5")
            sleep(500)
            bot:sendPacket(2, "action|dialog_return\ndialog_name|phonecall\ntilex|"..telephone.x.."|\ntiley|"..telephone.y.."|\nnum|-34|\nbuttonClicked|chc0")
            sleep(500)
        end  

        -- local COLLECT_LOGS = {}

        -- for id, amount in pairs(amounts) do
        --     local amount_to_collect = amount
            
        --     for _, object in pairs(bot:getWorld():getObjects()) do
        --         if amount_to_collect > 0 then
        --             if object.id == id then
        --                 previous_amount = bot:getInventory():getItemCount(id)

        --                 o_x = math.floor((object.x + 6) / 32)
        --                 o_y = math.floor(object.y / 32)
        --                 bot:findPath(o_x, o_y)
        --                 sleep(500)
        --                 bot:collectObject(object.oid, 2)
        --                 sleep(500)

        --                 collected = bot:getInventory():getItemCount(id) - previous_amount
        --                 amount_to_collect = amount_to_collect - collected
        --                 excess = collected - object.amount

        --                 table.insert(COLLECT_LOGS, {world = world.name, id = object.id, amount = collected})
        --                 sleep(1000)

        --                 if excess >= 1 then
        --                     if #bot:getWorld():getTile(o_x-1, o_y).fg > 0 then
        --                         bot:findPath(o_x-1, o_y)
        --                         bot:setDirection(false)
        --                     elseif #bot:getWorld():getTile(o_x+1, o_y).fg > 0 then
        --                         bot:findPath(o_x+1, o_y)
        --                         bot:setDirection(true)
        --                     else
        --                         response:setContent(json.encode({error_code = "FAILED_TO_DROP_EXCESS", error = "Bot account "..account_details.username.." failed to drop excess items at "..output_world.." as no path was found. Please check world ASAP!"}), 'application/json')
        --                         response.status = 404
        --                         return
        --                     end

        --                     sleep(500)
        --                     bot:drop(id, excess)
        --                 end
        --             end
        --         else
        --             if bot:getInventory():getItemCount(id) ~= amount then
        --                 amount_to_collect = amount - bot:getInventory():getItemCount(id)
        --             end
        --         end
        --     end
        -- end
    end

    if bot:getInventory():getItemCount(7188) ~= amounts[7188] or bot:getInventory():getItemCount(1796) ~= amounts[1796] then
        response:setContent(json.encode({error_code = "PICKUP_MISCOUNT", error = "Bot account "..account_details.username.." failed to collect the correct amount of items.\n\nBlue Gem Locks needed: "..amounts[7188].."\nBlue Gem Locks collected: "..bot:getInventory():getItemCount(7188).."\n\nDiamond Locks needed: "..amounts[7188].."\nDiamond Locks collected: "..bot:getInventory():getItemCount(1796).."\n\nPlease check ASAP!"}), 'application/json')
        response.status = 404
        return_to_saves()
        return
    end

    local join_count = 0

    while bot:getWorld().name:lower() ~= output_world:lower() do
        if join_count >= 5 then
            response:setContent(json.encode({error_code = "OUTPUT_WORLD_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to join world "..output_world.." for unknown reasons."}), 'application/json')
            response.status = 404
            return_to_saves()
            return
        else
            bot:warp(output_world)
            sleep(8000)
            join_count = join_count + 1
        end
    end

    if donation_box then
        bot:findPath(donation_box_coordinates.x, donation_box_coordinates.y)
        sleep(1000)
        local DROP_LOGS = {}
        local skip_to_display_box = false

        for id, amount in pairs(amounts) do
            local drop_attempts = 0
            
            while bot:getInventory():getItemCount(id) > 0 do
                if drop_attempts >= 5 and not display_box then
                    response:setContent(json.encode({error_code = "OUTPUT_WORLD_DISPLAY_BOX_DROP_FAILED", error = "Bot account "..account_details.username.." failed to deliver items to the donation box in "..output_world.." for unknown reasons and there was no display box. Check ASAP!"}), 'application/json')
                    response.status = 404

                    return_to_saves()
                    return
                elseif drop_attempts >= 5 and display_box then
                    skip_to_display_box = true
                    break
                else
                    bot:wrench(donation_box.x, donation_box.y)
                    sleep(1000)
                    bot:sendPacket(2, "action|dialog_return\ndialog_name|donation_box_edit\ntilex|"..donation_box.x.."|\ntiley|"..donation_box.y.."|\nitemid|"..id)
                    sleep(1250)
                    bot:sendPacket(2, "action|dialog_return\ndialog_name|give_item\ncount|"..amount.."\nsign_text|Thank you for your business!\nitemID|"..id.."|\ntilex|"..donation_box.x.."|\ntiley|"..donation_box.y.."|\nbuttonClicked|give")
                    sleep(500)
                    table.insert(DROP_LOGS, {world = output_world, id = id, amount = dropped})
                    drop_attempts = drop_attempts + 1
                end
            end

            if skip_to_display_box then
                break
            end
        end
    end

    if display_box or skip_to_display_box then
        bot:findPath(display_box_coordinates.x, display_box_coordinates.y)
        sleep(1000)
        bot:setDirection(display_box_coordinates.left)
        sleep(250)
        
        local DROP_LOGS = {}

        for id, amount in pairs(amounts) do
            local drop_attempts = 0

            while bot:getInventory():getItemCount(id) > 0 do
                if drop_attempts >= 5 then
                    response:setContent(json.encode({error_code = "OUTPUT_WORLD_DISPLAY_BOX_DROP_FAILED", error = "Bot account "..account_details.username.." failed to drop items to "..output_world.." for unknown reasons. Check ASAP!"}), 'application/json')
                    response.status = 404

                    return_to_saves()
                    return
                else
                    amount_before = bot:getInventory():getItemCount(id)
                    bot:drop(id, amount)
                    dropped = amount_before - bot:getInventory():getItemCount(id)

                    table.insert(DROP_LOGS, {world = output_world, id = id, amount = dropped})
                    sleep(500)
                    drop_attempts = drop_attempts + 1
                end
            end
        end
    end

    if bot:getInventory():getItemCount(7188) ~= 0 or bot:getInventory():getItemCount(1796) ~= 0 then
        response:setContent(json.encode({error_code = "DROPPED_AN_INCORRECT_AMOUNT", error = "Bot account "..account_details.username.." dropped an incorrect (smaller than expected) amount of items to "..output_world.." for unknown reasons. Returned extras to save worlds!"}), 'application/json')
        response.status = 404

        return_to_saves()
        return
    end

    bot:leaveWorld()
    sleep(1000)

    response:setContent(json.encode({content = "Successfully distributed diamond locks to "..output_world.."!", time = os.time()}), 'application/json')
    response.status = 200
    runThread(function(bot_name)
        local function generateRandomWorld(length)
            local characters
            
            if include_numbers then
                characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            else
                characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            end
            
            local randomWorld = ""
            
            for i = 1, length do
                local randomIndex = math.random(1, #characters)
                randomWorld = randomWorld .. string.sub(characters, randomIndex, randomIndex)
            end
            
            return randomWorld
        end

        local bot = getBot(bot_name)
        if bot then
            for i = 1, 10 do
                bot:warp(generateRandomWorld(14))
                sleep(5000)
            end
        end
    end, bot.name)
    return
end)

server:post("/distribute1", function(request, response)
    local json = require('json')
    
    authorization = "REDACTED"
    params = json.decode(request.body)

    for key, value in pairs(params) do
        print(key, value)
    end

	local client_authorization = params.authorization

	if client_authorization ~= authorization then
		response.status = 403
		response:setContent("Access Denied")
		return
	end

    local function generateRandomWorld(length)
        local characters
        
        if include_numbers then
            characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        else
            characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        end
        
        local randomWorld = ""
        
        for i = 1, length do
            local randomIndex = math.random(1, #characters)
            randomWorld = randomWorld .. string.sub(characters, randomIndex, randomIndex)
        end
        
        return randomWorld
    end

    local account_details = params.account_details

    local bot

    if account_details.type == "UBICONNECT" then
        if not getBot(account_details.name) then
            addUbiBot(account_details.username, account_details.password, account_details.secret)
            local bots = getBots()
            bot = bots[#bots]
        else
            bot = getBot(account_details.name)
        end
    elseif account_details.type == "LEGACY" then
        if not getBot(account_details.name) then
            addBot(account_details.username, account_details.password)
            local bots = getBots()
            bot = bots[#bots]
        else
            bot = getBot(account_details.name)
        end
    end

    sleep(1500)

    local retry_count = 0
    local login_fail_count = 0

    while bot.status ~= BotStatus.online do
        if retry_count >= 5 or login_fail_count >= 8 then
            response:setContent(json.encode({error_code = "ERROR_CONNECTING", error = "Failed to log on to bot account "..account_details.username..". Proxy "..bot:getProxy().ip.." might be shadowbanned.", username = account_details.username}), 'application/json')
            response.status = 404

            removeBot(bot.name)
            return
        elseif bot.status == BotStatus.account_banned then
            response:setContent(json.encode({error_code = "BAN", error = "Bot account "..account_details.username.." has been suspended.", username = account_details.username}), 'application/json')
            response.status = 404
            
            removeBot(bot.name)
            return
        elseif bot.status == BotStatus.logon_fail then
            bot:connect()
            sleep(8000)
            login_fail_count = login_fail_count + 1
        elseif bot.status == BotStatus.offline and bot:getPing() == 0 then
            sleep(1500)
            if bot.status == BotStatus.offline and bot:getPing() == 0 then
                bot:connect()
                sleep(8000)
                retry_count = retry_count + 1
            end
        else
            sleep(1000)
        end
    end

    local world = generateRandomWorld(14)

    local join_count = 0

    while bot:getWorld().name:lower() ~= world:lower() do
        if join_count >= 5 then
            response:setContent(json.encode({error_code = "RANDOM_WORLD_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to join random world "..world.." for unknown reasons."}), 'application/json')
            response.status = 404
            return
        else
            bot:warp(world)
            sleep(8000)
            join_count = join_count + 1
        end
    end

    response:setContent(json.encode({content = "World Name Found", world_name = bot:getWorld().name, bot_name = bot.name}), 'application/json')
    response.status = 200
    return
end)

server:post("/distribute2", function(request, response)
    local json = require('json')
    
    authorization = "REDACTED"

    params = json.decode(request.body)

	local client_authorization = params.authorization

	if client_authorization ~= authorization then
		response.status = 403
		response:setContent("Access Denied")
		return
	end

    local bot_name = params.bot_name
    local world_data = params.world_data
    local offset = params.offset
    local owner_id = params.owner_id

    local bot = getBot(bot_name)

    local function count_locks()
        local items = {
            [1796] = 0,
            [7188] = 0
        }

        for _, item in pairs(bot:getInventory():getItems()) do
            if item.id == 1796 then
                items[1796] = items[1796] + item.count
            elseif item.id == 7188 then
                items[7188] = items[7188] + item.count
            end
        end

        return items
    end

    local function count_locks_string()
        local items = {
            ["1796"] = 0,
            ["7188"] = 0
        }

        for _, item in pairs(bot:getInventory():getItems()) do
            if item.id == 1796 then
                items["1796"] = items["1796"] + item.count
            elseif item.id == 7188 then
                items["7188"] = items["7188"] + item.count
            end
        end

        return items
    end

    -- Evenly distributes count_locks() over the worlds in the world_data array

    -- Example:

    -- items = { [1796] = 10, [7188] = 20 }

    -- worlds = {
    --     {name = "World1", id = "ID1", positions = {[1796] = 1, [7188] = 2}},
    --     {name = "World2", id = "ID2", positions = {[1796] = 3, [7188] = 4}},
    --     {name = "World3", id = "ID3", positions = {[1796] = 5, [7188] = 6}}
    -- }

    -- Example result:
    -- result = {
    --     World1 = { id = "ID1", items = { [1796] = 3, [7188] = 7 }, positions = { [1796] = 1, [7188] = 2 } },
    --     World2 = { id = "ID2", items = { [1796] = 3, [7188] = 7 }, positions = { [1796] = 3, [7188] = 4 } },
    --     World3 = { id = "ID3", items = { [1796] = 4, [7188] = 6 }, positions = { [1796] = 5, [7188] = 6 } }
    -- }

    local function distribute_locks(worlds, items)
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

    local function POST(url, data)
    	local json_payload = data
        
        local json_payload_str = json.encode(json_payload)
    
        local client = HttpClient.new()
        client:setMethod(Method.post)
        client.url = url
        client.headers = {["Content-Type"] = "application/json"}
        client.content = json_payload_str
        local result = client:request()
    end

    local start_time = os.time()
    local said_hello = false
    local wait_count = 0

    bot.auto_collect = true
    bot.collect_range = 10

    local last_collect = {
        [1796] = 0,
        [7188] = 0
    }

    local collected_string

    while os.time() <= start_time + offset do
        local collected = count_locks()

        if (collected[1796] ~= 0 or collected[7188] ~= 0) and (collected[1796] ~= last_collect[1796] or collected[7188] ~= last_collect[7188]) then
            last_collect[1796] = collected[1796]
            last_collect[7188] = collected[7188]
            collected_string = ""

            if collected[7188] > 0 then
                collected_string = collected_string.." "..collected[7188].." Blue Gem Locks"
            end

            if collected[1796] > 0 and collected[7188] > 0 then
                collected_string = collected_string.." and"
            end

            if collected[1796] > 0 then
                collected_string = collected_string.." "..collected[1796].." Diamond Locks"
            end

            bot:say("Total deposit: "..collected_string..". 10 seconds to drop more.")
            start_time = os.time()
            offset = 10
            sleep(250)
        else
            sleep(250)
        end
    end

    bot.auto_collect = false
    local collected = count_locks()
    local END_COLLECTED = collected

    if collected[1796] == 0 and collected[7188] == 0 then
        response:setContent(json.encode({error_code = "NO_ITEMS_DROPPED", error = "Bot account "..bot.name.." collected no dropped items!"}), 'application/json')
        response.status = 404
        return
    end

    local items = count_locks_string()
    local distributed = distribute_locks(world_data, items)
    local status = false

    while not status do
        local count = 0
        for world_name, data in pairs(distributed) do

            local join_count = 0
            local skip_world = false

            while bot:getWorld().name:lower() ~= world_name:lower() do
                if join_count >= 5 then
                    -- response:setContent(json.encode({error_code = "DISTRIBUTE_ITEMS_WORLD_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to join world "..output_world.." while distributing."}), 'application/json')
                    -- response.status = 404

                    POST('http://73.247.130.199:3730/distribute', {error_code = "DISTRIBUTE_ITEMS_WORLD_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to join world "..world_name.." while distributing. Skipped world."})
                    -- print('DISTRIBUTE_ITEMS_WORLD_JOIN_FAILED', "Bot account "..bot.name.." failed to join world "..world_name.." while distributing.")
                    skip_world = true
                    break
                else
                    bot:warp(world_name, data.id)
                    sleep(8000)
                    join_count = join_count + 1
                end
            end

            if skip_world then
                items = count_locks_string()
                new_world_data = {}

                for _, world in pairs(world_data) do
                    if world.name ~= world_name then
                        table.insert(new_world_data, world)
                    end
                end

                if #new_world_data == 0 then
                    response:setContent(json.encode({error_code = "COMPLETE_DISTRIBUTION_ERROR", error = "Ran out of worlds to deposit to! Bot name "..bot.name.." has logged off with dropped items. CHECK ASAP <@"..owner_id..">!"}), 'application/json')
                    response.status = 404
                    bot:disconnect()
                    bot.auto_reconnect = false
                    return
                end

                world_data = new_world_data

                distributed = distribute_locks(world_data, items)
                break
            end

            for item_id, quantity in pairs(data.items) do
                if quantity > 0 then
                    drop_tile = data.positions[item_id]
                    print(drop_tile)

                    for key, value in pairs(data.positions) do
                        print(key, type(key), value, type(value))
                    end

                    local found = false

                    for _, tile in pairs(bot:getWorld():getTiles()) do
                        if tile.bg == drop_tile then
                            for x = -1, 1, 2 do

                                if #bot:getPath(tile.x+x, tile.y) > 0 then
                                    found = true
                                    bot:findPath(tile.x+x, tile.y)
                                    sleep(1000)
                                
                                    if x == -1 then
                                        bot:setDirection(false)
                                    elseif x == 1 then
                                        bot:setDirection(true)
                                    end
                                    break
                                end

                            end

                            if found then
                                break
                            end
                        end
                    end

                    if not found then
                        POST('http://73.247.130.199:3730/distribute', {error_code = "DISTRIBUTE_ITEMS_WORLD_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to get drop position for "..getInfo(tonumber(item_id)).name.." in "..world_name.." while distributing. Skipped world."})
                        -- print('DISTRIBUTE_ITEMS_DROP_POSITION_FAILED', "Bot account "..bot.name.." failed to get drop position for "..getInfo(tonumber(item_id)).name.." in "..world_name.." while distributing.")
                        skip_world = true
                        sleep(5000)
                        break
                    end

                    local before = bot:getInventory():getItemCount(tonumber(item_id))
                    local attempts = 0

                    while bot:getInventory():getItemCount(tonumber(item_id)) == before do
                        if attempts >= 5 then
                            POST('http://73.247.130.199:3730/distribute', {error_code = "DISTRIBUTE_ITEMS_DROP_FAILED", error = "Bot account "..account_details.username.." failed drop "..getInfo(tonumber(item_id)).name.." in "..world_name.." while distributing. Skipped world."})
                            -- print("DISTRIBUTE_ITEMS_DROP_FAILED", "Bot account "..bot.name.." failed drop "..getInfo(tonumber(item_id)).name.." in "..world_name.." while distributing.")
                            skip_world = true
                            break
                        else
                            bot:drop(tonumber(item_id), quantity)
                            sleep(500)
                        end
                    end
                end
            end

            if skip_world then
                items = count_locks_string()
                new_world_data = {}
    
                for _, world in pairs(world_data) do
                    if world.name ~= world_name then
                        table.insert(new_world_data, world)
                    end
                end

                if #new_world_data == 0 then
                    response:setContent(json.encode({error_code = "COMPLETE_DISTRIBUTION_ERROR", error = "Ran out of worlds to deposit to! Bot name "..bot.name.." has logged off with dropped items. CHECK ASAP <@"..owner_id..">!"}), 'application/json')
                    response.status = 404
                    bot:disconnect()
                    bot.auto_reconnect = false
                    return
                end
    
                world_data = new_world_data
    
                distributed = distribute_locks(world_data, items)
                break
            end
        end

        if bot:getInventory():getItemCount(1796) == 0 and bot:getInventory():getItemCount(7188) == 0 then
            status = true
            break
        end
    end

    POST('http://73.247.130.199:3730/distribute', {content = "Successfully distributed "..collected_string.." across "..#distributed.." worlds!"})
    -- print("Successfully distributed "..collected_string.." across "..#distributed.." worlds!")

    runThread(function(bot_name)
        local function generateRandomWorld(length)
            local characters
            
            if include_numbers then
                characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            else
                characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            end
            
            local randomWorld = ""
            
            for i = 1, length do
                local randomIndex = math.random(1, #characters)
                randomWorld = randomWorld .. string.sub(characters, randomIndex, randomIndex)
            end
            
            return randomWorld
        end

        local bot = getBot(bot_name)
        if bot then
            for i = 1, 10 do
                bot:warp(generateRandomWorld(14))
                sleep(5000)
            end
        end
    end, bot.name)

    response:setContent(json.encode({content = "Successfully distributed "..collected_string.." to "..#distributed.." worlds!", time = os.time(), collected = END_COLLECTED}), 'application/json')
    response.status = 200
    return
end)

server:post("/sync", function(request, response)
    local json = require('json')
	authorization = "REDACTED"

    params = json.decode(request.body)

	local client_authorization = params.authorization

	if client_authorization ~= authorization then
		response.status = 403
		response:setContent("Access Denied")
		return
	end
    
    local account_details = params.account_details
    local world_data = params.world_data

    local function POST(url, data)
    	local json_payload = data
        
        local json_payload_str = json.encode(json_payload)
    
        local client = HttpClient.new()
        client:setMethod(Method.post)
        client.url = url
        client.headers = {["Content-Type"] = "application/json"}
        client.content = json_payload_str
        local result = client:request()
    end

    local bot

    for key, value in pairs(account_details) do
        print(key, value)
    end

    if account_details.type == "UBICONNECT" then
        if not getBot(account_details.username) then
            addUbiBot(account_details.username, account_details.password, account_details.secret)
            local bots = getBots()
            bot = bots[#bots]
        else
            bot = getBot(account_details.username)
        end
    elseif account_details.type == "LEGACY" then
        if not getBot(account_details.username) then
            addBot(account_details.username, account_details.password)
            local bots = getBots()
            bot = bots[#bots]
        else
            bot = getBot(account_details.username)
        end
    end

    local function count_locks()
        local items = {
            [1796] = 0,
            [7188] = 0
        }

        for _, item in pairs(bot:getInventory():getItems()) do
            if item.id == 1796 then
                items[1796] = items[1796] + item.count
            elseif item.id == 7188 then
                items[7188] = items[7188] + item.count
            end
        end

        return items
    end

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

    local function count_dropped_locks_string()
        local items = {
            ["1796"] = 0,
            ["7188"] = 0
        }

        for _, object in pairs(bot:getWorld():getObjects()) do
            if object.id == 1796 then
                items["1796"] = items["1796"] + object.count
            elseif object.id == 7188 then
                items["7188"] = items["7188"] + object.count
            end
        end

        return items
    end

    local function find_tile(id)
        for _, tile in pairs(bot:getWorld():getTiles()) do
            if tile.fg == id or tile.bg == id then
                return tile
            end
        end

        return false
    end

    local retry_count = 0
    local login_fail_count = 0

    while bot.status ~= BotStatus.online do
        if retry_count >= 5 or login_fail_count >= 8 then
            response:setContent(json.encode({error_code = "ERROR_CONNECTING", error = "Failed to log on to bot account "..account_details.username..". Proxy "..bot:getProxy().ip.." might be shadowbanned.", username = account_details.username}), 'application/json')
            response.status = 404
            return
        elseif bot.status == BotStatus.account_banned then
            response:setContent(json.encode({error_code = "BAN", error = "Bot account "..account_details.username.." has been suspended.", username = account_details.username}), 'application/json')
            response.status = 404
            return
        elseif bot.status == BotStatus.logon_fail then
            bot:connect()
            sleep(5000)
            login_fail_count = login_fail_count + 1
        elseif bot.status == BotStatus.offline and bot:getPing() == 0 then
            sleep(1500)
            if bot.status == BotStatus.offline and bot:getPing() == 0 then
                bot:connect()
                sleep(8000)
                retry_count = retry_count + 1
            end
        else
            sleep(1000)
        end
    end

    local join_count = 0

    local total_locks = {
        ["1796"] = 0,
        ["7188"] = 0
    }

    for _, world in pairs(world_data) do
        for key, value in pairs(world) do
            print(key, value)
        end

        local join_count = 0

        while bot:getWorld().name:lower() ~= world.name:lower() do
            if join_count >= 5 then
                response:setContent(json.encode({error_code = "SYNC_WORLD_JOIN_FAILED", error = "Bot account "..account_details.username.." failed to check world "..world.name.." for unknown reasons."}), 'application/json')
                response.status = 404
                return
            else
                bot:warp(world.name)
                sleep(8000)
                join_count = join_count + 1
            end
        end

        local locks = count_dropped_locks_string()

        POST("http://73.247.130.199:3730/update_amount", {world = world.name, amounts = locks})
        bot:leaveWorld()
        sleep(500)
    end

    removeBot(bot.name)
    response:setContent(json.encode({content = "Successfully synced worlds to database", collected = total_collected}), 'application/json')
    response.status = 200
end)

server:listen("0.0.0.0", 5075)