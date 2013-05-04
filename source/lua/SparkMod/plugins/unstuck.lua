info = {
    name = "SparkMod Unstuck",
    author = "bawNg",
    description = "Unstuck functionality for SparkMod",
    version = "0.1",
    url = "https://github.com/SparkMod/SparkMod"
}

default_config = {
    wait_delay = 5,
    repeat_delay = 25
}

default_phrases = {
    ["Already Stuck"]   = "You are already marked as stuck and will be unstuck shortly",
    ["Repeat Delay"]    = "You can only use unstuck once every %d seconds",
    ["Unstuck In"]      = "You will be unstuck in %d seconds",
    ["Moved Since"]     = "You moved since using the unstuck command",
    ["Died Since"]      = "You died and no longer need to be unstuck",
    ["Respawned"]       = "You have been respawned in a new location"
}

function OnClientDeath(client)
    if clients[client].is_stuck then
        clients[client].is_stuck = false
        PrintToChat(client, "[SM] %t", "Died Since")
    end
end

function OnCommandStuck(client)
    local info = clients[client]

    if info.is_stuck then
        SendError("[SM] %t", "Already Stuck")
    elseif info.last_unstuck_at and GetTime() - info.last_unstuck_at < config.repeat_delay then
        SendError("[SM] %t", "Repeat Delay", config.repeat_delay)
    end

    info.is_stuck = true
    info.origin = GetClientOrigin(client)
    info.last_unstuck_at = GetTime()

    SendReply("[SM] %t", "Unstuck In", config.wait_delay)

    scheduler.In(config.wait_delay, function()
        if not clients[client] then return end

        if info.origin == GetClientOrigin(client) then
            info.is_stuck = false
            RespawnClientNearby(client)
            SendReply("[SM] %t", "Unstuck")
        else
            SendReply("[SM] %t", "Moved Since")
        end
    end)
end

CommandAlias("stuck", "unstuck")