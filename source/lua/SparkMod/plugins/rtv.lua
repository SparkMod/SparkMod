Requires "map_vote"

info = {
    name = "SparkMod Rock The Vote",
    author = "bawNg",
    description = "Adds rock the vote command",
    version = "0.5",
    url = "https://github.com/SparkMod/SparkMod"
}

default_config = {
    minimum_percentage = 50
}

default_phrases = {
    ["Already Started"] = "There is a map vote already running.",
    ["Already Voted"]   = "You have already voted to RTV.",
    ["Voted"]           = "%N wants to rock the vote. (%d votes, %d required)."
}

started = false

local function NeededVotes()
    return math.ceil(clients.count * (config.minimum_percentage / 100))
end

local function CountVotes()
    return clients.Count(function(info) return info.voted end)
end

local function ClearVotes()
    clients.Each(function(info) info.voted = nil end)
end

-- Votes to change the map
function OnCommandRtv(client)
    if MapVote.starting or MapVote.started or MapVote.complete then
        SendError("%t", "Already Started")
    end

    if clients[client:GetUserId()].voted then         
        SendError("%t", "Already Voted")
    end

    clients[client].voted = true
    
    local vote_count = CountVotes()
    local needed_votes = NeededVotes()

    if vote_count >= needed_votes then
        started = true

        ClearVotes()

        MapVote.requested = true
        MapVote.StartVote()
    else
        PrintToChatAll("%t", "Voted", client, vote_count, needed_votes)
    end
end

CommandAlias("rtv", "rockthevote")