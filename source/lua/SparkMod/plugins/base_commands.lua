info = {
    name = "SparkMod Base Commands",
    author = "bawNg",
    description = "Base user commands for SparkMod",
    version = "0.1",
    url = "https://github.com/SparkMod/SparkMod"
}

default_phrases = {
    ["Available Languages"] = "Available languages: %s",
    ["How To Set Language"] = "To set your own language, use \"set language <language>\"",
    ["No Set Name Given"]   = "You need to specify a name. Usage: set <name> [value]",
    ["Set Attribute"]       = "Your %s has been set to \"%s\".",
    ["Attribute Value"]     = "Your %s is currently set to \"%s\".",
    ["Attribute Not Set"]   = "You have not yet set your %s."
}

function OnCommandSettings(client)
    SendReply("[SM] %t", "Available Languages", table.concat(SparkMod.config.languages, ", "))
    SendReply("[SM] %t", "How To Set Language")
end

function OnCommandSet(client, name, value)
    if not name then
        SendError("[SM] %t", "No Set Name Given")
    end

    if value then
        clients[client].cookie[name] = value
        SendReply("[SM] %t", "Set Attribute", name, value)
    else
        value = clients[client].cookie[name]
        if value then
            SendReply("[SM] %t", "Attribute Value", name, value)
        else
            SendReply("[SM] %t", "Attribute Not Set", name)
        end
    end
end