-- SparkMod global utilities

function Puts(format, ...)
    Shared.Message(string.format(format, ...))
end

function SendToAdmin(client, ...)
    ServerAdminPrint(client, string.format(...))
end

function Stringify(value, indent)
    local metatable = getmetatable(value)
    if metatable and type(metatable.__towatch) == "function" then
        local class, members = metatable.__towatch(value)
        return ("%s %s"):format(class, table.stringify(members, indent))
    else
        local value_type = type(value)
        if value_type == "table" then
            return table.stringify(value, indent)
        elseif value_type == "string" then
            return ("\"%s\""):format(value)
        else
            return value == nil and "nil" or tostring(value)
        end
    end
end

function FirstArg(first_arg)
    return first_arg
end

function PackAllValues(...)
    return { count = select('#', ...), ... }
end

function UnpackAllValues(tbl)
    return unpack(tbl, 1, tbl.count) 
end

local function InjectArgHelper(i, a, n, b, ...)
    if n == i then
        if n == 0 then
            return a
        else
            return a, InjectArgHelper(nil, a, n, b, ...)
        end
    elseif n == (i and 0 or 1) then
        return b
    else
        return b, InjectArgHelper(i, a, n-1, ...)
    end
end

function InjectArg(i, a, ...)
    local arg_count = select('#', ...)
    return InjectArgHelper(arg_count-i+1, a, arg_count, ...)
end

local function CoXpCallHelper(co, succeeded, ...)
    local ret = select(1, ...)
    if not succeeded and ret and ret.type ~= "return" then
        return nil, { message = ret, traceback = debug.traceback(co, select(2, ...)) }
    end
    return co, ...
end

function CoXpCall(func_or_co, ...)
    local co
    if type(func_or_co) == "function" then
        co = coroutine.create(func_or_co)
    elseif type(func_or_co) == "thread" then
        co = func_or_co
    else
        error("Argument #1 (" .. type(func_or_co) .. ") must be a function or coroutine")
    end
    return CoXpCallHelper(co, coroutine.resume(co, ...))
end

function GlobToPattern(glob)
    local p = "^"  -- pattern being built
    local i = 0    -- index in g
    local c        -- char at index i in glob.

    local function unescape()
        if c == '\\' then
            i = i + 1
            c = glob:sub(i, i)

            if c == '' then
                p = '[^]'
                return false
            end
        end

        return true
    end

    local function escape(char)
        return char:match("^%w$") and char or '%' .. char
    end

    local function charset_end()
        while 1 do
            if c == '' then
                p = '[^]'
                return false
            elseif c == ']' then
                p = p .. ']'
                break
            else
                if not unescape() then
                    break
                end

                local c1 = c
                i = i + 1
                c = glob:sub(i, i)

                if c == '' then
                    p = '[^]'
                    return false
                elseif c == '-' then
                    i = i + 1
                    c = glob:sub(i, i)

                    if c == '' then
                        p = '[^]'
                        return false
                    elseif c == ']' then
                        p = p .. escape(c1) .. '%-]'
                        break
                    else
                        if not unescape() then
                            break
                        end
                        p = p .. escape(c1) .. '-' .. escape(c)
                    end
                elseif c == ']' then
                    p = p .. escape(c1) .. ']'
                    break
                else
                    p = p .. escape(c1)
                    i = i - 1
                end
            end

            i = i + 1
            c = glob:sub(i, i)
        end

        return true
    end

    local function charset()
        i = i + 1
        c = glob:sub(i, i)

        if c == '' or c == ']' then
            p = '[^]'
            return false
        elseif c == '^' or c == '!' then
            i = i + 1
            c = glob:sub(i, i)

            if c ~= ']' then
                p = p .. '[^'
                if not charset_end() then
                    return false
                end
            end
        else
            p = p .. '['

            if not charset_end() then
                return false
            end
        end

        return true
    end

    while 1 do
        i = i + 1
        c = glob:sub(i, i)

        if c == '' then
            p = p .. '$'
            break
        elseif c == '?' then
            p = p .. '.'
        elseif c == '*' then
            if glob:sub(i+1, i+2) == "*/" then
                p = p .. '.+%/'
                i = i + 2
            else
                p = p .. '[^%/]+'
            end
        elseif c == '[' then
            if not charset() then
                break
            end
        elseif c == '\\' then
            i = i + 1
            c = glob:sub(i, i)

            if c == '' then
                p = p .. '\\$'
                break
            end

            p = p .. escape(c)
        else
            p = p .. escape(c)
        end
    end

    return p
end