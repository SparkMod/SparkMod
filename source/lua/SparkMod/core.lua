-- SparkMod core

SparkMod.debug_network_messages = false

SparkMod.is_using_workshop = false

SparkMod.is_game_loaded = false

-- Called after every Script.Load call
function SparkMod.OnScriptLoaded(path, reloaded)
    if not SparkMod.is_game_loaded and path:ends("/PostLoadMod.lua") then
        SparkMod.is_game_loaded = true            
        SparkMod.OnGameLoaded()
    else
        for path_ending, callbacks in pairs(SparkMod.script_loaded_hooks) do
            if path:ends(path_ending) then
                for _, callback in ipairs(callbacks) do
                    callback(path, reloaded)
                end
            end
        end
    end
end

-- Called after game code and all other mod .entry files have been loaded
function SparkMod.OnGameLoaded()
    SparkMod.LoadCorePlugin "base_hooks"

    if Server then
        SparkMod.LoadCorePlugin "server/base_hooks"
    end

    Plugin.LoadAll()

    local count = 0
    for message_name, fields in pairs(SparkMod.network_messages) do
        Shared._RegisterNetworkMessage(message_name, table.map(fields, "type"))
        count = count + 1
    end

    Puts("[SM] Registered %d network messages", count)

    SparkMod.network_messages_registered = true

    for message_name, callbacks in pairs(SparkMod.network_message_hooks) do
        for _, callback in ipairs(callbacks) do
            if Server then
                Server._HookNetworkMessage(message_name, callback)
            elseif Client then
                Client._HookNetworkMessage(message_name, callback)
            end
        end
    end
end

-- Checks if server is running SparkMod via the workshop
function SparkMod.CheckWorkshopMods()
    local mod_names = { }

    for i = 1, Server.GetNumMods() do
        local mod_id = Server.GetModId(i)
        local name = Server.GetModTitle(i)
        mod_names[mod_id] = name
    end

    for i = 1, Server.GetNumActiveMods() do
        local mod_id = Server.GetActiveModId(i)
        if mod_names[mod_id]:starts("SparkMod") then
            SparkMod.is_using_workshop = true
            break
        end
    end
end

-- Finds files in the given path, supports glob syntax and returns a table of matching file paths
function SparkMod.FindMatchingFiles(format, ...)
    local glob = format:format(...)
    local pattern = GlobToPattern(glob)
    local recursive = not not glob:match "/****/"
    if recursive then --TODO: clean glob better so that advanced glob syntax other than /**/ does not break GetMatchingFileNames
        glob = glob:gsub("/****/", "/")
    end
    local matching_paths = { }
    Shared.GetMatchingFileNames(glob, recursive, matching_paths)
    if #matching_paths > 0 then
        for i = #matching_paths, 1 do
            if not matching_paths[i]:match(pattern) then
                table.remove(matching_paths, i)
            end
        end
    end
    return matching_paths
end

-- Checks if a specific file exists
function SparkMod.FileExists(file_path)
    local file = io.open(file_path, 'r')
    if file then
        file:close()
        return true
    end
    return false
end

-- Internal
local function PrintDebugMessages(callback_name, ...)    
    if callback_name:match("WebRequest") and not SparkMod.config.debug_web_requests then
        return
    elseif callback_name:match("NetworkMessage") and not SparkMod.config.debug_network_messages then
        return
    elseif not SparkMod.config.debug_forwards then
        return
    elseif callback_name:match("Update") or callback_name:match("Check") then
        return
    end

    Puts("[SparkMod] %s: %s", callback_name, Stringify{...})
end

-- Internal
function SparkMod._On(event_name, ...)
    if type(event_name) == "table" then
        for i = 1, #event_name do
            local result = SparkMod._On(event_name[i], ...)
            if result and result.count > 0 then
                return result
            end
        end
        return
    end

    callback_name = ("On%s"):format(event_name)

    PrintDebugMessages(callback_name, ...)

    if SparkMod[callback_name] then
        local values = PackAllValues(SparkMod[callback_name](...))
        if values and #values > 0 then
            return values
        end
    end

    return Plugin._On(event_name, ...)
end

-- Fires event forwards
function SparkMod.On(event_name, ...)
    if type(event_name) == "table" then
        local values = SparkMod._On(event_name, ...)
        if values and values.count > 0 then
            return UnpackAllValues(values)
        end
        return
    end

    callback_name = ("On%s"):format(event_name)

    PrintDebugMessages(callback_name, ...)

    if SparkMod[callback_name] then
        local values = PackAllValues(SparkMod[callback_name](...))
        if values and #values > 0 then
            return UnpackAllValues(values)
        end
    end

    return Plugin.On(event_name, ...)
end

if Server then
    SparkMod.CheckWorkshopMods()
end