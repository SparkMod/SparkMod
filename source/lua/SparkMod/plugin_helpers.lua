--- SparkMod server plugin helpers.
-- These helpers are only available to server plugins

--- Formats a string, supports %t for context based translations
-- @string format a string to be formatted
-- @param[opt] ... any arguments to be formatted
function Format(format, ...)
    if type(format) ~= "string" or not format:match("%%t") then
        return format:format(...)
    end

    local language = _reply_info and SparkMod.GetClientLanguage(_reply_info.client) or SparkMod.config.default_language

    local args = {...}
    local arg = 1

    for token in format:gmatch "%%%d?%.?%d?%a" do
        local skip_arg_count

        if token == "%t" then
            if not translations then
                error("No translations found for current scope")
            end

            local phrase = args[arg]
            if not phrase then
                error("Translation phrase argument missing")
            end

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
            format = format:gsub("%%t", translation, 1)

            table.remove(args, arg)

            skip_arg_count = 0
            for _ in string.gmatch(translation, "%%%d?%.?%d?%a") do
                skip_arg_count = skip_arg_count + 1
            end
        end

        arg = arg + (skip_arg_count or 0)
    end

    return format:format(unpack(args))
end

--- Send a chat message to all players
-- @string format string to format before sending
-- @param[opt] ... any number of format arguments
function PrintToChatAll(format, ...)
    local message = Format(format, ...):sub(1, kMaxChatLength)
    Puts("Notification: %s", message)
    local chat_message = BuildChatMessage(false, SparkMod.config.notification_from, -1, kTeamReadyRoom, kNeutralTeamType, message)
    SparkMod.Schedule(Server.SendNetworkMessage, "Chat", chat_message, true)
end

--- Send a private chat message to a client or player
-- @target[opt] target the target that the message will be sent to
-- @string format string to format before sending
-- @param[opt] ... any number of format arguments
function PrintToChat(target, format, ...)
    local client, player
    if target:isa('Player') then
        player = target
        client = player:GetClient()
    else
        client = target
        player = client:GetControllingPlayer()
    end
    if client and not client:GetIsVirtual() then
        local message = Format(format, ...):sub(1, kMaxChatLength)
        local chat_message = BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, message)
        SparkMod.Schedule(Server.SendNetworkMessage, player, "Chat", chat_message, true)
    end
end

--- Send a private message to a server admins console
-- @client client the client to send the message to
-- @string format string to format before sending
-- @param ... any number of format arguments
function SendToAdmin(client, ...)
    SendToAdmin(client, Format(...))
end

--- Send a reply from a command or chat message callback
-- @string format string to format before sending
-- @param[opt] ... any number of format arguments
function SendReply(...)
    assert(_reply_info, "You can only use SendReply from inside a command or chat message callback")
    assert(self[_reply_info.method], "Unknown reply method is set: " .. _reply_info.method or "nil")
    self[_reply_info.method](_reply_info.client, ...)
end

--- Send a reply from a command or chat message callback and stop processing the command
-- @string format string to format before sending
-- @param[opt] ... any number of format arguments
function SendError(...)
    assert(_reply_info, "You can only use SendError from inside a command or chat message callback")
    assert(self[_reply_info.method], "Unknown reply method is set: " .. _reply_info.method or "nil")

    if _reply_info.client then
        self[_reply_info.method](_reply_info.client, ...)
    else
        Puts("[SM] %s", Format(...))
    end

    error({ type = "return" })
end

--- Gets a specific argument from a command or chat message callback
-- @int arg_number argument number starting from 1
-- @treturn string an argument that was entered after the command
function GetCmdArg(arg_number)
    assert(_command_args, "You can only use GetCmdArg from inside a command or chat message callback")
    return _command_args[arg_number]
end

--- Gets the full argument string from a command or chat message callback
-- @treturn string all arguments that were entered after the command
function GetCmdArgString()
    assert(_command_arg_string, "You can only use GetCmdArgString from inside a command or chat message callback")
    return _command_arg_string
end

--- Get a table of players
-- @treturn table a table containing all Player entities
function GetPlayers()
    return EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
end

--- Loops through each player
-- @func callback a callback which will be called for each player
function EachPlayer(callback)
    local players = GetPlayers()

    for i = 1, #players do
        local player = players[i]
        callback(player)     
    end
end

--- Loops through each real player
-- @func callback a callback which will be called for each real player
function EachRealPlayer(callback)
    for client in clients do
        callback(client:GetControllingPlayer())
    end
end

--- Loops through each client
-- @func callback a callback which will be called for each client
function EachClient(callback)
    local players = GetPlayers()

    for i = 1, #players do
        local client = players[i]:GetClient()
        if client then
            callback(player)
        end
    end
end

--- Loops through each real client
-- @func callback a callback which will be called for each real client
function EachRealClient(callback)
    local players = GetPlayers()

    for i = 1, #players do
        local client = players[i]:GetClient()
        if client and not client:GetIsVirtual() then
            callback(client)
        end
    end
end

--- Finds a client matching the given steam id
-- @int steam_id a steam id of a connected client
-- @treturn ServerClient the connected client who the steam id belongs to
function GetClientFromSteamId(steam_id)
    assert(type(steam_id) == "number")    
    return SparkMod.connected_steam_ids[steam_id]
end

--- Finds a player matching the given steam id
-- @int steam_id a steam id of a connected player
-- @treturn ServerClient the connected player who the steam id belongs to
function GetPlayerFromSteamId(steam_id)
    local client = GetClientFromSteamId(steam_id)
    return client and client:GetControllingPlayer()
end

--- Find all players whos name includes the partial name
-- @string partial_name a partial name of a connected player
-- @treturn table all players whos names contain the partial name
function GetPlayersMatchingName(partial_name)
    local name = string.lower(partial_name)
    local matches = { }

    EachPlayer(function(player)
        if string.find(string.lower(player:GetName()), name) then
            table.insert(matches, player)
        end
    end)

    return matches
end

--- Find a single connected player matching a partial name or returns with an error message.
-- If there are are multiple or no matches, an error message will be sent to
-- the client and the command will not be processed any further.
-- @string partial_name a partial name of a connected player
-- @bool allow_none if true, return nil and continus processing the command if there are no matches
function FindPlayerMatchingName(partial_name, allow_none)
    assert(SendError ~= nil, "FindPlayerMatchingName() may only be used inside a command or chat message callback!")

    local matches = GetPlayersMatchingName(partial_name)
    
    if #matches == 0 and not allow_none then
        SendError("There are no players matching '%s' in game.", partial_name)
    elseif #matches > 1 then
        SendError("There are %d players matching '%s' in game, try something more unique.", #matches, partial_name)
    end

    return matches[1]
end

--- Returns a client for a client or player
-- @target target the target client or player
-- @treturn ServerClient the client associated with the target
function GetClient(target)
    if target:isa("ServerClient") then
        return target
    elseif target:isa("Player") then
        return target:GetClient()
    else
        error("Unexpected " .. type(target) .. ". This function expects a client or player.")
    end
end

--- Returns a player for a client or player
-- @target target the target client or player
-- @treturn Player the client associated with the target
function GetPlayer(target)
    if target:isa("ServerClient") then
        return target:GetControllingPlayer()
    elseif target:isa("Player") then
        return target
    else
        error("Unexpected " .. type(target) .. ". This function expects a client or player.")
    end
end

--- Gets the current language set for a client, defaults to the default language for the server
-- @function GetClientLanguage
-- @client client the client whos language you want to get
-- @treturn string the language the client has set or the servers default language
GetClientLanguage = SparkMod.GetClientLanguage

--- Checks if a client is running SparkMod client-side
-- @function IsClientEnabled
-- @client client the target client
-- @treturn boolean true if the clients game is running SparkMod
IsClientEnabled = SparkMod.IsClientEnabled

--- Returns the targets current team index
-- @target target the target client or player
-- @treturn number the targets current team number
function GetClientTeam(target)
    return GetPlayer(target):GetTeamNumber()
end

--- Returns a lower case NS2 team name for the given team index
-- @int team_index the index of a NS2 team
function GetTeamName(team_index)
    if team_index == kTeamReadyRoom then
        return "ready room"
    elseif team_index == kTeam1Index then
        return kTeam1Type == kMarineTeamType and "marines" or kTeam1Name
    elseif team_index == kTeam2Index then
        return kTeam2Type == kAlienTeamType and "aliens" or kTeam2Name
    elseif team_index == kSpectatorIndex then
        return "spectator"
    else
        return "invalid"
    end
end

--- Joins a target to a team
-- Joins a player to a team and sets clients[client].moving_user_to_team to the
-- team number so that you can allow the join if you are using an OnJoinTeam forward
-- @target target the target client or player
-- @number team_number the team number
function JoinTeam(target, team_number)
    local client = GetClient(target)

    if client then
        clients[client].moving_user_to_team = team_number
    end

    gamerules:JoinTeam(GetPlayer(target), team_number)

    if client then
        clients[client].moving_user_to_team = nil
    end
end

--- Joins a target to a random team
-- @target target the target client or player
function JoinRandomTeam(target)
    _G.JoinRandomTeam(GetPlayer(target))
end

--- Gets a target current origin
-- @target target the target client or player
-- @treturn table a vector containing the current origin of the target
function GetClientOrigin(target)
    return GetPlayer(target):GetOrigin()
end

--- Gets a clients tech id
-- @target target the target client or player
-- @treturn number the targets tech id
function GetClientTechId(target)
    local player = GetPlayer(target)
    return player and player:GetIsAlive() and player:GetTechId()
end

--- Checks if the target is still on the server
-- @target target the target client or player
-- @treturn boolean true if the target is still on the server
function IsClientInGame(target)
    assert(type(target) == "userdata", "IsClientInGame must be passed a ServerClient or Player object")

    local succeeded, err = pcall(function() target:isa("Player") end)
    if not succeeded then
        if not err:match("Attempt to access an object that no longer exists %(was type [^%)]+%)$") then
            error(err)
        end
    end

    return succeeded
end

--- Checks if a player is alive
-- @target target the target client or player
-- @treturn boolean true if the target is alive
function IsClientAlive(target)
    local player = GetPlayer(target)
    return player and player:GetIsAlive()
end

--- SourceMod compatible alias for IsClientAlive
-- @function IsPlayerAlive
-- @target target the target client or player
-- @treturn true if the target is alive
IsPlayerAlive = IsClientAlive

--- Respawns an alive target in a nearby location which is not near a resource point
-- @target target the target client or player
-- @number[opt=8] max_range
function RespawnClientNearby(target, max_range)
    if not IsClientAlive(target) then
        return false
    end

    max_range = max_range or 8

    local origin = GetClientOrigin(target)
    local tech_id = GetClientTechId(target) or kTechId.Marine
    local extents = LookupTechData(tech_id, kTechDataMaxExtents)
    local height, radius = GetTraceCapsuleFromExtents(extents)
    
    for i = 1, 99 do
        local spawn_point = GetRandomSpawnForCapsule(height, radius, origin, 3, max_range, EntityFilterAll())
        if spawn_point then
            if GetIsPlacementForTechId(spawn_point, true, tech_id) then
                if #GetEntitiesWithinRange("ResourcePoint", spawn_point, 2) < 1 then
                    SpawnPlayerAtPoint(player, spawn_point)
                    return true
                end
            end
        end
    end

    return false
end

--- Executes a console command on a client
-- @target target the target client or player
-- @string format a string to be formatted
-- @param[opt] ... any arguments to be formatted
function ClientCommand(target, ...)
    return Server.SendCommand(GetPlayer(target), Format(...))
end

--- Sets a cookie for a user from a steam id
-- @function SetUserIdCookie
-- @number user_id the steam id of the user
-- @string cookie_name the name of the cookie
-- @param value the value to set
SetUserIdCookie = SparkMod.SetUserIdCookie

--- Sets a cookie for a connected client
-- @function SetClientCookie
-- @client client the connected client
-- @string cookie_name the name of the cookie
-- @param value the value to set
SetClientCookie = SparkMod.SetClientCookie

--- Gets a raw cookie table for a specific cookie beloning to a user from a steam id
-- @function GetUserIdRawCookie
-- @number user_id the steam id of the user
-- @string cookie_name the name of the cookie
-- @return the cookie value
GetUserIdRawCookie = SparkMod.GetUserIdRawCookie

--- Gets a cookie value for a user from a steam id
-- @function GetUserIdCookie
-- @number user_id the steam id of the user
-- @string cookie_name the name of the cookie
-- @return the cookie value
GetUserIdCookie = SparkMod.GetUserIdCookie

--- Gets a cookie value for a connected client
-- @function GetClientCookie
-- @client client the connected client
-- @string cookie_name the name of the cookie
-- @return the cookie value
GetClientCookie = SparkMod.GetClientCookie

--- Gets the time a cookies value was last changed for a user from a steam id
-- @function GetClientCookieTime
-- @client client the connected client
-- @string cookie_name the name of the cookie
-- @treturn float the time that the cookies value last changed
GetClientCookieTime = SparkMod.GetClientCookieTime

-- Internal
function RegisterClientCommand(command_name, callback)                
    Plugin.RegisterClientCommand(command_name)

    client_commands[command_name] = callback

    if command_aliases[command_name] then
        for _, command_alias in ipairs(command_aliases[command_name]) do
            client_commands[command_alias] = callback
        end
    end
end

-- Internal
function RegisterAdminCommand(command_name, callback)                
    Plugin.RegisterAdminCommand(command_name)

    admin_commands[command_name] = callback

    if command_aliases[command_name] then
        for _, command_alias in ipairs(command_aliases[command_name]) do
            admin_commands[command_alias] = callback
        end
    end
end

--- Registers an alias for a registered client or admin command
-- @string command_name the registered command name
-- @string alias_name the name of the alias you want to register
function CommandAlias(command_name, alias_name)
    if client_commands[command_name] then
        RegisterClientCommand(alias_name, client_commands[command_name])
    elseif admin_commands[command_name] then
        RegisterAdminCommand(alias_name, admin_commands[command_name])
    else
        command_aliases[command_name] = command_aliases[command_name] or { }
        table.insert(command_aliases[command_name], alias_name)
    end
end

--- Prints a text message at a specific location of a targets screen
-- @target target the target to send the message to
-- @number x a ratio between 0 and 1.0 representing the x position on the clients screen
-- @number y a ratio between 0 and 1.0 representing the y position on the clients screen
-- @string text the text message you want to display
-- @number duration the amount of seconds the message should be visible for
-- @tab color the RGB color of the text
-- @string[opt] tag a tag to associate with the message which can be used to remove it
function PrintToScreen(target, x, y, text, duration, color, tag)
    SparkMod.PrintToScreen(GetPlayer(target), x, y, text, duration, color, tag)
end

--- Prints a text message at a specific location of all connected players screens
-- @number x a ratio between 0 and 1.0 representing the x position on the clients screen
-- @number y a ratio between 0 and 1.0 representing the y position on the clients screen
-- @string text the text message you want to display
-- @number duration the amount of seconds the message should be visible for
-- @tab color the RGB color of the text
-- @string[opt] tag a tag to associate with the message which can be used to remove it
function PrintToScreenAll(x, y, text, duration, color, tag)
    EachRealPlayer(function(player)
        SparkMod.PrintToScreen(player, x, y, text, duration, color, tag)
    end)    
end

--- Prints a text message to the center of a targets screen
-- @target target the target to send the message to
-- @string format a string to format
-- @param[opt] ... any arguments to format
function PrintCenterText(target, format, ...)
    PrintToScreen(target, 0.5, 0.5, Format(format, ...), 5, { 255, 255, 255 })
end

--- Prints a text message to the center of all connected players screens
-- @string format a string to format
-- @param[opt] ... any arguments to format
function PrintCenterTextAll(format, ...)
    PrintToScreenAll(0.5, 0.5, Format(format, ...), 5, { 255, 255, 255 })
end

--- Counts the number of arguments given
-- @function ArgCount
-- @param ... the arguments to count
-- @treturn number the number of arguments
ArgCount = SparkMod.ArgCount

--- Joins the arguments given together with spaces
-- @function ArgString
-- @param ... the arguments to join
-- @treturn string the arguments given joined together with spaces
ArgString = SparkMod.ArgString