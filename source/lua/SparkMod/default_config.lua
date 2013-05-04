SparkMod.default_config = {
    unload_plugin_error_limit = 100,    -- The maximum number of unhandled errors a plugin can have before it is unloaded
    notification_from = "SparkMod",     -- The sender of chat messages which are sent to all clients
    public_chat_triggers = { '!' },     -- Triggers that can be used to trigger commands visibly from chat messages
    hidden_chat_triggers = { '/' },     -- Triggers that can be used to trigger commands invisibly from chat messages
    triggerless_commands = true,        -- Can commands be triggered from chat messages without a prefixed trigger
    default_language = "en",            -- The default language used for messages sent from a context which has no language
    disabled_languages = { },           -- Languages are automatically enabled when phrases are found in sparkmod/translations
    disabled_plugins = { }              -- Disables specific plugins, all plugins found are automatically loaded by default
}

-- Shared default config values are not saved to the SparkMod config by default, they will only be saved if you add them to the SparkMod.json config file
SparkMod.shared_default_config = {
    debug_plugin_loading = false,       -- Enables debug output for plugin loading and automatic dependency management
    debug_forwards = false,             -- Enables debug output showing when forwards fire (excludes network messages, web requests and forwards with Check/Update in their name)
    debug_function_hooks = false,       -- Enables debug output about function hooks
    debug_network_messages = false,     -- Enables debug output about network messages and showing when network message forwards fire
    debug_web_requests = false          -- Enables debug output showing when web request forwards fire
}