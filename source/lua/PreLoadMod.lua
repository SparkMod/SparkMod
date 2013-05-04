-- SparkMod preloader

if Server then
	Script.Load("lua/SparkMod/server.lua")
elseif Client then
    Script.Load("lua/SparkMod/client.lua")
end

Script.Load("../core/lua/PreloadMod.lua")