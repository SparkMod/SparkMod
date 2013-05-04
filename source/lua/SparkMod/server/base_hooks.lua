-- SparkMod base server hooks

-- Spark gamerules hooks
SparkMod.HookGamerulesFunctionPre("CanEntityDoDamageTo") -- attacker, target

SparkMod.HookGamerulesFunction("OnEntityKilled") -- target, attacker, doer, point, direction

SparkMod.HookGamerulesFunction("OnEntityChange", "OnEntityChanged") -- old_id, new_id

SparkMod.HookGamerulesFunctionPre("ResetGame")
SparkMod.HookGamerulesFunction("ResetGame", "GameReset")

SparkMod.HookGamerulesFunction("GetCanPlayerHearPlayer") -- listener_player, speaker_player, can_hear

SparkMod.HookGamerulesFunctionPre("RespawnPlayer") -- player
SparkMod.HookGamerulesFunction("RespawnPlayer") -- player

SparkMod.HookGamerulesFunctionPre("GetDamageMultiplier")

SparkMod.HookGamerulesFunction("OnTrigger") -- entity, trigger_name

-- NS2 gamerules hooks
SparkMod.HookNS2GamerulesFunctionPre("CheckGameStart")

SparkMod.HookNS2GamerulesFunctionPre("UpdatePregame")

SparkMod.HookNS2GamerulesFunctionPre("CastVoteByPlayer") -- vote_tech_id, player

SparkMod.HookNS2GamerulesFunctionPre("GetFriendlyFire") -- (is_enabled)

SparkMod.HookNS2GamerulesFunctionPre("EndGame", "GameEnd") -- winning_team
SparkMod.HookNS2GamerulesFunction("EndGame", "GameEnded") -- winning_team

SparkMod.HookNS2GamerulesFunctionPre("OnEntityCreate", "OnEntityCreated") -- entity

SparkMod.HookNS2GamerulesFunctionPre("SetGameState",
    function(self, state)
        SparkMod.previous_game_state = self.gameState
        return state
    end
)

SparkMod.HookNS2GamerulesFunctionPre("JoinTeam",
    function(self, player, team_number, force)
        local client = player:GetClient()
        return client, team_number, force
    end
)

-- Mixin hooks
SparkMod.HookFunctionPre("DamageMixin.DoDamage") -- entity, damage, target, point, direction, surface, alt_mode, show_tracer, (killed_from_damage)

SparkMod.HookFunctionPre("ResearchMixin.AbortResearch") -- entity, refund_cost
SparkMod.HookFunctionPre("ResearchMixin.TechResearched") -- entity, structure, research_id
SparkMod.HookFunction("ResearchMixin.SetResearching") -- entity, tech_node, player

SparkMod.HookFunctionPre("GhostStructureMixin.OnConstruct", "ConstructGhostStructure") -- entity, builder
SparkMod.HookFunction("GhostStructureMixin.__initmixin", "GhostStructureCreated") -- entity
SparkMod.HookFunction("GhostStructureMixin.PerformAction", "GhostStructurePerformedAction") -- entity, tech_node, position

SparkMod.HookFunction("FireMixin.SetOnFire") -- entity, attacker, doer

SparkMod.HookFunction("ConstructMixin.Construct", "ConstructionStarted") -- entity, elapsed_time, builder
SparkMod.HookFunction("ConstructMixin.OnConstructionComplete", "ConstructionComplete") -- entity, builder

SparkMod.HookFunction("RecycleMixin.OnResearchComplete", "RecyclableResearchCompleted") -- entity, research_id

SparkMod.HookFunctionPre("PickupableMixin._DestroySelf", "DestroyPickupable") -- entity
SparkMod.HookFunction("PickupableMixin.__initmixin", "PickupableCreated") -- entity

SparkMod.HookFunctionPre("Projectile.ProcessHit", "ProcessProjectileHit") -- projectile, entity
SparkMod.HookFunction("Projectile.ProcessHit", "ProjectileHitProcessed") -- projectile, entity

-- Player hooks
SparkMod.HookFunctionPre("Player.ResetScores", "ResetPlayerScores") -- player
SparkMod.HookFunction("Player.ResetScores", "PlayerScoresReset") -- player
SparkMod.HookFunction("Player.OnCreate", "PlayerCreated") -- player
SparkMod.HookFunction("Player.OnJumpLand", "PlayerJumpLanded") -- player, land_intensity, slow_down
SparkMod.HookFunction("Player.CopyPlayerDataFrom") -- player, other_player

-- Commander hooks
SparkMod.HookFunctionPre("CommanderAbility.OnInitialized", "InitializeCommanderAbility") -- ability
SparkMod.HookFunctionPre("CommanderAbility.OnDestroy", "DestroyCommanderAbility") -- ability
SparkMod.HookFunction("CommanderAbility.OnInitialized", "CommanderAbilityInitialized") -- ability
SparkMod.HookFunction("CommanderAbility.OnDestroy", "CommanderAbilityDestroyed") -- ability

-- Global hooks
SparkMod.HookFunctionPre("MapCycle_TestCycleMap", "CanCycleMap")

SparkMod.HookFunction("CreateEntityForCommander") -- tech_id, position, commander, (new_entity)
SparkMod.HookFunction("BuildScoresMessage") -- score_player, send_to_player, (message)
SparkMod.HookFunction("RemoveAllObstacles")
SparkMod.HookFunction("PerformGradualMeleeAttack") -- weapon, player, damage, range, optional_coords, alt_mode, (did_hit, target, end_point, direction, surface)
SparkMod.HookFunction("AttackMeleeCapsule") -- weapon, player, damage, range, optional_coords, alt_mode, (did_hit, target, end_point, surface)

-- Immediate hooks
SparkMod._HookFunction("Server.AddChatToHistory", "ChatMessage",
    function(message, player_name, steam_id, team_number, team_only)
        local client = SparkMod.connected_steam_ids[steam_id]
        return client, message, team_number, team_only
    end
)

SparkMod._HookFunction("MapCycle_ChangeMap", "ChangeMap")

SparkMod._HookFunction("SetGamerules")

-- Events
function SparkMod.OnSetGamerules(gamerules)
    SparkMod.gamerules = gamerules

    local previous_gamerules_class_name = SparkMod.gamerules_class_name
    local gamerules_class_names = Script.GetDerivedClasses("Gamerules")
    for i = 1, #gamerules_class_names do
        if gamerules:isa(gamerules_class_names[i]) then
            SparkMod.gamerules_class_name = gamerules_class_names[i]
            break
        end
    end

    if SparkMod.gamerules_class_name ~= previous_gamerules_class_name then
        SparkMod._HookOptionalClassFunctions(SparkMod.gamerules_class_name)
    end
end