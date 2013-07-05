-- SparkMod core commands

local sender

local function SendReply(...)
    SendToAdmin(sender, ...)
end

local function SendError(...)
    SendToAdmin(sender, ...)
    error({ type = "return" })
end

-- Plugin commands
function SparkMod.Command_Plugins(command, ...)
    if client and not SparkMod.CanClientRunCommand(client, "sm_rcon") then
        return SparkMod.Command_Plugins_List()
    end

    local callback = command and SparkMod["Command_Plugins_" .. command:camelize()]

    if command and callback then
        callback(...)
    else
        if command then Puts("Unknown command: %s", command:camelize()) end
        SendReply("SparkMod Plugins Menu:")
        SendReply("    info               - Information about a plugin")
        SendReply("    list                - Show loaded plugins")
        SendReply("    load              - Load a plugin")
        SendReply("    refresh          - Reloads/refreshes all plugins in the plugins folder")
        SendReply("    reload           - Reloads a plugin")
        SendReply("    unload          - Unload a plugin")
        SendReply("    unload_all     - Unloads all plugins")
    end
end

function SparkMod.Command_Plugins_Info(plugin_name)
    local plugin
    
    if plugin_name then
        local plugin_names = Plugin.List()
        local plugin_number = tonumber(plugin_name)
        if plugin_number then
            local plugin_count = #plugin_names
            if plugin_number > plugin_count then
                SendError("[SM] Invalid plugin number: %d", plugin_number)
            end
            plugin_name = plugin_names[plugin_number]
        elseif not table.contains(plugin_names, plugin_name) then
            SendError("[SM] Invalid plugin name: %s", plugin_name)
        end
        plugin = Plugin.plugins[plugin_name]
    else
        SendError("[SM] Usage: sm plugins info <plugin name>")
    end

    SendReply("[SM] Plugin: %s", plugin_name)
    
    if plugin then
        if plugin.info.title then
            local format = "    Title: %s"
            if plugin.info.description then
                format = format .. " (%s)"
            end
            SendReply(format, plugin.info.title or plugin_name, plugin.info.description)
        end
        
        if plugin.info.author then
            SendReply("    Author: %s", plugin.info.author)
        end
        
        if plugin.info.version then
            SendReply("    Version: %s", plugin.info.version)
        end
        
        if plugin.info.url then
            SendReply("    URL: %s", plugin.info.url)
        end

        SendReply("    Status: Running")
    elseif Plugin.plugin_errors[plugin_name] then
        SendReply("    Load error: %s", Plugin.plugin_errors[plugin_name])        
    else
        SendReply("    Status: Unloaded")
    end
end

function SparkMod.Command_Plugins_List()
    local plugin_names = Plugin.List()
    
    SendReply("[SM] Listing %d plugins:", #plugin_names)

    for i, plugin_name in ipairs(plugin_names) do
        local plugin = Plugin.plugins[plugin_name]

        if plugin_name and plugin then
            local format = "%02d \"%s\""

            if plugin.info.version then
                format = format .. " (%s)"
            end

            if plugin.info.author then
                format = format .. " by %s"
            end

            SendReply(format, i, plugin.info.name, plugin.info.version, plugin.info.author)
        else
            local format = "%02d <failed> \"%s\""

            if Plugin.plugin_errors[plugin_name] then
                format = format .. " - Error: %s"
            end

            SendReply(format, i, plugin_name .. ".lua", Plugin.plugin_errors[plugin_name])
        end
    end
end

function SparkMod.Command_Plugins_Load(plugin_name)
    if not plugin_name then
        SendError "[SM] You need to give a plugin name that you would like to load"
    end
    
    if Plugin.Load(plugin_name) then
        SendReply("[SM] Loaded plugin successfully: %s", plugin_name)
    else
        SendReply("[SM] Plugin failed to load: %s", plugin_name)
    end
end

function SparkMod.Command_Plugins_Refresh(plugin_name)
    local plugin_names = Plugin.List()

    Plugin.UnloadAll()
    
    local loaded = 0
    
    for i = 1, #plugin_names do
        if Plugin.Load(plugin_names[i]) then
            loaded = loaded + 1
        else
            SendReply("[SM] Plugin failed to load: %s", plugin_names[i])
        end
    end

    if loaded > 0 then
        SendReply("[SM] %s %s successfully loaded", loaded, loaded > 1 and "plugins" or "plugin")
    end
end

function SparkMod.Command_Plugins_Reload(plugin_name)
    if not plugin_name then
        SendError "[SM] You need to give a plugin name that you would like to reload"
    end

    if Plugin.Reload(plugin_name) then
        SendReply("[SM] Reloaded plugin successfully: %s", plugin_name)
    else
        SendReply("[SM] Plugin failed to reload: %s", plugin_name)
    end
end

function SparkMod.Command_Plugins_Unload(plugin_name)
    if not plugin_name then
        SendError "[SM] You need to give a plugin name that you would like to unload"
    end
    
    if Plugin.Unload(plugin_name) then
        SendReply("[SM] Unloaded plugin successfully: %s", plugin_name)
    else
        SendReply("[SM] Plugin failed to unload: %s", plugin_name)
    end
end

function SparkMod.Command_Plugins_UnloadAll()
    Plugin.UnloadAll()    
    SendReply("[SM] Unloaded all plugins")
end

function SparkMod.Command_Config(config_name, command, key, ...)
    if client and not SparkMod.CanClientRunCommand(client, "sm_rcon") then
        SendError "[SM] You have insufficient access to use that command."
    end

    local plugins = table.select(Plugin.plugins, function(name, pl) return table.countkeys(pl.config) > 0 end)
    local config_names = table.keys(plugins)
    table.insert(config_names, 1, "SparkMod")

    if not config_name then
        SendReply("[SM] Usage: sm config <config_name>")
        SendError("[SM] Loaded configs: %s", table.to_sentence(config_names))
    end

    local lower_config_name = config_name:lower()
    local config, config_plugin

    if lower_config_name == "sparkmod" or lower_config_name == "sm" then
        config_name = "SparkMod"
        config = SparkMod.config
    else
        for plugin_name, plugin in pairs(plugins) do
            if plugin_name:lower() == lower_config_name then
                config_plugin = plugin
                config_name = plugin_name
                config = plugin.config
                break
            end
        end
    end

    if not config then
        SendReply("[SM] Invalid config name given: %s", config_name)
        SendError("[SM] Loaded configs: %s", table.to_sentence(config_names))
    end

    local display_name = config_plugin and (config_name .. " plugin") or config_name

    if key then
        local indexes = { }
        for index in key:gmatch "[^%.]+" do
            table.insert(indexes, index)
        end

        local first_index = indexes[1]
        local first_index_old_value = config[first_index] and table.dup(config[first_index])
        local shared_config = config_plugin and config_plugin.shared_default_config or SparkMod.shared_default_config

        local last_index
        for i, index in ipairs(indexes) do
            local config_value = config[index]
            if config_value == nil or i == 1 and index == "admin" then
                SendError("[SM] Invalid config key: %s", key)
            end
            if i < #indexes then
                if shared_config then
                    shared_config = shared_config[index]
                end
                config = config_value
            else
                last_index = index
            end
        end

        local value = SparkMod.ArgString(...)

        if value and #value > 0 then
            local succeeded
            local func, ret = loadstring("return " .. value)
            if func then succeeded, ret = pcall(func) end
            if not succeeded then
                SendReply("[SM] Error while parsing value: %s", value)
                SendError(ret)
            end

            if ret == nil and value ~= "nil" then
               SendError("[SM] Error: Value of \"%s\" is nil (hint: string values need to be surrounded with quotes)", value)
            end

            local value_was_set = config[last_index] ~= nil

            config[last_index] = ret

            if config_plugin then
                SparkMod.SavePluginConfig(config_plugin)
                config_plugin.FireEvent("ConfigValueChanged", first_index, config[first_index], first_index_old_value)
            elseif value_was_set then
                SparkMod.SaveConfig()
            end

            if shared_config and shared_config[last_index] ~= nil then
                SparkMod.SetClientConfigAll(config_plugin and config_plugin.plugin_name or "SparkMod", key, ret)
            end

            SendReply("[SM] Set %s in %s config: %s", key, display_name, Stringify(ret, -1))
        else
            local config_string = Stringify(config[last_index])
            if config_string:match("\n") or #config_string > 32 then
                SendReply("[SM] Printing out %s from %s config:", key, display_name)
                for line in config_string:gmatch("[^\n]+") do
                    SendReply(line)
                end
            else
                SendReply("[SM] Printing out %s from %s config: %s", key, display_name, config_string)
            end
        end

        return
    end

    SendReply("[SM] To set an attribute, type \"sm config %s set <key> [value]\"", config_name)
    SendReply("[SM] Printing out %s config:", display_name)

    local config_string = Stringify(table.reject(config, function(k, v) return k == "admin" end))
    for line in config_string:gmatch("[^\n]+") do
        SendReply(line)
    end
end

function SparkMod.Command_Cmds(plugin_name)
    SendReply("[SM] Command not yet implemented")
end

-- Base commands
function SparkMod.Command_Version()
    SendReply("SparkMod Version: %s", SparkMod.version)
end

local function Command_SparkMod(client, command, ...)
    sender = client

    local callback = command and SparkMod["Command_" .. command:camelize()]

    if command and callback then
        local args = {...}
        local succeeded, err = SparkMod.Call(callback, unpack(args))
        if not succeeded and err.type ~= "return" then
            Puts("Error: %s", err.message)
            Puts(err.traceback)
        end
    else
        SendReply("Usage: sm <command> [arguments]")
        SendReply("    cmds <plugin>     - List commands for plugin")
        if not client or SparkMod.CanClientRunCommand(client, "sm_rcon") then
            SendReply("    plugins                - Manage plugins")
            SendReply("    config                - Manage configs")
        else
            SendReply("    plugins                - List plugins")
        end
        SendReply("    version                - Display SparkMod version")
    end
end

Event.Hook("Console_sm", Command_SparkMod)

for key, value in pairs(SparkMod.shared_default_config) do

    local function handle_shared_config_command(client, ...)
        sender = client

        local succeeded, err = SparkMod.Call(SparkMod.Command_Config, "SparkMod", "set", key, ...)
        if not succeeded and err.type ~= "return" then
            Puts("Error: %s", err.message)
            Puts(err.traceback)
        end
    end

    Event.Hook("Console_sm_" .. key, handle_shared_config_command)

end