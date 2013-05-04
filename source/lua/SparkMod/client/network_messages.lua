-- SparkMod client network messages

local HookNetworkMessage = Client.HookNetworkMessage
function Client._HookNetworkMessage(message_name, callback)
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

function Client.HookNetworkMessage(message_name, callback)
    SparkMod.network_message_hooks[message_name] = SparkMod.network_message_hooks[message_name] or { }
    if callback then
        table.insert(SparkMod.network_message_hooks[message_name], callback)
    end
end

local SendNetworkMessage = Client.SendNetworkMessage
function Client.SendNetworkMessage(message_name, message, reliable)
    SparkMod.OnPreSendNetworkMessage(nil, message_name, message, reliable)

    if Plugin.On("PreSendNetworkMessage" .. message_name, message) == false then
        return
    end

    if coroutine.running() then
        SparkMod.Schedule(SendNetworkMessage, message_name, message, reliable)
    else
        SendNetworkMessage(message_name, message, reliable)
    end

    return true
end

SparkMod.HookNetworkMessage("SM_SetConfig", function(message)
    local value = json.decode(message.value)

    local config
    if message.name == "SparkMod" then
        config = SparkMod.config
    else
        local plugin = Plugin.plugins[message.name]
        if not plugin then
            Puts("[SM] Unable to set config attribute \"%s\" for unloaded plugin: %s", message.key, message.name)
            SparkMod.On("Error", ("Unable to set config attribute \"%s\" for unloaded plugin"):format(message.key), message.name, "SM_SetConfig")
            return
        end

        plugin.config = plugin.config or { }

        config = plugin.config
    end


    local indexes = { }
    for index in message.key:gmatch "[^%.]+" do
        table.insert(indexes, index)
    end

    local first_index = indexes[1]
    local first_index_old_value = config[first_index] and table.dup(config[first_index])
    
    local last_index
    for i, index in ipairs(indexes) do
        if i < #indexes then
            config = config[index]
        else
            last_index = index
        end
    end

    config[last_index] = value

    Puts("[%s] Server changed config for %s: %s", message.name, message.key, message.value)

    if message.name == "SparkMod" then
        --TODO: implement event for SparkMod base config changes
    else
        if SparkMod.is_configuration_initialized then
            plugin.FireEvent("ConfigValueChanged", first_index, value, first_index_old_value)
        end
    end
end)

SparkMod.HookNetworkMessage("SM_Forward", function(message)
    if message.plugin then
        if Plugin.IsLoaded(message.plugin) then
            Plugin.plugins[message.plugin].FireEvent(message.name)
        else
            Puts("[SM] Warning: Server expects plugin which is not loaded: %s", message.plugin)
        end
    else
        SparkMod.On(message.name)
    end
end)

SparkMod.HookNetworkMessage("SM_PrintToScreen", function(message)
    local color = Color(message.r/255, message.g/255, message.b/255)
    SparkMod.PrintToScreen(message.x, message.y, message.text, message.duration, color, message.tag)
end)

SparkMod.HookNetworkMessage("SM_NetMsgExists", function(message)
    message.exists = not not SparkMod.network_messages[message.name]
    SparkMod.SendNetworkMessage("SM_NetMsgExists", message)
end)