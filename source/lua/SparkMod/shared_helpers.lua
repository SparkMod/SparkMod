-- SparkMod shared helpers

SparkMod.script_loaded_hooks = { }

function SparkMod.WhenScriptLoads(path_ending, callback)
    SparkMod.script_loaded_hooks[path_ending] = SparkMod.script_loaded_hooks[path_ending] or { }
    table.insert(SparkMod.script_loaded_hooks[path_ending], callback)
end

-- Fires a callback in the next server tick
function SparkMod.Schedule(callback, ...)
    SparkMod.scheduled_for_next_tick = SparkMod.scheduled_for_next_tick or { }
    table.insert(SparkMod.scheduled_for_next_tick, { callback = callback, args = {...} })
end

-- Calls a function, catches errors, returns success, ...
function SparkMod.Call(func, ...)
    function call_function()
        return func(unpack(arg))
    end
    function process_error(msg)
        if msg.type == "return" then
            return msg
        else
            return { message = msg, traceback = debug.traceback() }
        end
    end
    return xpcall(call_function, process_error)
end

-- Loads a core SparkMod file as if it were a plugin
function SparkMod.LoadCorePlugin(name)
    local load_file, err = loadfile(string.format("lua/SparkMod/%s.lua", name))
    if not load_file then
        Puts("[SM] Failed to load SparkMod/%s.lua: %s", name, err)
        return
    end

    local plugin_env = Plugin.BuildEnv("SparkMod")

    local plugin_metatable = {
        __index = function(_, name)
            return Plugin.proxy_attributes[name] and Plugin.proxy_attributes[name]() or _G[name]
        end
    }

    local plugin = setmetatable(plugin_env, plugin_metatable)

    Plugin.LoadBase(plugin)

    setfenv(load_file, plugin)
    load_file()
end