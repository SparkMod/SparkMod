info = {
    name = "SparkMod MOTD",
    author = "bawNg",
    description = "Prints any number of messages to chat when a client connects",
    version = "0.1",
    url = "https://github.com/SparkMod/SparkMod"
}

default_motd = Format("* This server is running SparkMod v%s", SparkMod.version)

motd_lines = { }

function OnLoaded()
    local file = io.open("config://motd.txt", "r")
    if file then
        local motd_contents = file:read("*all")
        file:close()
        for line in motd_contents:gmatch "[^\n]+" do
            table.insert(motd_lines, line)
        end
    end
    if #motd_lines == 0 then
        motd_lines = { default_motd }
    end
end

function OnClientPutInServer(client)
    for _, line in ipairs(motd_lines) do
        PrintToChat(client, line)
    end
end