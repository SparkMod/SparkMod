-- SparkMod client loader

Script.Load("lua/SparkMod/shared.lua")
Script.Load("lua/SparkMod/client/text_messages.lua")
Script.Load("lua/SparkMod/client/network_messages.lua")

SparkMod.is_configuration_initialized = false

function SparkMod.OnClientInitialized()
    Shared.ConsoleCommand("___sm_initialized___ " .. SparkMod.version)
end

function SparkMod.OnConfigurationInitialized()
    SparkMod.is_configuration_initialized = true
end

function SparkMod.OnError(err, plugin_name, event_name, is_unloading)
    local error_message, traceback
    if type(err) == "string" then
        error_message = err
    elseif type(err) == "table" then
        error_message = err.message
        traceback = err.traceback
    else
        Puts("[OnError] Unknown error container: %s (%s)", tostring(err), type(err))
    end

    local message = {
        message = error_message,
        traceback = traceback,
        plugin_name = plugin_name,
        event_name = event_name,
        unloading = is_unloading or false
    }

    SparkMod.SendNetworkMessage("SM_ClientError", message)
end

local update_client_interval = 0.1
local since_last_update_client = 0
local has_initialized = false

Event.Hook("UpdateClient", function(delta_time)
    since_last_update_client = since_last_update_client + delta_time

    if not has_initialized then
        has_initialized = true
        SparkMod.On("ClientInitialized")
    end

    if SparkMod.scheduled_for_next_tick and #SparkMod.scheduled_for_next_tick > 0 then
        for _, scheduled in ipairs(SparkMod.scheduled_for_next_tick) do
            local succeeded, err = SparkMod.Call(function()
                return scheduled.callback(unpack(scheduled.args))
            end)
            if not succeeded and err.type ~= "return" then
                Puts("Error: %s", err.message)
                Puts(err.traceback)
                Plugin.On("Error", err, plugin_name, "NextTick")
            end
        end
        SparkMod.scheduled_for_next_tick = nil
    end

    if since_last_update_client > update_client_interval then
        Scheduler.Update()

        SparkMod.On("UpdateClient", delta_time)
        
        since_last_update_client = since_last_update_client - update_client_interval
    end
end)