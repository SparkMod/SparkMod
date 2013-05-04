--- SparkMod managed clients table.
-- Available to server plugins

local _i = 0

local clients_metatable = {
    __index = function(clients, client_index)
        if client_index then
            if client_index == "count" then
                return SparkMod.clients.count
            elseif client_index == "Count" then
                return function(obj)
                    if obj then
                        obj_type = type(obj)                
                        if not obj_type == "function" and not obj_type == "table" then
                            error("You must pass a function or a table to clients.Count()")
                        end
                        local count = 0
                        for _, client in ipairs(SparkMod.connected_clients) do
                            if obj_type == "table" then
                                local is_equal = true
                                for index, value in pairs(obj) do
                                    if data[index] ~= value then
                                        is_equal = false
                                        break
                                    end
                                end
                                if is_equal then
                                    count = count + 1
                                end
                            else
                                --TODO: detect when iterating function takes two arguments and pass (client, data) instead of only data
                                if obj(data) then
                                    count = count + 1
                                end
                            end
                        end
                        return count
                    end
                    return SparkMod.clients.count
                end
            elseif client_index == "Each" then
                return function(callback)
                    for _, client in ipairs(SparkMod.connected_clients) do
                        callback(data)
                    end
                    return SparkMod.clients.count
                end
            end

            local index_type = type(client_index)

            local client
            if index_type == "number" then
                client = SparkMod.connected_steam_ids[client_index]
                if not client then return end
            elseif index_type == "userdata" and client_index:isa("ServerClient") then
                client = client_index
            elseif index_type == "userdata" and client_index:isa("Player") then
                client = client_index:GetClient()
            else
                error("Invalid client data index \"" .. tostring(client_index) .. "\" (" .. index_type .. "), you can only get client data by client, player or steam id!")
            end

            local steam_id = client:GetUserId()

            local client_proxy_metatable = {
                __index = function(_, index)
                    return clients.data[steam_id] and clients.data[steam_id][index] or SparkMod.clients[steam_id][index]
                end,
                __newindex = function(self, index, value)
                    clients.data[steam_id] = clients.data[steam_id] or { }
                    clients.data[steam_id][index] = value
                end
            }

            return setmetatable({ }, client_proxy_metatable)
        end
    end,
    __newindex = function(self, ...)
        error "You should not be modifying the managed clients table, maybe you meant to define your own clients table first (clients = { })"
    end,
    __call = function(self)
        if #SparkMod.connected_clients < 1 then return end
        if _i > #SparkMod.connected_clients then _i = 0 end
        _i = _i + 1
        local client = SparkMod.connected_clients[_i]
        return client, self[client]
    end
}

--- The managed clients table is a magic table that can be used to store client specific data or iterate
-- over the connected clients. Client data can be indexed by ServerClient, Player or numeric steam id. Client
-- data stored in this table is specific to the plugin and is removed automatically when the client disconnects.
-- @usage -- Loop through all clients and their data:
-- for client, info in clients do
--     Puts("%N voted for map: %s", client, info.voted_for_map)
-- end
-- -- Set an attribute for a specific client
-- clients[client].voted_for_map = "ns2_tram"
-- -- Count how many clients voted for map "ns2_tram"
-- clients.Count { voted_for_map = "ns2_tram" }
-- -- Counting can also be done using a function if more flexibility is needed
-- clients.Count(function(info) return info.voted_for_map == "ns2_tram" end)
-- -- Clear an attribute for all clients
-- clients.Each(function(info) info.voted_for_map = nil end)
-- -- Count all connected clients
-- clients.count
clients = setmetatable({ data = { } }, clients_metatable)