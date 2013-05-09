-- SparkMod network messages

SparkMod.network_messages = { }
SparkMod.network_message_hooks = { }
SparkMod.network_messages_registered = false

Shared._RegisterNetworkMessage = Shared.RegisterNetworkMessage
function Shared.RegisterNetworkMessage(...)
    local message_name = select(1, ...)
    local attributes = select('#', ...) > 1 and select(2, ...) or { }
    
    if SparkMod.network_messages_registered then
        Puts("[SM] Network message will only be registered after map change: %s", message_name)
        return
    end

    SparkMod.network_messages[message_name] = SparkMod.network_messages[message_name] or { }

    for name, attribute_type in pairs(attributes) do
        SparkMod.network_messages[message_name][name] = { type = attribute_type }
    end
end

-- Hooks a network message and calls the callback when the network message is received
-- @string message_name the name of the message
-- @func callback the callback function
function SparkMod.HookNetworkMessage(message_name, callback)
    SparkMod.network_message_hooks[message_name] = SparkMod.network_message_hooks[message_name] or { }
    if callback then
        table.insert(SparkMod.network_message_hooks[message_name], function(client, message)
            if Client then message = client end

            if SparkMod.network_messages[message_name] then
                for name, field in pairs(SparkMod.network_messages[message_name]) do
                    if field.type:starts("string") and #message[name] == 0 then
                        message[name] = nil
                    end
                end
            end

            local suceeeded, err
            if Client then
                suceeeded, err = SparkMod.Call(callback, message)
            else
                suceeeded, err = SparkMod.Call(callback, client, message)
            end
            if not suceeeded then
                Puts("[SM] Error while handling %s network message: %s", message_name, err.message)
                Puts(err.traceback)
                Plugin.On("Error", err, "SparkMod", "NetworkMessage")
            end
        end)
    end
end

function SparkMod.OnPreSendNetworkMessage(client, message_name, message)
    if SparkMod.network_messages[message_name] then
        for name, field in pairs(SparkMod.network_messages[message_name]) do
            if not message[name] then
                message[name] = field.default_value
            end
        end
    end
end

-- Sends a network message to a target client or player
-- @target the target to send the message to
-- @string message_name the name of the message
-- @func callback the callback function
function SparkMod.SendNetworkMessage(...)
    assert(select('#', ...) >= 2, "SendNetworkMessage requires at least 2 arguments (message_name and message)")

    local player, player, message_name, message, reliable
    if type(select(1, ...)) == "string" then
        message_name, message, reliable = ...
    else
        player, message_name, message, reliable = ...
        if player:isa('ServerClient') then
            player = player:GetControllingPlayer()
        end
    end

    if SparkMod.network_messages[message_name] then
        for name, field in pairs(SparkMod.network_messages[message_name]) do
            if not message[name] and field.type:starts("string") then
                message[name] = ""
            end
        end
    else
        Puts("[SendNetworkMessage] Unknown message: %s", message_name)
    end

    if coroutine.running() then
        if player then
            SparkMod.Schedule((Server or Client).SendNetworkMessage, player, message_name, message, true)
        else
            SparkMod.Schedule((Server or Client).SendNetworkMessage, message_name, message, true)
        end
    else
        if player then
            (Server or Client).SendNetworkMessage(player, message_name, message, true)
        else
            (Server or Client).SendNetworkMessage(message_name, message, true)
        end
    end

    return true
end

-- Registers or extends a network message
-- The default_value is used when sending a message missing the field,
-- it will be used even if the server plugin is unloaded at runtime
-- @string message_name
-- @func func an inline function
-- @usage NetworkMessage(`message_name`, function())
--     Field(`field_name`, `field_type`, `default_value`)
-- end)
function SparkMod.NetworkMessage(message_name, func)
    SparkMod.network_messages[message_name] = SparkMod.network_messages[message_name] or { }
    local env = {
        Field = function(field_name, field_type, default_value)
            SparkMod.network_messages[message_name][field_name] = { type = field_type }
        end
    }
    setfenv(func, env)
    func()
end

if Server and not SparkMod.is_using_workshop then return end

-- Core network messages
kMaxConfigValueLength = 256

local kSetConfigMessage = {
    name = "string (64)",
    key = "string (64)",
    value = ("string (%d)"):format(kMaxConfigValueLength),
}

Shared.RegisterNetworkMessage("SM_SetConfig", kSetConfigMessage)

local kForwardMessage = {
    name = "string (64)",
    plugin = "string (64)"
}

Shared.RegisterNetworkMessage("SM_Forward", kForwardMessage)

local kNetMsgExistsMessage = {
    name = "string (64)",
    exists = "boolean"
}

Shared.RegisterNetworkMessage("SM_NetMsgExists", kNetMsgExistsMessage)

local kClientErrorMessage = {
    message = "string (192)",
    traceback = "string (512)",
    plugin_name = "string (64)",
    event_name = "string (64)",
    unloading = "boolean"
}

Shared.RegisterNetworkMessage("SM_ClientError", kClientErrorMessage)

local kPrintToScreenMessage = {
    x           = "float",
    y           = "float",
    text        = "string (255)",
    duration    = "float",
    r           = "integer",
    g           = "integer",
    b           = "integer",
    tag         = "string (32)"
}

Shared.RegisterNetworkMessage("SM_PrintToScreen", kPrintToScreenMessage)