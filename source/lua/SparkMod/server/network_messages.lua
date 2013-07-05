-- SparkMod server network messages

-- Engine hooks
local HookNetworkMessage = Server.HookNetworkMessage
function Server._HookNetworkMessage(message_name, callback)
    local function hook_callback(...)
        local values = SparkMod._On("PreNetworkMessage" .. message_name, ...)
        if values then
            return UnpackAllValues(values)
        else
            callback(...)
            SparkMod.On("NetworkMessage" .. message_name, ...)
        end
    end

    return HookNetworkMessage(message_name, hook_callback)
end

function Server.HookNetworkMessage(message_name, callback)
    SparkMod.network_message_hooks[message_name] = SparkMod.network_message_hooks[message_name] or { }
    if callback then
        table.insert(SparkMod.network_message_hooks[message_name], callback)
    end
end

-- Overloads:
-- Server.SendNetworkMessage(string messageName, table variables)
-- Server.SendNetworkMessage(string messageName, table variables, boolean reliable)
-- Server.SendNetworkMessage(ServerClient client, string messageName, table variables, boolean reliable)
-- Server.SendNetworkMessage(Entity player, string messageName, table variables, boolean reliable)
local SendNetworkMessage = Server.SendNetworkMessage
function Server.SendNetworkMessage(...)
    local target, message_name, message, reliable
    if type(select(1, ...)) == "string" then
        message_name, message, reliable = ...
    else
        target, message_name, message, reliable = ...
    end

    SparkMod.OnPreSendNetworkMessage(target, message_name, message, reliable)

    if Plugin.On("PreSendNetworkMessage" .. message_name, target, message) == false then
        return
    end

    if coroutine.running() then
        if target then
            SparkMod.Schedule(SendNetworkMessage, target, message_name, message, reliable or false)
        else
            SparkMod.Schedule(SendNetworkMessage, message_name, message, reliable or false)
        end
    else
        if target then
            SendNetworkMessage(target, message_name, message, reliable or false)
        else
            SendNetworkMessage(message_name, message, reliable or false)
        end
    end
end


local netmsg_callbacks = { }

-- Network message hooks
if SparkMod.is_using_workshop then

    SparkMod.HookNetworkMessage("SM_ClientError", function(client, err)
        SparkMod.OnClientError(client, err.message, err.traceback, err.plugin_name, err.event_name, err.unloading)
    end)

    SparkMod.HookNetworkMessage("SM_NetMsgExists", function(client, message)
        local user_id = client:GetUserId()

        local info = SparkMod.clients[user_id]
        if info then
            info.network_message_supported = info.network_message_supported or { }
            info.network_message_supported[message.name] = message.exists
        end

        local user_callbacks = netmsg_callbacks[user_id]
        if not user_callbacks or not user_callbacks.exists then return end
        
        if user_callbacks.exists[message.name] and #user_callbacks.exists[message.name] > 0 then
            for _, callback in ipairs(user_callbacks.exists[message.name]) do
                local succeeded, err = SparkMod.Call(callback, message.exists)
                if not succeeded and err.type ~= "return" then
                    plugin.Puts("Error while processing SM_NetMsgExists callback: %s", err.message)
                    plugin.Puts(err.traceback)
                    Plugin.On("Error", err, "SparkMod", "SM_NetMsgExists")
                end
            end
            user_callbacks.exists[message.name] = nil
        end
    end)

end

-- Network message helpers
function SparkMod.SetClientConfig(client, config_name, key, value)
    local message = { name = config_name, key = key, value = json.encode(value) }

    if #message.value > kMaxConfigValueLength then
        Puts("[SM] Warning: Shared configuration value \"%s\" in \"%s\" is too large to send over the network!", key, config_name)
    else
        Puts("[SM] Sending %s configuration to %N: %s", config_name, client, key)
        SparkMod.SendNetworkMessage(client, "SM_SetConfig", message)
    end
end

function SparkMod.SetClientConfigAll(config_name, key, value)
    if SparkMod.clients.count < 1 then return end

    local message = { name = config_name, key = key, value = json.encode(value) }

    if #message.value > kMaxConfigValueLength then
        Puts("[SM] Warning: Shared configuration value \"%s\" in \"%s\" is too large to send over the network!", key, config_name)
    else
        Puts("[SM] Sending %s configuration to all clients: %s", config_name, key)
        SparkMod.SendNetworkMessage("SM_SetConfig", message)
    end
end

function SparkMod.FireClientForward(client, event_name, plugin_name)
    Puts("[SM] Firing forward on client %N: %s (%s)", client, event_name, plugin_name or "global")
    SparkMod.SendNetworkMessage(client, "SM_Forward", { name = event_name, plugin = plugin_name })
end

function SparkMod.FireClientForwardAll(event_name, plugin_name)
    Puts("[SM] Firing forward on all clients: %s (%s)", event_name, plugin_name or "global")
    SparkMod.SendNetworkMessage("SM_Forward", { name = event_name, plugin = plugin_name })
end

function SparkMod.ClientSupportsNetworkMessage(client, message_name, callback)
    local co = coroutine.running()
    if not co and not callback then
        error("ClientSupportsNetworkMessage must either be called from inside a coroutine or you need to pass a callback to it")
    end

    local user_id = client:GetUserId()
    local user_info = SparkMod.clients[user_id]

    if not user_info.client_enabled then
        if callback then callback(false) end
        return false
    end

    if user_info.network_message_supported and user_info.network_message_supported[message_name] ~= nil then
        if callback then
            callback(user_info.network_message_supported[message_name])
        end
        return user_info.network_message_supported[message_name]
    end

    netmsg_callbacks[user_id] = netmsg_callbacks[user_id] or { }
    netmsg_callbacks[user_id].exists = netmsg_callbacks[user_id].exists or { }
    netmsg_callbacks[user_id].exists[message_name] = netmsg_callbacks[user_id].exists[message_name] or { }

    if #netmsg_callbacks[user_id].exists[message_name] == 0 then
        SparkMod.SendNetworkMessage(client:GetControllingPlayer(), "SM_NetMsgExists", { name = message_name, exists = false })
    end
    
    table.insert(netmsg_callbacks[user_id].exists[message_name], function(exists)
        if co then coroutine.resume(co, exists) else callback(exists) end
    end)
    
    return co and coroutine.yield()
end

function SparkMod.PrintToScreen(player, x, y, text, duration, color, tag)
    local message = {
        x = x,
        y = y,
        text = text,
        duration = duration,
        r = color.r or color[1],
        g = color.g or color[2],
        b = color.b or color[3],
        tag = tag
    }

    SparkMod.SendNetworkMessage(player, "SM_PrintToScreen", message)
end