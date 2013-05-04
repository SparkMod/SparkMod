info = {
    name = "SparkMod Map Vote",
    author = "bawNg",
    description = "Adds end of map voting functionality",
    version = "0.5",
    url = "https://github.com/SparkMod/SparkMod"
}

default_config = {
    start_delay = 7,
    include_maps = 7,
    exclude_recent_maps = 3,
    extend_time = 15,
    max_extends = 3,
    end_of_map_vote_delay = 2,
    map_change_delay = 4,
    vote_status_interval = 7,
    vote_duration = 35,
    run_off_enabled = true,
    run_off_percentage = 50,
    run_off_start_delay = 4,
    pregame_status_interval = 6,
    pregame_length = 10
}

default_phrases = {
    ["Start Countdown"] = "%.1f seconds remaining until the game begins...",
    ["Already Started"] = "There is a map vote already running.",
    ["Not Started"]     = "There is currently no map vote running.",
    ["Too Few Maps"]    = "*** Not enough maps in rotation for a vote.",
    ["Starting"]        = "*** Map voting will begin in %s seconds...",
    ["Instructions"]    = "*** You can vote for the map you want by typing vote <map>",
    ["Started"]         = "*** Map voting has started.",
    ["Current Votes"]   = "*** %s votes for %s (type vote %d)",
    ["Map"]             = "*** %d) %s",
    ["Time Left"]       = "*** %.1f seconds are left to vote for a map",
    ["No Winner"]       = "*** Map voting has ended, no map won.",
    ["Runoff"]          = "*** No map got over %d%% votes, a new vote will start in %d seconds.",
    ["Winner"]          = "*** Map voting has ended, %s won with %s votes.",
    ["Extended"]        = "*** Map voting has ended, extending current map for %d minutes.",
    ["Cancelled"]       = "Map vote has been cancelled.",
    ["Invalid Number"]  = "There is no map number %d in the current vote.",
    ["Invalid Name"]    = "There are no maps matching '%s' in the current vote.",
    ["Multiple Names"]  = "There are %d maps matching '%s' in the current vote, try something more unique.",
    ["Already Voted"]   = "You have already voted for that map.",
    ["Voted For"]       = "You voted for %s.",
    ["Next Map"]        = "Next map will be %s.",
    ["Map Time Left"]   = "%.1f minutes remaining."
}

library_name = "MapVote"

requested = false
starting = false
started = false
complete = false
run_off = false

recent_maps = { }
vote_maps = { }

last_pregame_status_at = 0
extend_count = 0

next_map = nil

local function FindVoteMapMatchingName(partial_name)
    local matches = { }

    if vote_maps and #vote_maps > 0 then
        for _, map_name in ipairs(vote_maps) do
            if map_name:lower():match(partial_name) then
                table.insert(matches, map_name)
            end
        end
    end

    if #matches == 0 then
        SendError("%t", "Invalid Name", partial_name)
    elseif #matches > 1 then
        SendError("%t", "Multiple Names", #matches, partial_name)
    end

    return matches[1]
end

local function BuildVoteMaps(...)
    vote_maps = { }

    local arg_count = select('#', ...)
    if arg_count > 0 then
        for i = 1, arg_count do
            table.insert(vote_maps, select(i, ...))
        end

        return true
    end
   
    local maps = { }
    
    local cycle_maps = { }

    local cycle = MapCycle_GetMapCycle().maps
    for _, cycle_map in ipairs(cycle) do
        table.insert(cycle_maps, cycle_map.map)
    end

    if cycle_maps and #cycle_maps > 0 then
        for _, map_name in ipairs(cycle_maps) do
            if not WasMapRecentlyPlayed(map_name) then
                table.insert(maps, map_name)
            end            
        end
    end

    if #maps < config.include_maps then    
        for i = 1, config.include_maps - #maps do
            if recent_maps[i] ~= current_map and table.contains(cycle_maps, recent_maps[i]) then
                table.insert(maps, recent_maps[i])
            end
        end    
    end
    
    if #maps < 1 then
        return false
    end

    for i = 1, config.include_maps do
        if #maps > 0 then
            vote_maps[i] = table.remove(maps, math.random(1, #maps))
        else
            break
        end
    end

    --TODO: finish implementing extend
    -- if extend_count < config.max_extends then
    --     table.insert(vote_maps, "extend " .. current_map)
    -- end

    return true
end

local function CountMapVotes(map_name)
    return clients.Count(function(client) return client.voted_for_map == map_name end)
end

local function DisplayVoteStatus()
    PrintToChatAll("%t", "Time Left", config.vote_duration - (Now() - started_at))

    for i, map_name in ipairs(vote_maps) do
        PrintToChatAll("%t", "Current Votes", CountMapVotes(map_name), map_name, i)
    end
end

function WasMapRecentlyPlayed(map_name)
    return current_map == map_name or table.contains(recent_maps, map_name)
end

function StartVote(...)
    if starting or started or complete then
        return false
    end

    if BuildVoteMaps(...) then
        starting = true

        if run_off then
            PrintToChatAll("%t", "Runoff", config.run_off_percentage, config.run_off_start_delay)

            scheduler.In(config.run_off_start_delay, OnVoteStarted)
        else
            PrintToChatAll("%t", "Starting", config.start_delay)
            PrintToChatAll("%t", "Instructions")

            scheduler.In(config.start_delay, OnVoteStarted)
        end

        return true
    else
        PrintToChatAll("%t", "Too Few Maps")
        return false
    end
end

-- Events
function OnLoaded()
    if config.pregame_length then
        kPregameLength = config.pregame_length
    end
end

function OnMapEnd()
    next_map = nil
    
    table.insert(recent_maps, current_map)

    if #recent_maps > config.exclude_recent_maps then
        table.remove(recent_maps, 1)
    end
end

function OnVoteStarted()
    starting = false
    started = true
    started_at = Now()

    PrintToChatAll("%t", "Started")

    scheduler.Every(config.vote_status_interval, DisplayVoteStatus, "vote_status")
    
    scheduler.In(config.vote_duration, OnVoteEnded)
end

function OnVoteEnded()
    scheduler.Unschedule "vote_status"

    started = false

    local map_votes = { }
    local total_votes = 0

    for _, map_name in ipairs(vote_maps) do
        local votes = CountMapVotes(map_name)
        table.insert(map_votes, { map_name, votes })
        total_votes = total_votes + votes
    end

    table.sort(map_votes, function(a, b) return a[2] > b[2] end)

    local winning_map, winning_votes = map_votes[1][1], map_votes[1][2]

    if not winning_map then
        puts "No map won the vote, will use next map in cycle"
        PrintToChatAll("%t", "No Winner")
        next_map = nil
        complete = true
    else
        local required_votes = total_votes * (config.run_off_percentage / 100)
        if winning_votes <= required_votes then
            puts("Starting a runoff vote for maps: %s and %s", winning_map, map_votes[2][1])
            run_off = true
            StartVote(winning_map, map_votes[2][1])
            return
        end

        if winning_map:starts("extend ") then
            PrintToChatAll("%t", "Extended", config.extend_time)
        else
            PrintToChatAll("%t", "Winner", winning_map, winning_votes)
            next_map = winning_map
            complete = true
        end
    end

    if next_map then
        puts("Changing to next_map: %s", next_map)
        MapCycle_ChangeMap(next_map)
    elseif not requested then
        puts("Changing to next map in cycle")
        MapCycle_CycleMap()
    end

    complete = false
    requested = false
    run_off = false
end

function OnUpdatePregame(time_passed)
    if Shared.GetDevMode() or Shared.GetCheatsEnabled() then
        return
    end

    if game_state == kGameState.PreGame and time_since_game_state_changed < kPregameLength then
        if GetTime() - last_pregame_status_at >= config.pregame_status_interval then
            PrintToChatAll("%t", "Start Countdown", kPregameLength - time_since_game_state_changed)
            last_pregame_status_at = GetTime()
        end
    end
end

function OnSetGameState(state)
    if state == previous_game_state then return end

    if state == kGameState.Team1Won or state == kGameState.Team2Won then
        if MapCycle_TestCycleMap() then
            gamerules.timeToCycleMap = GetTime() + config.map_change_delay
        end
    end
end

function OnPreCanCycleMap()
    if starting or started or complete then
        return false
    end

    if GetTime() < MapCycle_GetMapCycle().time*60 + extend_count*extend_time*60 then
        return false
    end
end

-- Commands
function OnCommandVote(client, map)
    if not in_progress then
        SendError("%t", "Not Started")
    end

    local map_name
    if map:match("^%d+$") then
        map_name = vote_maps[tonumber(map)]
        if not map_name then
            SendError("%t", "Invalid Number", map)
        end
    else
        map_name = FindVoteMapMatchingName(map)
    end

    if clients[client].voted_for_map == map_name then
        SendError("%t", "Already Voted")
    end

    clients[client].voted_for_map = map_name

    SendReply("%t", "Voted For", map_name)
end

function OnCommandTimeleft(client)
    SendReply("%t", "Map Time Left", math.max(0, (MapCycle_GetMapCycle().time*60 - GetTime()) / 60))
end

-- Starts a new map vote
function OnAdminCommandMapvote(client)
    if starting or started or complete then
        SendError("%t", "Already Started")
    end

    StartVote()
end

-- Cancels a map vote that has started
function OnAdminCommandCancelvote(client)
    if not starting and not started and not complete then
        SendError "No map vote is currently in progress"
    end
    
    starting = false
    started = false
    complete = false

    vote_maps = { }
    
    PrintToChatAll("%t", "Cancelled")
end