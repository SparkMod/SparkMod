-- SparkMod command processing

function SparkMod.ArgCount(...)
    return select('#', ...)
end

function SparkMod.ArgString(...)
    local arg_count = select('#', ...)

    if arg_count == 0 then
        return
    elseif arg_count == 1 then
        return ...
    end

    local output = ""
    
    for i = 1, arg_count do
        if #output > 0 then
            output = output .. " "
        end
        output = output .. select(i, ...)
    end

    return output
end

function SparkMod.ParseCommandArguments(...)
    if select('#', ...) == 0 then
        return { }
    end

    local line = SparkMod.ArgString(...)

    local arguments = { }

    local i = 1
    while i < #line do
        local arg
        local next_space_pos = line:find(' ', i+1)
        
        while 1 do
            arg = next_space_pos and line:sub(i, next_space_pos-1) or line:sub(i)

            if arg then
                if arg:ends('\\') then
                    next_space_pos = line:find(' ', i + #arg + 1)
                    if not next_space_pos then
                        break
                    end
                else
                    arg = arg:gsub('\\\\', '&#92;'):gsub('\\', ''):gsub('&#92;', '\\')
                    break
                end
            else
                break
            end
        end

        if arg and arg:starts('"') then
            local end_pos = line:find('"', next_space_pos)
            arg = line:sub(i+1, end_pos-1)
            i = end_pos + 2
        elseif next_space_pos then
            i = next_space_pos + 1
        end

        table.insert(arguments, arg)

        if not next_space_pos then
            break
        end
    end

    return arguments
end