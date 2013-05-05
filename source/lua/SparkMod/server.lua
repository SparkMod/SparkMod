-- SparkMod server loader

Script.Load("lua/SparkMod/shared.lua")
Script.Load("lua/SparkMod/server/network_messages.lua")
Script.Load("lua/SparkMod/cookies.lua")
Script.Load("lua/SparkMod/commands.lua")
Script.Load("lua/SparkMod/sm_commands.lua")
Script.Load("lua/SparkMod/event_hooks.lua")
Script.Load("lua/SparkMod/managed_clients.lua")
Script.Load("lua/SparkMod/web_interface.lua")

-- Returns the current language set for a client, defaults to the default language for the server
function SparkMod.GetClientLanguage(client)
    return SparkMod.GetClientCookie(client, "language") or SparkMod.config.default_language
end

-- Is the client running SparkMod
function SparkMod.IsClientEnabled(client)
    local client_info = SparkMod.clients[client:GetUserId()]
    return client_info and client_info.client_enabled
end

-- Events
function SparkMod.OnMapEnd(map_name)
    Plugin.UnloadAll()
    SparkMod.is_map_loaded = false
end

function SparkMod.OnClientConnect(client)
    if client and not client:GetIsVirtual() then
        local info = { id = client:GetUserId(), client = client }
        info.cookies = SparkMod.BuildClientCookiesProxy(client)
        SparkMod.clients[info.id] = info
        SparkMod.clients.count = SparkMod.clients.count + 1
    end
end

function SparkMod.OnClientDisconnect(client)
    if SparkMod.clients.count > 0 then
        local steam_id = client:GetUserId()
        if SparkMod.clients[steam_id] then
            SparkMod.clients[steam_id] = nil
            SparkMod.clients.count = SparkMod.clients.count - 1
        end
    end
end

function SparkMod.OnPreNetworkMessageSetName(client, message)
    local name = message.name
    if client and name then
        name = TrimName(name)

        if string.len(name) > 0 and name ~= kDefaultPlayerName then
            if client:GetControllingPlayer():GetName() == kDefaultPlayerName then
                SparkMod.Schedule(SparkMod.On, "ClientPutInServer", client)
            end
        end
    end
end

function SparkMod.OnClientInitialized(client, version)
    local info = SparkMod.clients[client:GetUserId()]
    if info then
        info.client_enabled = true
        info.client_version = version
        if version < SparkMod.version then
            Puts("[SM] Client is running an older version of SparkMod: %N (version %s)", client, version)
        end

        for key, default_value in pairs(SparkMod.shared_default_config) do
            if SparkMod.config[key] ~= default_value then
                SparkMod.SetClientConfig(client, "SparkMod", key, SparkMod.config[key])
            end
        end

        Plugin.OnClientInitialized(client, version)

        SparkMod.FireClientForward(client, "ConfigurationInitialized")
    end
end

Event.Hook("Console____sm_initialized___", SparkMod.OnClientInitialized)

function SparkMod.OnEntityKilled(target, attacker, doer, point, direction)
    if target then
        local client = target:GetClient()
        if client then
            SparkMod.On("ClientDeath", client, attacker, doer, point, direction)
        end
    end
end

function SparkMod.OnClientError(client, message, traceback, plugin_name, event_name, is_unloading)
    Puts("[ClientError] %N: %s", client, message)
    --TODO: log to file once engine supports io append mode
end

function SparkMod.OnError(error, plugin_name, event_name, is_unloading)
    --TODO: log to file once engine supports io append mode
end

SparkMod.LoadConfig()
SparkMod.LoadPersistentStore()