-- SparkMod shared loader
-- https://github.com/SparkMod/SparkMod

SparkMod = { version = "0.3" }

Script.Load("lua/dkjson.lua")

Script.Load("lua/SparkMod/core_ext.lua")
Script.Load("lua/SparkMod/util.lua")
Script.Load("lua/SparkMod/core.lua")
Script.Load("lua/SparkMod/config.lua")
Script.Load("lua/SparkMod/shared_helpers.lua")
Script.Load("lua/SparkMod/scheduler.lua")
Script.Load("lua/SparkMod/engine_hooks.lua")
Script.Load("lua/SparkMod/network_messages.lua")
Script.Load("lua/SparkMod/plugin.lua")
Script.Load("lua/SparkMod/function_hooks.lua")

Shared.Message("This server is running SparkMod v" .. SparkMod.version)