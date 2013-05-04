-- SparkMod core extensions

-- Table
function table.dup(tbl, depth)
    if type(tbl) ~= "table" then
        return tbl
    end
    depth = depth or 0
    local new_table = {}
    for key, value in pairs(tbl) do
        new_table[key] = type(value) == "table" and depth ~= 1 and table.dup(value, depth-1) or value
    end
    return new_table
end

function table.map(tbl, callback_or_index)
    local map_type = type(callback_or_index)
    local new_table = { }

    for index, value in pairs(tbl) do
        if map_type == "function" then
            new_table[index] = callback_or_index(index, value)
        else
            new_table[index] = value[callback_or_index]
        end
    end

    return new_table
end

function table.select(tbl, callback_or_index)
    local map_type = type(callback_or_index)
    local new_table = { }

    for index, value in pairs(tbl) do
        if map_type == "function" then
            if callback_or_index(index, value) then
                new_table[index] = value
            end
        else
            if value[callback_or_index] then
                new_table[index] = value[callback_or_index]
            end
        end
    end

    return new_table
end

function table.reject(tbl, callback_or_index)
    local map_type = type(callback_or_index)
    local new_table = { }

    for index, value in pairs(tbl) do
        if map_type == "function" then
            if not callback_or_index(index, value) then
                new_table[index] = value
            end
        else
            if not value[callback_or_index] then
                new_table[index] = value[callback_or_index]
            end
        end
    end

    return new_table
end

function table.merge(target, ...)
    target = target or { }
    for i = 1, select('#', ...) do
        for key, value in pairs(select(i, ...)) do
            if type(target[key]) == "table" and type(value) == "table" then
                table.merge(target[key], value)
            else
                target[key] = value
            end
        end
    end
    return target
end

function table.merged(...)
    local new_table = { }
    for i = 1, select('#', ...) do
        for key, value in pairs(select(i, ...)) do
            if type(new_table[key]) == "table" and type(value) == "table" then
                new_table[key] = table.merged(new_table[key], value)
            else
                new_table[key] = value
            end
        end
    end
    return new_table
end

function table.imerged(...)
    local new_table = { }
    for i = 1, select('#', ...) do
        for i, value in ipairs(select(i, ...)) do
            if not table.contains(new_table, value) then
                table.insert(new_table, value)
            end
        end
    end
    return new_table
end

function table.eq(t1, t2)
    if t1 == t2 then
        return true
    end

    local t1_type = type(t1)
    local t2_type = type(t2)

    if t1_type ~= t2_type then
        return false
    end

    if t1_type ~= 'table' and t2_type ~= 'table' then 
        return t1 == t2
    end
    
    for index, value in pairs(t1) do
        if t2[index] == nil or not table.eq(value, t2[index]) then
            return false
        end
    end

    for index, value in pairs(t2) do
        if t1[index] == nil or not table.eq(value, t1[index]) then
            return false
        end
    end

    return true
end

function table.contains(tbl, element)
    for _, value in pairs(tbl) do
        if value == element then
            return true
        end
    end
    return false
end

function table.size(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function table.keys(tbl)
    local keys = { }
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

function table.to_sentence(tbl, downcase)
    local key_count = table.countkeys(tbl)
    local sentence = ""
    for i, value in pairs(tbl) do
        if #sentence > 0 then
            sentence = sentence .. (i == key_count and ' and ' or ', ')
        end
        sentence = sentence .. (downcase and value:lower() or value)
    end
    return sentence
end

function table.stringify(value, indent)
    local inline = indent and indent < 0
    indent = indent and indent < 0 and 0 or indent or 1

    local spaces = inline and "" or string.rep(" ", (indent-1)*4)
    
    if not inline then
        local inline_string = Stringify(value, -1)
        if #spaces + #inline_string < 58 then
            return inline_string
        end
    end

    local result = inline and "{ " or "{\n"
    local key_count = table.countkeys(value)

    local i = 1
    for k, v in pairs(value) do
        local ending = inline and " " or "\n"
        if i < key_count then ending = "," .. ending end
        if type(k) == "string" then
            result = ("%s%s%s = %s%s"):format(result, (" "):rep(indent*4), k, Stringify(v, indent+1), ending)
        else
            result = ("%s%s%s%s"):format(result, (" "):rep(indent*4), Stringify(v, indent+1), ending)
        end
        i = i + 1
    end

    if indent == 1 and #result < 58 then
        return ("{ %s }"):format(result:sub(3))
    end

    return ("%s%s}"):format(result, spaces)
end

-- String
local string_format = string.format
function string.format(format, ...)
    if type(format) ~= "string" or not format:match("%%[NT]") then
        return string_format(format, ...)
    end

    local args = {...}
    local arg = 1

    for token in format:gmatch "%%%d?%.?%d?%a" do
        local skip_arg_count

        if token == "%N" then
            format = format:gsub("%%N", "%%s", 1)
            
            if type(args[arg]) == "userdata" then
                if args[arg]:isa('Player') then
                    args[arg] = args[arg]:GetName()
                elseif args[arg]:isa('ServerClient') then
                    local player = args[arg]:GetControllingPlayer()
                    if player then
                        args[arg] = player:GetName()
                    else
                        args[arg] = args[arg]:GetUserId()
                    end
                else
                    print(string_format("Invalid object \"%s\" passed for %N, object must be a ServerClient or Player", tostring(args[arg])))
                end
            else
                print(string_format("Invalid object \"%s\" passed for %N, object must be a ServerClient or Player", type(args[arg])))
            end
        elseif token == "%T" then
            if not translations then
                error("No translations found for current scope")
            end

            local phrase = args[arg]
            if not phrase then
                error("Translation phrase argument missing")
            end

            local client_or_language = args[arg+1]
            if not client_or_language then
                error("No translation client or language given")
            end

            local language
            if client_or_language:isa('ServerClient') then
                language = SparkMod.GetClientLanguage(client_or_language)
            elseif client_or_language:isa('Player') then
                language = SparkMod.GetClientLanguage(client_or_language:GetClient())
            elseif type(client_or_language) == "string" then
                if client_or_language ~= "default" then
                    language = client_or_language
                end
            end

            language = language or SparkMod.config.default_language

            local phrases = translations[language]
            if not phrases then
                phrases = translations[SparkMod.config.default_language]
                if not phrases then
                    error("Translation phrases for language not found: " .. language)
                end
            end

            local translation = phrases[phrase]
            if not translation then
                error("Translation phrase not found: " .. phrase .. " (" .. language .. ")")
            end

            translation = translation:gsub("%%%d?%.?%d?%a", function(token) return token:gsub("%%", "%%%%") end)
            format = format:gsub("%%T", translation, 1)

            table.remove(args, arg)
            table.remove(args, arg)

            skip_arg_count = 0
            for _ in string.gmatch(translation, "%%%d?%.?%d?%a") do
                skip_arg_count = skip_arg_count + 1
            end
        end

        arg = arg + (skip_arg_count or 1)
    end

    return string_format(format, unpack(args))
end

function string.starts(str, format, ...)
    local compare = select('#', ...) > 0 and string.format(format, ...) or format
    return string.sub(str, 1, #compare) == compare
end

function string.ends(str, format, ...)
    local compare = select('#', ...) > 0 and string.format(format, ...) or format
    return compare == '' or string.sub(str, -#compare) == compare
end

function string.underscore(str)
    return string.lower(str:gsub("([a-z])([A-Z])", function(a, b) return string.format("%s_%s", a, b) end))
end

function string.camelize(str)
    output = str:gsub("([a-z])_([a-z])", function(a, b) return string.format("%s%s", a, string.upper(b)) end)
    return output:gsub("^[a-z]", function(first_char) return string.upper(first_char) end)
end

function string.escape_pattern(str)
    return str:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1'):gsub('%z','%%z')
end

local json_encode = json.encode
function json.encode(data, options)
    if options and options.line_up then
        options.indent = true
    end

    local json_string = json_encode(data, options)

    if not options or not options.line_up then
        return json_string
    end

    local lines = { }    
    local furthest_pos = 0

    for line in json_string:gmatch("[^\n]+") do
        table.insert(lines, line)

        local pos = line:find(":")        
        if pos and pos > furthest_pos then
            furthest_pos = pos
        end
    end

    local value_pos = math.ceil(furthest_pos / 4) * 4

    for i, line in ipairs(lines) do
        local key, value = line:match("(%b\"\"):%s*([^\n]+)")
        if key then
            local key_length = #key + 5
            local format = "    %s:%" .. value_pos - key_length .. "s%s"
            lines[i] = string.format(format, key, " ", value)
        elseif i == #lines then
            lines[i] = "}"
        end
    end
  
    return table.concat(lines, "\n")
end