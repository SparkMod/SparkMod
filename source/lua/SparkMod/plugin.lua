-- SparkMod plugin manager

local base_components = { "base", "scheduler" }

if Server then
    base_components = { "base", "clients", "scheduler", "helpers" }
end

for i, name in ipairs(base_components) do
    local load_function, err = loadfile(("lua/SparkMod/plugin_%s.lua"):format(name))
    if not load_function then
        Puts("[Fatal error] Failed to load SparkMod/plugin_%s.lua: %s", name, err)
        return false
    end
    base_components[i] = load_function
end

Plugin = {
    plugins = { },
    is_unloading = { },
    dependencies = { },
    waiting_for_dependencies = { },
    plugin_errors = { },
    initialized = { },
    enabled = { },
    hooked_functions = { },
    network_message_hooked = { },
    client_commands = { },
    admin_commands = { },
    registered_forwards = { },
    stored_data = { }
}

setmetatable(Plugin, {
    __index = function(_, index)
        return Plugin.plugins[index]
    end
})

Plugin.base = {
    forwards = { },
    hooked_function_callbacks = { },
    network_message_value_callbacks = { },
    network_message_hooks = { },
    client_commands = { },
    admin_commands = { },
    command_aliases = { },
    command_descriptions = { },
    error_count = 0
}

Plugin.proxy_attributes = {
    gamerules = function() return SparkMod.gamerules end,
    game_state = function() return SparkMod.gamerules and SparkMod.gamerules.gameState end,
    previous_game_state = function() return SparkMod.previous_game_state end,
    time_since_game_state_changed = function() return SparkMod.gamerules and SparkMod.gamerules.timeSinceGameStateChanged end,
    current_map = function() return SparkMod.current_map end
}

function Plugin.LoadBase(plugin)
    for _, load_function in ipairs(base_components) do
        setfenv(load_function, plugin)
        load_function()
    end
end

function Plugin.BuildEnv(plugin_name)
    local plugin_env = table.dup(Plugin.base)    
    
    plugin_env.plugin_name = plugin_name

    return plugin_env
end

function Plugin.Build(plugin_name)
    local plugin_env = Plugin.BuildEnv(plugin_name)

    local plugin_metatable = {
        __index = function(self, name)
            return Plugin.proxy_attributes[name] and Plugin.proxy_attributes[name]() or _G[name]
        end,
        __newindex = function(self, ...)
            return self.__newindex and self.__newindex(self, ...) or rawset(self, ...) 
        end
    }

    local plugin = setmetatable(plugin_env, plugin_metatable)

    Plugin.LoadBase(plugin)

    return plugin
end

function Plugin.InitializeForwards(plugin)
    for name, value in pairs(plugin) do        
        if type(value) == "function" and name:starts("On") then
            
            if name:starts("OnCommand") or name:starts("OnClientCommand") then
                
                local command_name = name:match("Command([^%(]+)"):underscore()
                plugin.RegisterClientCommand(command_name, value)

            elseif name:starts("OnAdminCommand") then

                local command_name = name:sub(15):underscore()
                plugin.RegisterAdminCommand(command_name, value)

            else

                local event_name = name:sub(3)
                plugin.RegisterForward(event_name, value)

            end

        end
    end
end

function Plugin.Initialize(plugin)
    if plugin.library_name then
        if _G[plugin.library_name] then
            local error_message = "Plugin library name unavailable: " .. plugin.library_name
            plugin.Puts("Error while loading: %s", error_message)
            Plugin.plugin_errors[plugin.plugin_name] = error_message
            Plugin.On("Error", error_message, plugin.plugin_name, "Initialize")
            return false
        end
        
        plugin._library_name = plugin.library_name

        _G[plugin.library_name] = plugin

        plugin.Puts("Plugin library name: %s", plugin.library_name)
    end

    Plugin.initialized[plugin.plugin_name] = true
    plugin.is_plugin_initialized = true

    if SparkMod.config.debug_plugin_loading then
        Puts("Plugin initialized: %s", plugin.plugin_name)
    end

    if plugin.OnLoaded or plugin.OnPluginStart then
        local succeeded, err = plugin.FireEvent("Loaded")
        if succeeded then
            succeeded, err = plugin.FireEvent("PluginStart")
        end
        if not succeeded then
            plugin.Puts("Error while loading: %s", err.message)
            plugin.Puts(err.traceback)
            Plugin.plugin_errors[plugin.plugin_name] = err.message
            Plugin.On("Error", err, plugin.plugin_name, "OnLoaded")
            Plugin.Unload(plugin.plugin_name, true)
            return false
        end
    end

    if plugin.OnAllPluginsLoaded then
        plugin.CatchErrors(plugin.OnAllPluginsLoaded)
    end

    if plugin.OnMapLoad and SparkMod.is_map_loaded then
        plugin.CatchErrors(plugin.OnMapLoad)
    end

    Plugin.On("PluginAdded", plugin.plugin_name)

    return true
end

function Plugin.IsSingleFile(plugin_name)
    local plugin_pattern = "^" .. plugin_name .. "[/%.]"
    return SparkMod.Any(SparkMod.FindMatchingFiles("lua/SparkMod/plugins/*"), function(_, path)
        local plugin_subpath = path:sub(22)
        if plugin_subpath:match(plugin_pattern) then
            return plugin_subpath:ends(".lua")
        end
    end)
end

function Plugin.IsSharedFile(file_path)
    return file_path:ends("shared.lua")
end

function Plugin.ShouldFileBeLoaded(path)
    if path:match "/shared%.lua$" then
        return true
    end

    local is_client_file = path:match "/client%.lua$"
    if not is_client_file then
        is_client_file = path:match "/plugins/client/"
    end

    if Client then
        return is_client_file
    else -- Server
        return not is_client_file
    end    

    return false
end

function Plugin.IsDisabled(plugin_name)
    return SparkMod.config and SparkMod.config.disabled_plugins and table.contains(SparkMod.config.disabled_plugins, plugin_name)
end

function Plugin.OnDefaultConfig(plugin, file_path, default_config)
    if Plugin.IsSharedFile(file_path) then
        plugin.shared_default_config = plugin.shared_default_config or { }
        table.merge(plugin.shared_default_config, default_config)
    end
end

function Plugin.LoadWithDependencies(plugin, was_requested, config_plugin_paths)
    local plugin_name = plugin.plugin_name

    local load_paths = { }
    local load_functions = { }
    local load_plugin, err
    local config_plugin_paths = config_plugin_paths or SparkMod.FindMatchingFiles("config://sparkmod/plugins/*")

    plugin._plugin_base_path = "lua/SparkMod/plugins"

    if Plugin.IsSingleFile(plugin_name) then
        local file_path = ("%s/%s.lua"):format(plugin._plugin_base_path, plugin_name)

        if SparkMod.Any(config_plugin_paths, function(_, path) return path:ends("/%s.lua", plugin_name) end) then
            -- This plugin exists in config://sparkmod/plugins/ which gets priority over other plugin locations
            if SparkMod.FileExists(file_path) then
                Puts("[SM] Warning: Plugin \"%s.lua\" exists in multiple locations. Plugin will be loaded from sparkmod/plugins in your server config directory.", plugin_name)
            end
            
            plugin._plugin_base_path = "config://sparkmod/plugins"
            file_path = ("%s/%s.lua"):format(plugin._plugin_base_path, plugin_name)
        end

        load_plugin, err = loadfile(file_path)
        table.insert(load_paths, file_path)
        table.insert(load_functions, load_plugin)
    else
        plugin._plugin_base_path = "lua/SparkMod/plugins/" .. plugin_name

        local lua_files = SparkMod.FindMatchingFiles("%s/**/*.lua", plugin._plugin_base_path)

        if SparkMod.Any(config_plugin_paths, function(_, path) return path:starts("sparkmod/plugins/%s/", plugin_name) end) then
            -- This plugin exists in config://sparkmod/plugins/ which gets priority over other plugin locations
            if #lua_files > 0 then
                Puts("[SM] Warning: Plugin \"%s.lua\" exists in multiple locations. Plugin will be loaded from sparkmod/plugins in your server config directory.", plugin_name)
            end
            
            plugin._plugin_base_path = "config://sparkmod/plugins/" .. plugin_name
            lua_files = SparkMod.FindMatchingFiles("%s/**/*.lua", plugin._plugin_base_path)
        end

        for _, file_path in ipairs(lua_files) do
            if Plugin.ShouldFileBeLoaded(file_path) then
                if SparkMod.config.debug_plugin_loading then
                    Puts("[DEBUG] Loading plugin file: %s", file_path)
                end
                load_plugin, err = loadfile(file_path)
                if load_plugin then
                    if file_path:ends("shared.lua") then
                        table.insert(load_paths, 1, file_path)
                        table.insert(load_functions, 1, load_plugin)
                    else
                        table.insert(load_paths, file_path)
                        table.insert(load_functions, load_plugin)
                    end
                    Plugin.ParseMetadata(plugin_name, file_path)
                else
                    break
                end
            elseif SparkMod.config.debug_plugin_loading then
                Puts("[DEBUG] Ignoring plugin file: %s", file_path)
            end
        end
    end

    if not load_plugin then
        err = err or "Unable to find plugin files for plugin: " .. plugin_name

        Puts("[SM] %s failed to load: %s", plugin_name, err)

        -- Do not log error if load was requested by command and plugin does not exist
        if not was_requested or not err:ends "No such file or directory" then
            Plugin.plugin_errors[plugin_name] = err
            Plugin.On("Error", err, plugin_name, "Load")
        end

        return false
    end

    for i, load_file in ipairs(load_functions) do
        setfenv(load_file, plugin)

        local file_path = load_paths[i]
        
        local co = coroutine.create(function()
            currently_loading_plugin_file = file_path
            load_file()
        end)

        while true do
            local succeeded, err = CoXpCall(co)

            if not succeeded then
                Puts("[SM] Plugin \"%s\" failed to load: %s", plugin_name, err.message)
                Puts(err.traceback)
                Plugin.plugin_errors[plugin_name] = err.message
                Plugin.On("Error", err, plugin_name, "Load")
                return false
            end

            if err and err.type == "need_dependency" then
                if Plugin.plugin_errors[err.name] then
                    local unloadable_message = ("Dependent plugin \"%s\" is unloadable"):format(err.name)
                    Puts("[SM] %s failed to load: %s", plugin_name, unloadable_message)
                    Plugin.plugin_errors[plugin_name] = unloadable_message
                    return false
                else
                    if SparkMod.config.debug_plugin_loading then
                        Puts("[DEBUG] Attempting to load %s dependency: %s", plugin_name, err.name)
                    end
                    if Plugin.Load(err.name) then
                        if SparkMod.config.debug_plugin_loading then
                            Puts("[DEBUG] %s was loaded successfully, continuing to load: %s", err.name, plugin_name)
                        end
                    else
                        local unloadable_message = ("Dependent plugin \"%s\" is unloadable"):format(err.name)
                        Puts("[SM] %s failed to load: %s", plugin_name, unloadable_message)
                        Plugin.plugin_errors[plugin_name] = unloadable_message
                        return false
                    end
                end
            else
                break
            end
        end

        Plugin.InitializeForwards(plugin)
    end

    return true
end

function Plugin.Load(plugin_name, was_requested, config_plugin_paths)
    local plugin = Plugin.Build(plugin_name)

    Plugin.plugin_errors[plugin_name] = nil
    Plugin.plugins[plugin_name] = plugin
    
    if Plugin.enabled[plugin_name] ~= nil then
        -- Restore enabled state if another plugin has changed the value
        plugin.enabled = Plugin.enabled[plugin_name]
    end

    plugin.info = plugin.info or plugin.myinfo or { name = plugin.plugin_name .. ".lua" }
    plugin.myinfo = plugin.info

    -- Attempt to load plugin and all dependencies
    if not Plugin.LoadWithDependencies(plugin, was_requested, config_plugin_paths) then
        Plugin.plugins[plugin_name] = nil

        return false
    end

    if Server then
        SparkMod.LoadPluginConfig(plugin)
        
        if plugin.shared_default_config then
            for key, default_value in pairs(plugin.shared_default_config) do
                SparkMod.SetClientConfigAll(plugin_name, key, plugin.config[key])
            end
        end
    end

    -- Initialize plugins which were waiting for this plugin to load
    for pl_name, waiting_for in pairs(Plugin.waiting_for_dependencies) do
        if waiting_for[plugin_name] then
            if SparkMod.config.debug_plugin_loading then
                Puts("[DEBUG] Plugin \"%s\" is no longer waiting on dependency: %s", pl_name, plugin_name)
            end
            waiting_for[plugin_name] = nil
            if #waiting_for == 0 and not Plugin.initialized[pl_name] then
                if Plugin.IsLoaded(pl_name) then
                    if SparkMod.config.debug_plugin_loading then
                        Puts("[DEBUG] Plugin \"%s\" can now be initialized", pl_name)
                    end
                    Plugin.Initialize(Plugin.plugins[pl_name])
                else
                    if SparkMod.config.debug_plugin_loading then
                        Puts("[DEBUG] Plugin \"%s\" can now be loaded", pl_name)
                    end
                    Plugin.Load(pl_name)
                end
            end
        end
    end

    -- Don't initialize this plugin yet if it is still waiting on dependencies
    if Plugin.waiting_for_dependencies[plugin_name] then
        for dependency_name, required in pairs(Plugin.waiting_for_dependencies[plugin_name]) do
            if SparkMod.config.debug_plugin_loading then
                Puts("[DEBUG] Can't complete loading of plugin \"%s\" until dependency is loaded: %s", plugin_name, dependency_name)
            end
            return true
        end
        Plugin.waiting_for_dependencies[plugin_name] = nil
    end

    return Plugin.Initialize(plugin)
end

function Plugin.Unload(plugin_name, skip_unload_forwards)
    local plugin = Plugin.plugins[plugin_name]
    if not plugin then return false end

    Plugin.is_unloading[plugin_name] = true

    for pl_name, dependencies in pairs(Plugin.dependencies) do
        if Plugin.IsLoaded(pl_name) and table.contains(dependencies, plugin_name) then
            if not Plugin.is_unloading[pl_name] then
                if SparkMod.config.debug_plugin_loading then
                    Puts("[DEBUG] Plugin \"%s\" is dependent on: %s (unloading)", pl_name, plugin_name)
                end
                Plugin.waiting_for_dependencies[pl_name] = Plugin.waiting_for_dependencies[pl_name] or { }
                Plugin.waiting_for_dependencies[pl_name][plugin_name] = true
                Plugin.Unload(pl_name)
            end
        end
    end
    
    if plugin.scheduler then
        plugin.scheduler.UnscheduleAll()
    end
    
    if not skip_unload_forwards then
        if plugin.OnUnloaded then
            local succeeded, err = SparkMod.Call(plugin.OnUnloaded)
            if not succeeded then
                plugin.Puts("Error while unloading: %s", err.message)
                plugin.Puts(err.traceback)
                Plugin.On("Error", err, plugin_name, "OnUnloaded")
            end
        end

        if plugin.OnPluginEnd then
            local succeeded, err = SparkMod.Call(plugin.OnPluginEnd)
            if not succeeded then
                plugin.Puts("Error while unloading: %s", err.message)
                plugin.Puts(err.traceback)
                Plugin.On("Error", err, plugin_name, "OnPluginEnd")
            end
        end
    end

    if plugin._library_name then
        _G[plugin._library_name] = nil
    end
    
    Plugin.plugins[plugin_name] = nil
    Plugin.initialized[plugin_name] = nil
    Plugin.is_unloading[plugin_name] = nil

    Plugin.On("PluginRemoved", plugin_name)
    
    return true
end

function Plugin.Reload(plugin_name)
    Plugin.Unload(plugin_name)
    return Plugin.Load(plugin_name)
end

function Plugin.LoadAll()
    SparkMod.are_plugins_loaded = false

    local config_plugin_paths = SparkMod.FindMatchingFiles("config://sparkmod/plugins/*")    
    local plugin_paths = table.imerged(SparkMod.FindMatchingFiles("lua/SparkMod/plugins/*"), config_plugin_paths)

    local loaded = 0
    for _, plugin_path in ipairs(plugin_paths) do
        local should_load_plugin = false
        local plugin_name

        if plugin_path:match "/$" then
            -- Plugin is a directory
            plugin_name = plugin_path:match "/([^/]+)/$"
            local lua_files = SparkMod.FindMatchingFiles(plugin_path .. "**/*.lua")
            should_load_plugin = SparkMod.AnyValue(lua_files, Plugin.ShouldFileBeLoaded)
        else
            -- Plugin is a single file
            plugin_name = plugin_path:match "/([^/]+).lua$"
            should_load_plugin = not Client
        end

        if should_load_plugin and not Plugin.IsDisabled(plugin_name) then
            if Plugin.Load(plugin_name, false, config_plugin_paths) then
                loaded = loaded + 1
            else
                Puts("[SM] Plugin failed to load: %s", plugin_name)
            end
        end
    end
    if loaded > 0 then
        Puts("[SM] %s %s successfully loaded", loaded, loaded > 1 and "plugins" or "plugin")

        if not SparkMod.are_plugins_loaded then
            Plugin.On("AllPluginsLoaded")
            SparkMod.are_plugins_loaded = true
        end
    end
end

function Plugin.UnloadAll()
    for plugin_name, plugin in pairs(Plugin.plugins) do
        if plugin then Plugin.Unload(plugin_name) end
    end
end

function Plugin.List()
    local plugin_names = { }

    for plugin_name, _ in pairs(Plugin.plugins) do
        table.insert(plugin_names, plugin_name)
    end

    for plugin_name, _ in pairs(Plugin.plugin_errors) do
        if not table.contains(plugin_names, plugin_name) then
            table.insert(plugin_names, plugin_name)
        end
    end

    return plugin_names
end

function Plugin.IsLoaded(plugin_name)
    return Plugin.plugins[plugin_name] and true or false
end

function Plugin.ParseMetadata(plugin, plugin_path)
    local contents
    local file = io.open(plugin_path, "r")

    if file then
        contents = file:read("*all")
        file:close()
    else
        Puts("[SM] Unable to load metadata from file: %s", plugin_path)
        return false
    end

    local parsing_summary, parsing_comment

    for line in contents:gmatch("[^\n]+") do
        local summary = line:match("^%-%-%- ([^\n]+)")

        if summary then
            parsing_summary = summary
        else
            local comment = line:match("^%-%- ([^\n]+)")

            if comment then
                parsing_comment = comment
            else
                command = line:match("^function On(%u%l+)?Command([^%(]+)")

                if command then
                    plugin.command_descriptions[command] = parsing_summary or parsing_comment
                end

                parsing_summary = nil
                parsing_comment = nil
            end
        end
    end

    return true
end

function Plugin.SetEnabled(plugin_name, enabled)
    Plugin.enabled[plugin_name] = enabled
    if Plugin.plugins[plugin_name] then
        Plugin.plugins[plugin_name].enabled = enabled
    end
end

function Plugin.Enable(plugin_name)
    Plugin.SetEnabled(plugin_name, true)
end

function Plugin.Disable(plugin_name)
    Plugin.SetEnabled(plugin_name, false)
end

-- Internal: Fires an event forward in all plugins and returns a packed result
function Plugin._On(event_name, ...)    
    local client
    if event_name == "ChatMessage" then
        client = select(1, ...)
    end
    
    callback_name = "On" .. event_name

    if Plugin[callback_name] then
        Plugin[callback_name](...)
    end

    local args
    for plugin_name, plugin in pairs(Plugin.plugins) do
        if plugin.forwards[event_name] then
            for _, callback in ipairs(plugin.forwards[event_name]) do                
                args = args or {...}

                if client then
                    plugin._reply_info = { client = client, method = "PrintToChat" }
                end

                local succeeded, ret = CoXpCall(function()
                    if client then
                        _reply_info = { client = client, method = "PrintToChat" }
                    end
                    return PackAllValues(callback(unpack(args)))
                end)

                if client then
                    plugin._reply_info = nil
                end

                if not succeeded and ret.type ~= "return" then
                    plugin.Puts("Error: %s", ret.message)
                    plugin.Puts(ret.traceback)
                    plugin.error_count = plugin.error_count + 1
                    if plugin.error_count >= SparkMod.config.unload_plugin_error_limit then
                        Plugin.On("Error", ret, plugin_name, event_name, true)
                        Puts("Unloading plugin due to error limit: %s (%d errors)", ret.message, plugin.error_count)
                        Plugin.Unload(plugin_name)
                    else
                        Plugin.On("Error", ret, plugin_name, event_name)
                    end
                elseif succeeded and ret.count > 0 then
                    return ret
                end
            end
        end
    end
end

-- Fires an event forward in all plugins and returns any values returned from a forward
function Plugin.On(event_name, ...)
    local values = Plugin._On(event_name, ...)
    if values then
        return UnpackAllValues(values)
    end
end

-- Hooks an engine event and fires a forward for each plugin
function Plugin.HookEvent(event_name)
	Event.Hook(event_name, function(...) Plugin.On(event_name, ...) end)
end

function Plugin.HookNetworkMessage(message_name)
    if Plugin.network_message_hooked[message_name] then
        return false
    end

    SparkMod.HookNetworkMessage(message_name, function(message)
        for plugin_name, plugin in pairs(Plugin.plugins) do
            if plugin.network_message_hooks[message_name] then
                for _, callback in ipairs(network_message_hooks[message_name]) do
                    local suceeeded, err = SparkMod.Call(callback, message)
                    if not suceeeded then
                        plugin.Puts("Error while handling %s network message: %s", message_name, err.message)
                        Puts(err.traceback)
                        Plugin.On("Error", err, plugin.plugin_name, "NetworkMessage")
                    end
                end
            end
        end
    end)

    Plugin.network_message_hooked[message_name] = true
    
    return true
end

function Plugin.FireFunctionHooks(hook_type, method_name, ...)
    for plugin_name, plugin in pairs(Plugin.plugins) do
        if plugin.hooked_function_callbacks[method_name] then
            local values = plugin.FireFunctionHooks(hook_type, method_name, ...)
            if values and values.count > 0 then
                return UnpackAllValues(values)
            end
        end
    end
end

if Server then
    Script.Load("lua/SparkMod/server/plugin.lua")
end