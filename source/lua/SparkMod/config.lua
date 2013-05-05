-- SparkMod config

Script.Load "lua/SparkMod/default_config.lua"

SparkMod.config = SparkMod.config or { admin = { }, languages = { "en" } }
SparkMod.config = table.merged(SparkMod.shared_default_config, SparkMod.config)

if not Server then return end

SparkMod.config_metadata = { }

local loaded_config

--TODO: implement config metadata support once IO engine bug has been fixed
local function InsertConfigMetadata(file_name, json_string)
    -- if file_name == "SparkMod.json" then
    --     local max_line_length = 0
    --     for line in json_string:gmatch("[^\n]+") do
    --         if #line > max_line_length then
    --             max_line_length = #line
    --         end
    --     end

    --     local comment_pos = math.ceil(max_line_length / 4) * 4

    --     local lines = { }
    --     for line in json_string:gmatch("[^\n]+") do
    --         local key, value = line:match("^%s+\"([^\"]+)\": ([^\n]+)")
    --         if key then
    --             local comment = SparkMod.config_metadata[key]
    --             if comment then
    --                 if value:ends(",") then value = value:sub(1, -2) end
    --                 if value == "[  ]" then value = "[ ]" end
    --                 local fmt = ("%s%" .. (comment_pos - #line) .. "s-- %s (default: %s)")
    --                 line = fmt:format(line, " ", comment, 1, tostring(value))
    --             end
    --         end
    --         table.insert(lines, line)
    --     end

    --     return table.concat(lines, "\n")
    -- end
    return json_string
end

local function WriteDefaultConfigFile(file_name, data)
    local file_path = "config://" .. file_name
    local file = io.open(file_path, "r")
    if not file then    
        file = io.open(file_path, "w+")
        if not file then return end
        Puts("[SM] Creating default config file: %s", file_path)
        file:write(InsertConfigMetadata(file_name, json.encode(data, { indent = true })))
    end    
    io.close(file)
end


local function LoadConfigFile(file_name)    
    local file = io.open("config://" .. file_name, "r")
    if file then    
        local config, _, err = json.decode(file:read("*all"))
        if err then
            Puts("Error while opening %s: %s", file_name, err)
        end
        io.close(file)
        return config
    end
end

local function SaveConfigFile(file_name, data)    
    local file = io.open("config://" .. file_name, "w+")    
    if file then
        file:write(InsertConfigMetadata(file_name, json.encode(data, { indent = true })))
        io.close(file)
        return true
    end
    return false
end

local function WriteDefaultPhrasesFile(file_name, data)
    local file_path = "config://" .. file_name
    local file = io.open(file_path, "r")
    if not file then    
        file = io.open(file_path, "w+")
        if not file then return end
        Puts("[SM] Creating default phrases file: %s", file_path)
        local raw_json = json.encode(data, { line_up = true })
        file:write(raw_json)
    end    
    io.close(file)    
end

local function SavePhrasesFile(file_name, data)    
    local file = io.open(file_name, "w+")    
    if file then    
        file:write(json.encode(data, { line_up = true }))
        io.close(file)        
    end
end

local function GenerateDefaultServerAdminsConfig()
    local admin_config = {
        groups = {
            admin_group = { commands = { }, type = "disallowed" },
            mod_group = { commands = { "sv_reset", "sv_ban" }, type = "allowed" }
        },
        users = {
            NsPlayer = { id = 10000001, groups = { "admin_group" } }
        }
    }
    
    WriteDefaultConfigFile("ServerAdmin.json", admin_config)
    
    return admin_config
end

local function InitializeConfig(file_name, default_config)
    local config_from_file = LoadConfigFile(file_name)
    local config = config_from_file or default_config
    
    if config_from_file then
        local merged_config = table.merged(default_config, config_from_file)
        
        if not table.eq(merged_config, config_from_file) then
            SaveConfigFile(file_name, merged_config)
            return merged_config
        end
    else
        WriteDefaultConfigFile(file_name, default_config)
    end

    return config
end

function SparkMod.LoadConfig()
    local default_admins_config = GenerateDefaultServerAdminsConfig()
    table.merge(SparkMod.config.admin, LoadConfigFile("ServerAdmin.json") or default_admins_config)

    loaded_config = InitializeConfig("SparkMod.json", SparkMod.default_config)
    table.merge(SparkMod.config, loaded_config)

    Plugin.config = SparkMod.config
end

function SparkMod.SaveConfig()
    local config_data = table.reject(SparkMod.config, function(key, value)
        -- Config values are only saved if they are in the default config or were already in the config file
        return SparkMod.default_config[key] == nil and loaded_config[key] == nil
    end)
    SaveConfigFile("SparkMod.json", config_data)
    loaded_config = config_data
end

function SparkMod.LoadPluginConfig(plugin)
    local config_path = ("sparkmod/configs/%s.json"):format(plugin.plugin_name)
    
    plugin.config = { }
    
    if plugin._default_config then
        plugin.config = InitializeConfig(config_path, plugin._default_config)
    end

    local phrases_path = ("sparkmod/translations/%s.phrases.json"):format(plugin.plugin_name)

    plugin.translations = { en = { } }

    if plugin.default_phrases then
        table.merge(plugin.translations.en, LoadConfigFile(phrases_path) or plugin.default_phrases)
        WriteDefaultPhrasesFile(phrases_path, plugin.default_phrases)
    end

    local plugin_phrase_paths = SparkMod.FindMatchingFiles("config://sparkmod/translations/**/%s.phrases.json", plugin.plugin_name)

    if #plugin_phrase_paths > 0 then
        for _, phrases_path in ipairs(plugin_phrase_paths) do
            local language = phrases_path:match "translations/([^/]+)/.+%.phrases%.json"
            if language then
                local phrases = LoadConfigFile(phrases_path)
                if phrases then
                    table.merge(plugin.translations[language], phrases)

                    if not SparkMod.config.disabled_languages or not table.contains(SparkMod.config.disabled_languages, language) then
                        if not table.contains(SparkMod.config.languages, language) then
                            table.insert(SparkMod.config.languages, language)
                        end
                    end
                else
                    Puts("[SM] Warning: Unable to load phrases file: %s", phrases_path)
                end
            end
        end
    end
end

function SparkMod.SavePluginConfig(plugin)
    local config_path = ("sparkmod/configs/%s.json"):format(plugin.plugin_name)
    if not SaveConfigFile(config_path, plugin.config) then
        Puts("[SM] Error: Unable to write to config file: %s", config_path)
    end
end

function SparkMod.ParseDefaultConfigMetadata(plugin)
    local file_path
    if plugin then
        --TODO: support for plugin default config metadata
    else
        file_path = "lua/SparkMod/default_config.lua"
    end

    local contents
    if file_path then
        local file = io.open("lua/SparkMod/default_config.lua", "r")
        contents = file:read("*all")
        file:close()
    else
        Puts("[SM] Unable to load metadata from file: %s", file_path)
        return false
    end

    for line in contents:gmatch("[^\n]+") do
        local key, value = line:match("^    (%S+)%s+=%s+([^\n]+)")
        if key then
            local comment = value:match("%s+%-%- ([^\n]+)")
            if comment then
                SparkMod.config_metadata[key] = comment
            end
        end
    end

    return true
end

function SparkMod.CanGroupRunCommand(group_name, command)
    local group = SparkMod.config.admin.groups[group_name]
    if not group then
        Puts("[SM] Warning: Invalid group_name referenced: " .. group_name)
        return false
    end
    
    local is_allowed = false
    for i = 1, #group.commands do    
        if group.commands[i] == command then        
            is_allowed = true
            break
        end
    end
    
    if group.type == "disallowed" then
        is_allowed = not is_allowed
    end

    return is_allowed
end

function SparkMod.CanClientRunCommand(client, command)
    if not client then return true end

    local steam_id = client:GetUserId()
    for name, user in pairs(SparkMod.config.admin.users) do    
        if user.id == steam_id then
            for i = 1, #user.groups do
                local group_name = user.groups[i]
                if SparkMod.CanGroupRunCommand(group_name, command) then
                    return true
                end                
            end
            break
        end        
    end

    return false
end

function SparkMod.IsClientInGroup(client, group_name)
    local steam_id = client:GetUserId()
    for name, user in pairs(SparkMod.config.admin.users) do    
        if user.id == steam_id then
            for i = 1, #user.groups do
                local current_group = user.groups[i]
                if current_group == group_name then
                    return true
                end
            end
        end
    end
end

-- Persistent storage
SparkMod.store = SparkMod.store or { }

function SparkMod.SavePersistentStore()    
    local file = io.open("config://sparkmod/data/storage.json", "w+")
    if file then    
        file:write(json.encode(SparkMod.store))
        file:close()
        return true
    else
        Puts("[SM] Error: Unable to save persistent storage, cannot write to sparkmod/data/storage.json")
    end

    return false
end

function SparkMod.LoadPersistentStore()
    local store = LoadConfigFile("sparkmod/data/storage.json")
    if store then
        SparkMod.store = store
    end
end

-- Cookies
SparkMod.cookies = SparkMod.cookies or { }
SparkMod.cookies_version = 0

function SparkMod.SaveCookies()
    SparkMod.cookies_version = SparkMod.cookies_version + 1
    
    local file = io.open("config://sparkmod/data/cookies.json", "w+")
    if file then    
        file:write(json.encode(SparkMod.cookies))
        file:close()

        file = io.open("config://sparkmod/data/cookies.version", "w+")    
        if file then
            file:write(SparkMod.cookies_version)
            file:close()
            
            return true
        else
            Puts("[SM] Error: Unable to save cookies, cannot write to sparkmod/data/cookies.json")
        end
    end

    return false
end

-- Temporary workaround for the lack of a native mtime function
local function GetCookiesVersion()
    local file_path = "config://sparkmod/data/cookies.version"
    
    local file = io.open(file_path, "r")
    if file then
        local raw_version = file:read("*all")
        file:close()
        return tonumber(raw_version)
    end

    return 0
end

function SparkMod.LoadCookies()
    local cookies = LoadConfigFile("sparkmod/data/cookies.json")
    if cookies then
        SparkMod.cookies = cookies
        SparkMod.cookies_version = GetCookiesVersion()
    else
        WriteDefaultConfigFile("sparkmod/data/cookies.json", { })
    end
end

function SparkMod.RefreshCookies()
    if SparkMod.cookies_version < GetCookiesVersion() then
        SparkMod.LoadCookies()
        return true
    end

    return false
end