-- SparkMod function hooks

SparkMod.function_hooks = { }
SparkMod.event_name_function_hooks = { }
SparkMod.optional_class_hooks = { }
SparkMod.is_optional_class_hooked = { }
SparkMod.hooked_function_args = { }

local function_info = { }

local function CombineArgsHelper(f, n, a, ...)
    if n == 0 then return f() end
    return a, CombineArgsHelper(f, n-1, ...)
end

local function CombineArgs(f, ...)
    local n = select('#', ...)
    return CombineArgsHelper(f, n, ...)
end

local function FirstArgsHelper(n, a, ...)
    if n == 0 then return end
    return a, FirstArgsHelper(n-1, ...)
end

local function FirstArgs(k, ...)
    local n = select('#', ...)
    return FirstArgsHelper(k, ...)
end

-- Parses defined function argument info from lua virtual machine bytecode
-- @return argument_count, has_varargs
local function GetFunctionArgInfo(func)
    dbg_info = debug.getinfo(func)
    return dbg_info.nparams, dbg_info.isvararg
end

function SparkMod.ParseHookFunctionArgs(arg1, arg2, arg3, arg4)
    local class_name, method_name, event_name, hook_arg_helper
    local arg2_type = type(arg2)

    assert(type(arg1) == "string", ("Argument #1 (%s) is invalid! You need to pass a function as a string."):format(type(arg1)))
    
    if arg1:match("%.") then
        class_name, method_name = arg1:match("^([^%.]+)%.([^%.]+)$")
    else
        method_name = arg1
    end

    if arg2_type == "string" then
        event_name = arg2
        hook_arg_helper = type(arg3) == "function" and arg3
    elseif arg2_type == "function" then
        hook_arg_helper = arg2
    else
        assert(arg2 == nil, ("Argument #2 (%s) is invalid!"):format(arg2_type))
    end
    
    if not event_name then event_name = method_name end
    
    if string.sub(event_name, 0, 2) == "On" then
        event_name = string.sub(event_name, 3)
    end

    return class_name, method_name, event_name, hook_arg_helper
end


function SparkMod.SetFunctionArg(arg_number, value)
    local hooked_function_args = SparkMod.hooked_function_args[#SparkMod.hooked_function_args]
    assert(hooked_function_args, "You can only use SetFunctionArg from inside a function hook callback")

    hooked_function_args[arg_number] = value
    hooked_function_args.includes[arg_number] = true
end

-- Pre-hooks a function and calls the callback everytime the function is about to be called
-- Varargs are passed to the callback as a table if no hook argument helper is defined.
-- If you need to return varargs from a hook argument helper you must first pack them into a table.
-- Possible usage:
-- Plugin.HookFunction(method_name)
-- Plugin.HookFunction(method_name, function(arg1, arg2) return arg2, arg1 end)
-- Plugin.HookFunction(method_name, event_name)
-- Plugin.HookFunction(method_name, event_name, function(arg1, arg2) return arg2, arg1 end)
function SparkMod.HookFunctionPre(...)
    local class_name, method_name, event_name, arg_helper = SparkMod.ParseHookFunctionArgs(...)

    event_name = "Pre" .. event_name

    local hook_name = class_name and ("%s.%s"):format(class_name, method_name) or method_name

    if not SparkMod.function_hooks[hook_name] then
        SparkMod.function_hooks[hook_name] = {
            name = hook_name,
            type = "pre",
            class_name = class_name,
            method_name = method_name,
            arg_helper = arg_helper,
            event_names = { }
        }
    end

    table.insert(SparkMod.function_hooks[hook_name].event_names, event_name)
    SparkMod.event_name_function_hooks[event_name] = SparkMod.function_hooks[hook_name]

    return SparkMod.function_hooks[hook_name]
end

-- Internal
function SparkMod._HookFunctionEventPre(hook)
    local hook = SparkMod.function_hooks[hook.name]
    if not hook then
        error("Unable to find a function hook for event name: " .. event_name)
    end

    if SparkMod.IsFunctionHooked(hook.name, "pre") then
        return false
    end

    table.insert(Plugin.hooked_functions, hook)

    if SparkMod.config.debug_function_hooks then
        Puts("[DEBUG] Hooking function: %s", hook.name)
    end

    local original_method

    local function hook_function(...)
        SparkMod.hooked_function_args = SparkMod.hooked_function_args or { }
        
        local hook_function_args = { includes = { } }
        
        table.insert(SparkMod.hooked_function_args, hook_function_args)

        local given_arg_count = select('#', ...)
        local max_arg_count, has_varargs

        if function_info[hook.name] then
            hook.native = function_info[hook.name].is_native
            max_arg_count = function_info[hook.name].max_arg_count
            has_varargs = function_info[hook.name].has_varargs
        else
            function_info[hook.name] = { }

            hook.native = debug.getinfo(original_method).what == 'C'

            if hook.native then
                function_info[hook.name].is_native = true
                Puts("[SM] Warning: Native function hooks have limited argument support (%s)", hook.name)
            else
                max_arg_count, has_varargs = GetFunctionArgInfo(original_method)
                function_info[hook.name].max_arg_count = max_arg_count
                function_info[hook.name].has_varargs = has_varargs
            end
        end

        if hook.native then
            max_arg_count = given_arg_count
            has_varargs = false
        end

        local varargs
        if has_varargs and not hook.arg_helper then
            varargs = { }
            if given_arg_count > max_arg_count then
                varargs = {select(max_arg_count+1, ...)}
            end
        end

        local function count_max_args(...)
            max_arg_count = select('#', ...)
            return ...
        end

        local function get_args(...)
            if hook.arg_helper then
                return count_max_args(hook.arg_helper(...))
            elseif has_varargs then
                return varargs, FirstArgs(max_arg_count, ...)
            else
                return FirstArgs(max_arg_count, ...)
            end
        end

        local forward_result = SparkMod._On(hook.event_names, get_args(...))
        local hook_result = Plugin.FireFunctionHooks('pre', hook.name, ...)
        local result = forward_result and forward_result.count > 0 and forward_result or hook_result

        if result and result.count > 0 then
            table.remove(SparkMod.hooked_function_args)
            return UnpackAllValues(result)
        elseif #hook_function_args.includes > 0 then
            local function merge_helper(c, n, a, ...)
                if n == 0 then
                    table.remove(SparkMod.hooked_function_args)
                    return
                end
                if hook_function_args.includes[c-n+1] then
                    return hook_function_args[c-n+1], merge_helper(c, n-1, ...)
                else
                    return a, merge_helper(c, n-1, ...)
                end
            end

            local function merge_args(...)
                local arg_count = select('#', ...)
                return merge_helper(arg_count, arg_count, ...)
            end

            return original_method(merge_args(...))
        else
            table.remove(SparkMod.hooked_function_args)
            return original_method(...)
        end
    end

    if hook.class_name then
        if Script.GetDerivedClasses(hook.class_name) then
            original_method = Class_ReplaceMethod(hook.class_name, hook.method_name, hook_function)
        else
            original_method = _G[hook.class_name][hook.method_name]
            _G[hook.class_name][hook.method_name] = hook_function
        end
    else
        original_method = _G[hook.method_name]
        _G[hook.method_name] = hook_function
    end

    hook.hooked = true

    if original_method then
        hook.native = function_info[hook.name] and function_info[hook.name].native or debug.getinfo(original_method).what == 'C'

        function_info[hook.name] = function_info[hook.name] or { }

        if hook.native then
            function_info[hook.name].is_native = true
            Puts("[SM] Warning: Native function hooks have limited argument support (%s)", hook.name)
        elseif not function_info[hook.name].max_arg_count then
            local max_arg_count, has_varargs = GetFunctionArgInfo(original_method)
            function_info[hook.name].max_arg_count = max_arg_count
            function_info[hook.name].has_varargs = has_varargs
        end
    else
        Puts("[SM] Warning: Undefined function has been pre-hooked: %s", hook.name)
    end

    return true
end

-- Hooks a function and fires a forward when the function is called
-- Varargs are passed to the forward as a table if no hook argument helper is defined.
-- If you need to return varargs from a hook argument helper you must first pack them into a table.
function SparkMod.HookFunction(...)
    local class_name, method_name, event_name, arg_helper = SparkMod.ParseHookFunctionArgs(...)

    local hook_name = class_name and ("%s.%s"):format(class_name, method_name) or method_name

    if not SparkMod.function_hooks[hook_name] then
        SparkMod.function_hooks[hook_name] = {
            name = hook_name,
            type = "post",
            class_name = class_name,
            method_name = method_name,
            arg_helper = arg_helper,
            event_names = { }
        }
    end

    table.insert(SparkMod.function_hooks[hook_name].event_names, event_name)
    SparkMod.event_name_function_hooks[event_name] = SparkMod.function_hooks[hook_name]

    return SparkMod.function_hooks[hook_name]
end

-- Internal
function SparkMod._HookFunctionEvent(hook)
    if SparkMod.IsFunctionHooked(hook.name, "post") then
        return false
    end
    
    table.insert(Plugin.hooked_functions, hook)

    if SparkMod.config.debug_function_hooks then
        Puts("[DEBUG] Hooking function: %s", hook.name)
    end

    local original_method

    local function hook_function(...)
        local origional_values = {original_method(...)}        
        
        local given_arg_count = select('#', ...)
        local max_arg_count, has_varargs

        if function_info[hook.name] then
            hook.native = function_info[hook.name].is_native
            max_arg_count = function_info[hook.name].max_arg_count
            has_varargs = function_info[hook.name].has_varargs
        else
            function_info[hook.name] = { }

            hook.native = debug.getinfo(original_method).what == 'C'

            if hook.native then
                function_info[hook.name].is_native = true
                Puts("[SM] Warning: Native function hooks have limited argument support (%s)", hook.name)
            else
                max_arg_count, has_varargs = GetFunctionArgInfo(original_method)
                function_info[hook.name].max_arg_count = max_arg_count
                function_info[hook.name].has_varargs = has_varargs
            end
        end

        if hook.native then
            max_arg_count = given_arg_count
            has_varargs = false
        end

        local varargs
        if has_varargs and not hook.arg_helper then
            varargs = { }
            if given_arg_count > max_arg_count then
                varargs = {select(max_arg_count+1, ...)}
            end
        end

        local function count_max_args(...)
            max_arg_count = select('#', ...)
            return ...
        end

        local function get_args(...)
            if hook.arg_helper then
                return count_max_args(hook.arg_helper(...))
            else
                return FirstArgs(max_arg_count, ...)
            end
        end

        local function get_other_args()
            if hook.arg_helper then
                return unpack(origional_values)
            else
                local other_args = table.dup(origional_values)
                local varargs_index = 1
                if given_arg_count < max_arg_count then
                    for i = 1, max_arg_count - given_arg_count do
                        table.insert(other_args, 1, nil)
                        varargs_index = varargs_index + 1
                    end
                end
                if has_varargs then
                    table.insert(other_args, varargs_index, varargs)
                end
                return unpack(other_args)
            end
        end

        local function val_or_orig(...)
            if select('#', ...) == 0 then
                return unpack(origional_values)
            else
                return ...
            end
        end

        local function hook_or_forward_result(...)
            local hook_result = Plugin.FireFunctionHooks('post', hook.name, CombineArgs(get_other_args, ...))
            local function args_or_hook_result(...)
                if select('#', ...) > 0 then
                    return ...
                elseif hook_result and hook_result.count > 0 then
                    return UnpackAllValues(hook_result)
                end
            end
            return args_or_hook_result(SparkMod.On(hook.event_names, CombineArgs(get_other_args, get_args(...))))
        end

        return val_or_orig(hook_or_forward_result(...))
    end

    if hook.class_name then
        if Script.GetDerivedClasses(hook.class_name) then
            if SparkMod.config.debug_function_hooks then
                Puts("[HookFunction] Hooking function in all derived classes: %s", hook.name)
            end
            original_method = Class_ReplaceMethod(hook.class_name, hook.method_name, hook_function)
        else
            original_method = _G[hook.class_name][hook.method_name]
            if SparkMod.config.debug_function_hooks then
                Puts("[HookFunction] No derived classes for: %s (%s)", hook.name, tostring(original_method or "nil"))
            end
            _G[hook.class_name][hook.method_name] = hook_function
        end
    else
        original_method = _G[hook.method_name]
        _G[hook.method_name] = hook_function
    end

    hook.hooked = true

    if original_method then
        hook.native = function_info[hook.name] and function_info[hook.name].native or debug.getinfo(original_method).what == 'C'

        function_info[hook.name] = function_info[hook.name] or { }

        if hook.native then
            function_info[hook.name].is_native = true
            Puts("[SM] Warning: Native function hooks have limited argument support (%s)", hook.name)
        elseif not function_info[hook.name].max_arg_count then
            local max_arg_count, has_varargs = GetFunctionArgInfo(original_method)
            function_info[hook.name].max_arg_count = max_arg_count
            function_info[hook.name].has_varargs = has_varargs
        end
    else
        Puts("[SM] Warning: Undefined function has been hooked: %s", hook.name)
    end

    return true
end

-- Hooks a class function and fires a forward before the function is called
function SparkMod.HookClassFunctionPre(class_name, method_name, ...)
    return SparkMod.HookFunctionPre(("%s.%s"):format(class_name, method_name), ...)
end

-- Hooks a class function and fires a forward when the function is called
-- Possible usage:
-- Plugin.HookFunction(class_name, method_name)
-- Plugin.HookFunction(class_name, method_name, function(arg1, arg2) return arg2, arg1 end)
-- Plugin.HookFunction(class_name, method_name, event_name)
-- Plugin.HookFunction(class_name, method_name, event_name, function(arg1, arg2) return arg2, arg1 end)
function SparkMod.HookClassFunction(class_name, method_name, ...)
    return SparkMod.HookFunction(("%s.%s"):format(class_name, method_name), ...)
end

function SparkMod.HookServerFunctionPre(...)
    return SparkMod.HookClassFunctionPre("Server", ...)
end

function SparkMod.HookServerFunction(...)
    return SparkMod.HookClassFunction("Server", ...)
end

function SparkMod.HookGamerulesClassFunctionPre(gamerules_class, ...)
    local _, method_name, event_name, arg_helper = SparkMod.ParseHookFunctionArgs(...)
    if not arg_helper then
        arg_helper = function(...) return select(2, ...) end
    end
    return SparkMod.HookClassFunctionPre(gamerules_class, method_name, event_name, arg_helper)
end

function SparkMod.HookGamerulesClassFunction(gamerules_class, ...)
    local _, method_name, event_name, arg_helper = SparkMod.ParseHookFunctionArgs(...)
    if not arg_helper then
        arg_helper = function(...) return select(2, ...) end
    end
    return SparkMod.HookClassFunction(gamerules_class, method_name, event_name, arg_helper)
end

function SparkMod.HookGamerulesFunctionPre(...)
    return SparkMod.HookGamerulesClassFunctionPre("Gamerules", ...)
end

function SparkMod.HookGamerulesFunction(...)
    return SparkMod.HookGamerulesClassFunction("Gamerules", ...)
end

function SparkMod.HookNS2GamerulesFunctionPre(...)
    local hook = SparkMod.HookGamerulesClassFunctionPre("NS2Gamerules", ...)
    
    hook.optional = true
    SparkMod.optional_class_hooks.NS2Gamerules = SparkMod.optional_class_hooks.NS2Gamerules or { }
    table.insert(SparkMod.optional_class_hooks.NS2Gamerules, hook)
    
    return hook
end

function SparkMod.HookNS2GamerulesFunction(...)
    local hook = SparkMod.HookGamerulesClassFunction("NS2Gamerules", ...)
    
    hook.optional = true
    SparkMod.optional_class_hooks.NS2Gamerules = SparkMod.optional_class_hooks.NS2Gamerules or { }
    table.insert(SparkMod.optional_class_hooks.NS2Gamerules, hook)

    return hook
end

-- Checks if a function has already been hooked by SparkMod
function SparkMod.IsFunctionHooked(hook_name, hook_type)
    if not hook_type then hook_type = "post" end
    
    for _, hook_info in ipairs(Plugin.hooked_functions) do
        if hook_info.name == hook_name and hook_info.type == hook_type then
            return true
        end
    end
    
    return false
end

-- Internal
function SparkMod._HookFunctionPre(...)
    local hook = SparkMod.HookFunctionPre(...)
    SparkMod._HookFunctionEventPre(hook)
end

-- Internal
function SparkMod._HookFunction(...)
    local hook = SparkMod.HookFunction(...)
    SparkMod._HookFunctionEvent(hook)
end

-- Internal
function SparkMod._HookFunctionHook(hook)
    if hook.type == "pre" then
        SparkMod._HookFunctionEventPre(hook)
    else
        SparkMod._HookFunctionEvent(hook)
    end
end

-- Internal
function SparkMod._ActivateFunctionHook(hook)
    if hook.active then
        return false
    end

    hook.active = true

    if not hook.optional or SparkMod.is_optional_class_hooked[hook.class_name] then
        SparkMod._HookFunctionHook(hook)
    end

    return true
end

-- Internal
function SparkMod._HookOptionalClassFunctions(class_name)
    local optional_hooks = SparkMod.optional_class_hooks[class_name]
    if optional_hooks then
        if SparkMod.is_optional_class_hooked[class_name] then
            return false
        end

        SparkMod.is_optional_class_hooked[class_name] = true

        for _, hook in ipairs(optional_hooks) do
            if hook.active then
                SparkMod._HookFunctionHook(hook)
            end
        end

        return true
    end

    return false
end

-- Injects a function into the scope of other functions so that you can use locals they reference
-- @func any number of functions referencing locals you want to use
-- @param ?int|string function to share scope with other functions, will not be called if passed as a string
function SparkMod.InjectIntoScope(...)
    local scope_functions = {...}
    local inject_function = table.remove(scope_functions)

    local metatable = {
        __index = function(_, name)
            for _, scope_function in ipairs(scope_functions) do
                local i = 1
                local key, value = debug.getupvalue(scope_function, i)
                while key do
                    if key == name then
                        return value
                    end
                    i = i + 1
                    key, value = debug.getupvalue(scope_function, i)
                end
            end
            return getfenv()[name]
        end,
        __newindex = function(_, name, set_value)
            for _, scope_function in ipairs(scope_functions) do
                local i = 1
                local key, value = debug.getupvalue(scope_function, i)
                while key do
                    if key == name then
                        debug.setupvalue(scope_function, i, set_value)
                        return
                    end
                    i = i + 1
                    key, value = debug.getupvalue(scope_function, i)
                end
            end
            getfenv()[name] = set_value
        end
    }

    local env = setmetatable({ }, metatable)

    if type(inject_function) == "function" then
        setfenv(inject_function, env)

        inject_function()
    else
        setfenv(_G[inject_function], env)
    end
end