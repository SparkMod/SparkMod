-- SparkMod engine hooks

if Server or Client then

    local LoadScript = Script.Load
    function Script.Load(path, reload)
        LoadScript(path, reload)

        if SparkMod.OnScriptLoaded then
            SparkMod.OnScriptLoaded(path, reload)
        end
    end

    SparkMod.event_prehooked = { }

    local HookEvent = Event.Hook
    function Event.Hook(event_name, callback)
        HookEvent(event_name, function(...)
            if SparkMod.event_prehooked[event_name] then
                local values = SparkMod._On("Pre" .. event_name, ...)
                if values and #values > 0 then
                    return UnpackAllValues(values)
                end
            end
            return callback(...)
        end)
    end
    
end