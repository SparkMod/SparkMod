info = {
    name = "SparkMod Random Teams",
    author = "bawNg",
    description = "Assigns players to random teams under certain conditions",
    version = "0.3",
    url = "https://github.com/SparkMod/SparkMod"
}

default_config = {
    delay_after_game_start = 30,
    max_idle_time = 60
}

enabled = true

local function MovePlayersToRandomTeam()
    local count = 0

    for client, info in clients do
        local team = GetClientTeam(client)

        if team == kTeamReadyRoom or team == kSpectatorIndex then
            if not Plugin.IsLoaded("afk") or Plugins.afk.ClientIdleTime(client) < max_idle_time then
                -- Player has not been idle for longer than max_idle_time
                JoinRandomTeam(client)
                count = count + 1
            end
        end
    end

    if count > 0 then
        PrintToChatAll("All remaining active players have been randomly assigned to a team.")
    end
end


function OnUpdatePregame(time_passed)
    if not enabled then return end

    if game_state == kGameState.Countdown then
        local countdown_time = gamerules.countdownTime - time_passed     

        if countdown_time > 0 then
            if game_started then
                scheduler.Unschedule("force_random")
                game_started = false
            end
        elseif not game_started then
            scheduler.In(config.delay_after_game_start, MovePlayersToRandomTeam, "force_random")
            game_started = true
        end
    end
end