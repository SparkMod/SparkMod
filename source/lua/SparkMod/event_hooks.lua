-- SparkMod event hooks

local update_server_interval = 0.1
local since_last_update_server = 0

local function OnUpdateServer(delta_time)
    since_last_update_server = since_last_update_server + delta_time

    if SparkMod.scheduled_for_next_tick and #SparkMod.scheduled_for_next_tick > 0 then
        local sheduled_calls = SparkMod.scheduled_for_next_tick
        SparkMod.scheduled_for_next_tick = nil
        for _, scheduled in ipairs(sheduled_calls) do
            local succeeded, err = SparkMod.Call(scheduled.callback, unpack(scheduled.args))

            if not succeeded and err.type ~= "return" then
                Puts("Error: %s", err.message)
                Puts(err.traceback)
            end
        end
    end

    if since_last_update_server > update_server_interval then
        Scheduler.Update()

        SparkMod.On("UpdateServer", delta_time)
        
        since_last_update_server = since_last_update_server - update_server_interval
    end
end

Event.Hook("UpdateServer", OnUpdateServer)

local function OnMapPreLoad()
    SparkMod.is_map_loading = true
    SparkMod.On("MapPreLoad")
end

Event.Hook("MapPreLoad", OnMapPreLoad)

local function OnMapPostLoad()
    SparkMod.is_map_loading = false
    SparkMod.is_map_loaded = true
    SparkMod.current_map = Shared.GetMapName()
    SparkMod.On("MapStart")
end

Event.Hook("MapPostLoad", OnMapPostLoad)

SparkMod.connected_clients = { }
SparkMod.connected_steam_ids = { }
SparkMod.client_connected_at = { }

local function OnClientConnect(client)
    if not client then return end

    table.insert(SparkMod.connected_clients, client)

    local steam_id = client:GetUserId()

    SparkMod.connected_steam_ids[steam_id] = client
    SparkMod.client_connected_at[steam_id] = Shared.GetSystemTime()

    SparkMod.On("ClientConnect", client)
end

Event.Hook("ClientConnect", OnClientConnect)

local function OnClientDisconnect(client)
    if not client then return end

    for i, connected_client in ipairs(SparkMod.connected_clients) do
        if connected_client == client then
            table.remove(SparkMod.connected_clients, i)
            break
        end
    end

    local steam_id = client:GetUserId()

    if SparkMod.connected_steam_ids[steam_id] then
        SparkMod.On("ClientDisconnect", client)
        
        SparkMod.connected_steam_ids[steam_id] = nil
        SparkMod.client_connected_at[steam_id] = nil

        SparkMod.Schedule(function()
            SparkMod.On("ClientDisconnected", client)
            SparkMod.On("ClientDisconnect_Post", client)
        end)
    end 
end

Event.Hook("ClientDisconnect", OnClientDisconnect)