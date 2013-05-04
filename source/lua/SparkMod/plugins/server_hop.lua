info = {
    name = "SparkMod Server Hop",
    author = "bawNg",
    description = "Hop between servers using a simple command",
    version = "0.1",
    url = "https://github.com/SparkMod/SparkMod"
}

default_config = {
    hop_delay = 3,
    servers = {
        ["My server name"] = "127.0.0.1:27015"
    }
}

default_phrases = {
    ["No Servers"]          = "There are currently no other servers available",
    ["Invalid Number"]      = "There is no server number %d in the server list",
    ["Invalid Name"]        = "There are no servers matching '%s' in the server list",
    ["Multiple Names"]      = "There are %d servers matching '%s' in the server list, try something more unique",
    ["Available Servers"]   = "Available Servers:",
    ["Server"]              = "%d) %s",
    ["About To Hop"]        = "%N is about to hop to server: %s (%s)"
}

function GetServerCount()
    if not config.servers then
        return 0
    end

    local count = table.countkeys(config.servers)
    
    if count == 1 and config.servers["My server name"] then
        return 0
    end

    return count
end

function FindServerMatchingName(partial_name)
    local matches = { }

    for server_name, server_address in pairs(config.servers) do
        if server_name:lower():match(partial_name) then
            table.insert(matches, server_name)
        end
    end

    if #matches == 0 then
        SendError("[SM] %t", "Invalid Name", partial_name)
    elseif #matches > 1 then
        SendError("[SM] %t", "Multiple Names", #matches, partial_name)
    end

    return matches[1]
end

function OnCommandHop(client, server)
    if GetServerCount() < 1 then
        SendError("[SM] %t", "No Servers")
    end

    if not server then
        SendReply("[SM] %t", "Available Servers", number, server_name)
        
        local number = 1
        for server_name, server_address in pairs(config.servers) do
            SendReply("[SM] %t", "Server", number, server_name)
            number = number + 1
        end

        return
    end

    local server_name
    if server:match("^%d+$") then
        local server_number = tonumber(server)
        local number = 1
        for name, _ in pairs(config.servers) do
            if number == server_number then
                server_name = name
                break
            end
            number = number + 1
        end
        if not server_name then
            SendError("[SM] %t", "Invalid Number", server_name)
        end
    else
        server_name = FindServerMatchingName(server)
    end

    local server_address = config.servers[server_name]

    PrintToChatAll("[SM] %t", "About To Hop", client, server_name, server_address)

    scheduler.In(config.hop_delay, function()
        if not clients[client] then return end
        ClientCommand(client, "connect %s", server_address)
    end)
end

CommandAlias("hop", "servers")