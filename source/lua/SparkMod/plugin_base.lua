--- SparkMod shared plugin base.
-- These functions are available to both server and client-side plugins

--- Shortcut to reference SparkMod core
SM = SparkMod

--- Reference to this plugin
self = getfenv()

--- Alias for string.format, functionality is extended for server plugins
-- @function Format
-- @string format the string to format
-- @param[opt] ... any number of arguments to be formatted
Format = string.format

--- Prints a string to the server console prepended with the plugins name
-- @string format the string to format
-- @param ... any number of arguments to be formatted
function Puts(format, ...)
    _G.Puts("[%s] %s", plugin_name, Format(format, ...))
end

--- Gets the number of seconds since the server started or changed map.
-- The value returned is a high precision float.
-- @function GetTime
-- @treturn number the current system timestamp in seconds
GetTime = Shared.GetTime

--- Gets the current system time in seconds
-- @function GetSystemTime
-- @treturn number the current system timestamp in seconds
GetSystemTime = Shared.GetSystemTime()

--- Declares variables that will persist between map changes, plugin reloads and server restarts.
-- Persistent variables are saved to a file when the plugin is unloaded or if Store() is called.
-- @tab tbl a table containing all variables you want to persist
-- @usage Persistent {
--     recent_map = { }
-- }
function Persistent(tbl)
    local plugin_store = SparkMod.store[plugin_name]

    SparkMod.store[plugin_name] = SparkMod.store[plugin_name] or { }
    
    persistent_variables = { }

    for name, default_value in pairs(tbl) do
        persistent_variables[name] = true
        self[name] = plugin_store and plugin_store[name] and table.dup(plugin_store[name]) or default_value
    end
end

--- Saves persistent variables to storage
-- @string[opt] name a variables name if you only want to save a single persistent variable
function Store(name)
    local plugin_store = SparkMod.store[plugin_name]

    if name then
        if not persistent_variables or not persistent_variables[name] then
            error("Unable to store variables which have not been defined as persistent")
        end

        plugin_store[name] = table.dup(self[name])
    else
        if not persistent_variables then
            return false
        end

        for name, _ in pairs(persistent_variables) do
            plugin_store[name] = table.dup(self[name])
        end
    end

    SparkMod.SavePersistentStore()

    return true
end

--- Restores persistent variables from storage
-- @string[opt] name a variables name if you only want to restore a single persistent variable
function Restore(name)
    local plugin_store = SparkMod.store[plugin_name]

    if name then
        if not persistent_variables or not persistent_variables[name] then
            error("Unable to restore variables which have not been defined as persistent")
        end

        self[name] = table.dup(plugin_store[name])
    else
        if not persistent_variables then
            return false
        end

        for name, _ in pairs(persistent_variables) do
            self[name] = table.dup(plugin_store[name])
        end
    end

    return true
end

function CatchErrors(func)
    local succeeded, ret = pcall(func)
    if succeeded then
        return ret
    else
        Puts("Error while loading: %s", ret)
    end
end

-- Internal
function __newindex(self, index, value)
    if not is_plugin_initialized then
        if index == "library_name" then
            name = value:camelize()

            if _G[name] then
                error("Plugin library name unavailable: " .. name)
            end

            if _library_name then
                _G[_library_name] = nil
                _G[name] = getfenv()
                _library_name = name
            end
        elseif index == "default_config" then
            if Client and not Plugin.IsSharedFile(currently_loading_plugin_file) then
                error "Client plugins may not have a default_config. default_config must be defined in either a server or shared plugin file"
            end

            Plugin.OnDefaultConfig(self, currently_loading_plugin_file, value)

            if self._default_config then
                value = table.merged(self._default_config, value)
            end

            rawset(self, "_default_config", value)
            
            return
        end
    end

    rawset(self, index, name)
end

--- Requires other plugins to be loaded before initializing this plugin.
-- Must be used in the plugin body. In the case of circular dependencies, plugins will be loaded before
-- OnLoaded is called in this plugin but OnLoaded may not have yet been called in the dependent plugins.
-- @param ... any number of other plugins names
-- @usage Requires "map_vote"
--Requires("map_vote", "rtv")
function Requires(...)
    if is_plugin_initialized then
        error("Requires must be used before the plugin has finished loading")
    end

    Plugin.dependencies[plugin_name] = Plugin.dependencies[plugin_name] or { }

    for i = 1, select('#', ...) do
        local dependency_name = select(i, ...)

        if not table.contains(Plugin.dependencies[plugin_name], dependency_name) then
            table.insert(Plugin.dependencies[plugin_name], dependency_name)
        end

        if not Plugin.IsLoaded(dependency_name) then
            Plugin.waiting_for_dependencies[plugin_name] = Plugin.waiting_for_dependencies[plugin_name] or { }
            Plugin.waiting_for_dependencies[plugin_name][dependency_name] = true

            if not Plugin.waiting_for_dependencies[dependency_name] then
                coroutine.yield({ type = "need_dependency", name = dependency_name })
            end
        end
    end
end

--- Registers a global name that can be used to reference this plugin from other plugins.
-- Must be used in the plugin body.
-- @string name the name of the global variable to be used to refer to your plugin
-- @usage RegPluginLibrary("YourPluginName")
-- -- You can also set library_name
-- library_name = "YourPluginName"
function RegPluginLibrary(name)
    if is_plugin_initialized then
        error("You must register a library name before the plugin has finished loading")
    end

    library_name = name
end

--- Registers a network message field, creates the network message if it does not already exist
-- @string message_name the name of the network message
-- @string name the name of the message field
-- @string type the type of the message field
-- @param default_value used when sending the message missing this field, will be used even if the server plugin is unloaded at runtime
function NetworkMessageField(message_name, field_name, field_type, default_value)
    if SparkMod.network_messages_registered then
        if not SparkMod.network_messages[message_name] then
            error "Plugins that need to register new network messages can only be loaded by changing the map"
        end

        local registered_field = SparkMod.network_messages[message_name][field_name]
        if not registered_field or registered_field.type ~= field_type or registered_field.default_value ~= default_value then
            error "Plugins that change network messages can only be loaded by changing the map"
        end
    end

    assert(field_type, "Argument #2 is missing, a field name is required")
    assert(field_type, "Argument #3 is missing, a field type is required for all fields")
    assert(default_value, "Argument #4 is missing, a default value is required for all fields")

    SparkMod.network_messages[message_name] = SparkMod.network_messages[message_name] or { }
    SparkMod.network_messages[message_name][field_name] = { type = field_type, default_value = default_value }
end

--- Registers or extends a network message.
-- The default_value is used when sending a message missing the field,
-- it will be used even if the server plugin is unloaded at runtime
-- @function NetworkMessage
-- @string message_name
-- @func func an inline function
-- @usage NetworkMessage("SM_SetKv", function()
--     Field("key", "string (64)", "")
--     Field("value", "string (128)", "")
-- end)
NetworkMessage = SparkMod.NetworkMessage

-- Internal
function RegisterForward(event_name, callback)
    if SparkMod.config.debug_forwards then
        Puts("Plugin handles forward: %s", event_name)
    end

    forwards[event_name] = forwards[event_name] or { }

    if table.contains(forwards[event_name], callback) then
        return false
    end

    table.insert(forwards[event_name], callback)

    local hook = SparkMod.event_name_function_hooks[event_name]
    if hook then
        if SparkMod.config.debug_function_hooks then
            Puts("Activating function hook for event: %s", event_name)
        end
        SparkMod._ActivateFunctionHook(hook)
    end

    return true
end

-- Internal
function FireEvent(event_name, ...)
    if forwards[event_name] then
        return CoXpCall(function(...)
            for _, callback in ipairs(forwards[event_name]) do
                callback(...)
            end
        end, ...)
    end
    return true
end

-- Internal
function FireFunctionHooks(hook_type, method_name, ...)
    if hooked_function_callbacks[method_name] then
        for _, callback in ipairs(hooked_function_callbacks[method_name][hook_type]) do
            local succeeded, ret = SparkMod.Call(function(...)
                return PackAllValues(callback(...))
            end, ...)

            if not succeeded and ret.type ~= "return" then
                Puts("Error: %s", ret.message)
                Puts(ret.traceback)
                error_count = error_count + 1
                if error_count >= SparkMod.config.unload_plugin_error_limit then
                    Plugin.On("Error", ret, plugin_name, method_name, true)
                    Puts("Unloading plugin due to error limit: %s (%d errors)", ret.message, error_count)
                    Plugin.Unload(plugin_name)
                else
                    Plugin.On("Error", ret, plugin_name, method_name)
                end
            elseif succeeded and ret.count > 0 then
                return ret
            end
        end
    end
end

--- Pre-hooks a function and calls the callback every time the function is about to be called.
-- Varargs are passed to the callback as a table. Other plugins can use Pre/post hook forwards to hook this kind of hook.
-- @string method_name the name of the function to be hooked
-- @func callback the callback which will be called before the hooked function is called
-- @usage HookFunctionPre("Server.DestroyEntity", function(entity)
--     Puts("Entity is being destoyed: %s", entity:GetClassName())
-- end)
function HookFunctionPre(method_name, callback)
    assert(callback, "Argument #2 needs to be a callback function")

    hooked_function_callbacks[method_name] = hooked_function_callbacks[method_name] or { pre = { }, post = { } }    
    table.insert(hooked_function_callbacks[method_name].pre, callback)

    local hook = SparkMod.HookFunctionPre(method_name, method_name:gsub('.', ''))

    if not hook.active then
        hook.active = true
        SparkMod._HookFunctionHook(hook)
    end
end

--- Post-hooks a function and calls the callback every time the function has been called.
-- Varargs are passed to the callback as a table. Other plugins can use Pre/post hook forwards to hook this kind of hook.
-- @string method_name the name of the function to be hooked
-- @func callback the callback which will be called after the hooked function is called
-- @usage HookFunction("Server.DestroyEntity", function(entity)
--     Puts "An entity has been destoyed"
-- end)
function HookFunction(method_name, callback)
    assert(callback, "Argument #2 needs to be a callback function")

    hooked_function_callbacks[method_name] = hooked_function_callbacks[method_name] or { pre = { }, post = { } }
    table.insert(hooked_function_callbacks[method_name].post, callback)

    local hook = SparkMod.HookFunction(method_name, method_name:gsub('.', ''))

    if not hook.active then
        hook.active = true
        SparkMod._HookFunctionHook(hook)
    end
end

--- Pre-hooks a Gamerules function and calls the callback every time the function is about to be called.
-- Varargs are passed to the callback as a table. Other plugins can use Pre/post hook forwards to hook this kind of hook.
-- @string method_name the name of the Gamerules function to be hooked
-- @func callback the callback which will be called before the hooked Gamerules function is called
function HookGamerulesFunctionPre(method_name, callback)
    HookFunctionPre('Gamerules.' .. method_name, callback)
end

--- Post-hooks a Gamerules function and calls the callback every time the function has been called.
-- Varargs are passed to the callback as a table. Other plugins can use Pre/post hook forwards to hook this kind of hook.
-- @string method_name the name of the Gamerules function to be hooked
-- @func callback the callback which will be called after the hooked Gamerules function is called
function HookGamerulesFunction(method_name, callback)
    HookFunction('Gamerules.' .. method_name, callback)
end

--- Pre-hooks a NS2Gamerules function and calls the callback every time the function is about to be called.
-- Varargs are passed to the callback as a table. Other plugins can use Pre/post hook forwards to hook this kind of hook.
-- @string method_name the name of the NS2Gamerules function to be hooked
-- @func callback the callback which will be called before the hooked NS2Gamerules function is called
function HookNS2GamerulesFunctionPre(method_name, callback)
    HookFunctionPre('NS2Gamerules.' .. method_name, callback)
end

--- Post-hooks a NS2Gamerules function and calls the callback every time the function has been called.
-- Varargs are passed to the callback as a table. Other plugins can use Pre/post hook forwards to hook this kind of hook.
-- @string method_name the name of the NS2Gamerules function to be hooked
-- @func callback the callback which will be called after the hooked NS2Gamerules function is called
function HookNS2GamerulesFunction(method_name, callback)
    HookFunction('NS2Gamerules.' .. method_name, callback)
end

--- Injects a function into the scope of other functions so that you can use locals they reference.
-- @function InjectIntoScope
-- @param ... any number of functions referencing locals you want to use
-- @tparam ?int|string function to share scope with other functions, will not be called if passed as a string
InjectIntoScope = SparkMod.InjectIntoScope

--- Hooks a network message and calls the callback when the network message is received
-- @string message_name the name of the message
-- @func callback the callback function
function HookNetworkMessage(message_name, callback)
    network_message_hooks[message_name] = network_message_hooks[message_name] or { }

    table.insert(network_message_hooks[message_name], callback)

    Plugin.HookNetworkMessage(message_name)
end

--- Sends a network message to one or all connected players.
-- @function SendNetworkMessage
-- @target[opt] target a single player to send the network message to
-- @string message_name the name of the network message
-- @tab message the network message
SendNetworkMessage = SparkMod.SendNetworkMessage

--- Hooks a network message and responds with the same message.
-- @string message_name the network message name
-- @func callback a function that is passed the received message and returns the response message
function RespondToNetworkMessage(message_name, callback)
    HookNetworkMessage(message_name, function(message)
        SendNetworkMessage(message_name, callback(message))
    end)
end