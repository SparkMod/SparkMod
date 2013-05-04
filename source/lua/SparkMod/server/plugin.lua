-- SparkMod server plugin manager

-- Internal: Registers a client command
function Plugin.RegisterClientCommand(command_name)
    if Plugin.client_commands[command_name] then return false end
    
    Plugin.client_commands[command_name] = function(client, ...)
        local args, arg_string = SparkMod.ParseCommandArguments(...)
        
        for plugin_name, plugin in pairs(Plugin.plugins) do
            if plugin.client_commands[command_name] then
                plugin._reply_info = { client = client, method = "PrintToChat" }

                local succeeded, ret = CoXpCall(function()
                    _reply_info = { client = client, method = "PrintToChat" }
                    _command_args = args
                    _command_arg_string = arg_string
                    args = args
                    arg_string = arg_string
                    plugin.client_commands[command_name](client, unpack(args))
                end)

                if not succeeded and ret.type ~= "return" then
                    plugin.Puts("Error: %s", ret.message)
                    plugin.Puts(ret.traceback)
                    Plugin.On("Error", ret, plugin_name, "ClientCommand")
                    plugin.PrintToChat(client, "Sorry, an error occurred while processing your request.")
                end

                plugin._reply_info = nil
            end
        end
    end
    
    Event.Hook(("Console_%s"):format(command_name), Plugin.client_commands[command_name])

    return true
end

-- Internal: Registers an admin command
function Plugin.RegisterAdminCommand(command_name)                
    if Plugin.admin_commands[command_name] then return false end

    Plugin.admin_commands[command_name] = function(client, ...)
        if client and not SparkMod.CanClientRunCommand(client, command_name) then
            SendToAdmin(client, "[SM] You have insufficient access to use that command.")
            return
        end

        local args, arg_string = SparkMod.ParseCommandArguments(...)

        for plugin_name, plugin in pairs(Plugin.plugins) do
            if plugin.admin_commands[command_name] then
                plugin._reply_info = { client = client, method = "SendToAdmin" }

                local succeeded, ret = CoXpCall(function()
                    _reply_info = { client = client, method = "SendToAdmin" }
                    _command_args = args
                    _command_arg_string = arg_string
                    args = args
                    arg_string = arg_string
                    plugin.admin_commands[command_name](client, unpack(args))
                end)

                if not succeeded and ret.type ~= "return" then
                    plugin.Puts("Error: %s", ret.message)
                    plugin.Puts(ret.traceback)
                    Plugin.On("Error", ret, plugin_name, "AdminCommand")
                    plugin.PrintToChat(client, "Sorry, an error occurred while processing your request.")
                end

                plugin._reply_info = nil
            end
        end
    end

    Event.Hook(("Console_%s"):format(command_name), Plugin.admin_commands[command_name])

    return true
end

-- Event handlers
function Plugin.OnChatMessage(client, message, team_number, team_only)
    if not client then return end
    
    -- Try handle chat message as client command
    local args, arg_string = SparkMod.ParseCommandArguments(message)
    local command_name = table.remove(args, 1):lower()

    local has_parsed_trigger = false

    if SparkMod.config.public_chat_triggers then
        for _, trigger in ipairs(SparkMod.config.public_chat_triggers) do
            if command_name:match('^' .. trigger:escape_pattern()) then
                command_name = command_name:sub(#trigger+1)
                has_parsed_trigger = true
                break
            end
        end
    end

    if not has_parsed_trigger and SparkMod.config.hidden_chat_triggers then
        for _, trigger in ipairs(SparkMod.config.hidden_chat_triggers) do
            if command_name:match('^' .. trigger:escape_pattern()) then
                command_name = command_name:sub(#trigger+1)
                has_parsed_trigger = true
                break
            end
        end
    end

    if not has_parsed_trigger and SparkMod.config.triggerless_commands == false then
        return
    end
    
    if Plugin.client_commands[command_name] then
        for plugin_name, plugin in pairs(Plugin.plugins) do
            if plugin.client_commands[command_name] then
                plugin._reply_info = { client = client, method = "PrintToChat" }

                local succeeded, ret = CoXpCall(function()
                    _reply_info = { client = client, method = "PrintToChat" }
                    _command_args = args
                    _command_arg_string = arg_string
                    args = args
                    arg_string = arg_string
                    plugin.client_commands[command_name](client, unpack(args))
                end)

                if not succeeded then
                    plugin.Puts("Error: %s", ret.message)
                    plugin.Puts(ret.traceback)
                    Plugin.On("Error", ret, plugin_name, "ClientCommand")
                    plugin.PrintToChat(client, "Sorry, an error occurred while processing your request.")
                end

                plugin._reply_info = nil
            end
        end
    end
end

function Plugin.OnClientInitialized(client, version)
    for plugin_name, plugin in pairs(Plugin.plugins) do
        if plugin.shared_default_config then
            for key, default_value in pairs(plugin.shared_default_config) do
                SparkMod.SetClientConfig(client, plugin_name, key, plugin.config[key])
            end
        end
    end
end

function Plugin.OnClientDisconnect(client)
    if client and not client:GetIsVirtual() then
        local steam_id = client:GetUserId()

        for _, plugin in pairs(Plugin.plugins) do
            if plugin.clients.data[steam_id] then
                plugin.clients.data[steam_id] = nil
            end
        end
    end
end