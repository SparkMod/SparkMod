rcon_commands = [
  'sv_ban',
  'sv_unban',
  'sv_kick',
  'sv_changemap',
  'sv_switchteam',
  'sv_rrall',
  'sv_randomall',
  'sv_eject',
  'sv_slay',
  'sv_tsay',
  'sv_psay',
  'sv_say',
  'sv_vote',
  'sv_tournament',
  'sv_cheats',
  'sv_reset',
  'sv_listbans',
  'cyclemap',
  'sv_autobalance',
  'kick',
  'status',
  'say',
  'reset',
  'sm',
  'sm cmds',
  'sm version',
  'sm config',
  'sm plugins',
  'sm plugins info',
  'sm plugins list',
  'sm plugins load',
  'sm plugins refresh',
  'sm plugins reload',
  'sm plugins unload',
  'sm plugins unload_all'
]

human_teams = ["Ready Room", "Marines", "Aliens", "Spectator"]

no_players_html = "<tr id=\"noplayers\"><td colspan=\"10\" style=\"text-align: center;\">No Connected Players</td></tr>"

refreshCount = 0
maxChatPos = 0
lastPerfTime = 0
performance_data = [[], []]

shorten_status = false

seconds_to_hhmmss = (seconds) ->
  hours = Math.floor(seconds / 3600)
  minutes = Math.floor((seconds - (hours * 3600)) / 60)
  seconds = Math.round(seconds - hours * 3600 - minutes * 60)
  hours = '0' + hours if hours < 10
  minutes = '0' + minutes if minutes < 10
  seconds = '0' + seconds if seconds < 10
  "#{hours}:#{minutes}:#{seconds}"

seconds_to_time = (seconds) ->
  tm = new Date(seconds * 1000)
  hours = tm.getUTCHours()
  minutes = tm.getUTCMinutes()
  seconds = tm.getUTCSeconds()
  time = ""
  if hours
    if shorten_status
      time += " h "
    else
      time += "#{hours} hour#{if hours > 1 then 's' else ''} "      
  time += minutes + " min " if minutes
  time += seconds + " sec " if seconds unless time.length
  time

refreshInfo = ->
  $.get '/?request=json', (data) ->
    if data? # NS2 has a bug where it sometimes returns no data.  Don't error if that happens
      $("#servermap").html data.map
      $("#serveruptime").html seconds_to_time(data.uptime)
      # $("#marineres").html data.marine_res
      # $("#alienres").html data.alien_res
      $("#servername").html data.server_name
      $("#serverrate").html (Math.round(data.frame_rate * 100) / 100).toFixed(2)

      status_length = $('#serverstatus').text().match(/\S/g).length
      status_length += 5 if shorten_status
      shorten_status = status_length > 45
      
      prevRefreshCount = $("#playerstable tr td").find(".lastupdated").val()
      prevRefreshCount = 0 unless prevRefreshCount?
      currentTime = (new Date()).getTime() / 1000
      connectionTime = currentTime

      if players = data.player_list
        for player in players
          player.humanTeam = human_teams[player.team] or player.team
          player.humanTeam = player.humanTeam + " (*)" if player.iscomm
          $player = $("#playerstable ." + player.steamid)
          unless $player.length
            player.lastupdated = refreshCount
            player.connTimeFormatted = seconds_to_hhmmss(connectionTime - currentTime)
            player.connTime = currentTime
            player.resources = player.resources.toFixed(2)
            $("#playerstable tbody").append tmpl("player_row", player)
          else
            $player.find(".name").text player.name
            $player.find(".team").text player.humanTeam
            $player.find(".score").text player.score
            $player.find(".kd").text "#{player.kills}/#{player.deaths}"
            $player.find(".res").text Math.floor(player.resources)
            $player.find(".ping").text player.ping
            connTime = currentTime - parseInt($player.find(".connectiontime").val())
            $player.find(".connTime").text seconds_to_hhmmss(connTime)
            $player.find(".lastupdated").val refreshCount
            $player.attr "id", refreshCount
      
        #if prevRefreshCount
        #   $("#" + prevRefreshCount).remove()
      if players?.length
        $("#noplayers").remove()          
        if refreshCount
          $("#playerstable").trigger "update"
        else
          $("#playerstable").tablesorter sortList: [[9, 0]]
      
      else if not $("#playerstable #noplayers").length
        $("#playerstable tbody").append no_players_html
        
      $("#playerstable tr").each (i) ->
        return unless i
        id = parseInt($(this).attr("id"))
        return unless id
        if id is refreshCount
          $(this).find("td.num").text "#{i}."
        else
          $(this).remove()

      $("#serverplayers").text "#{players?.length or 0} player#{if players?.length == 1 then '' else 's'}"

      refreshCount++

refreshBanList = ->
  $.get '/?request=getbanlist', (bans) ->
    $("#banstable tbody").empty()
    for ban in bans
      ban.reason = "None provided" unless ban.reason
      $("#banstable tbody").append tmpl("ban_row", ban)

refreshChat = (once) ->
  $.get '/?request=getchatlist', (entries) ->
    for entry in entries
      if entry.id > maxChatPos
        $("#chatlog").text $("#chatlog").text() + tmpl("chat_row", entry)
        maxChatPos = entry.id
      
      $("#chatlog").prop scrollTop: $("#chatlog").prop("scrollHeight")

showPerfChart = ->
  $("#perfchart").empty()
  $.jqplot "perfchart", performance_data,
    title: "Server Performance"
    axes:
      xaxis:
        renderer: $.jqplot.DateAxisRenderer
        tickOptions:
          formatString: "%H:%M"

        tickInterval: "30 minutes"

      yaxis:
        min: 0
        tickInterval: 5

    legend:
      show: true
      location: "se"
      labels: ["Players", "Tickrate"]

    seriesDefaults:
      markerOptions:
        show: false

refreshPerformance = ->
  $request = $.get '/?request=getperfdata'
  $request.done (entries) ->
    for entry in entries
      entry.time *= 1000
      continue if entry.time < lastPerfTime
      performance_data[0].push [entry.time, entry.players]
      performance_data[1].push [entry.time, entry.tickrate]
      lastPerfTIme = entry.time

    showPerfChart()
    setTimeout refreshPerformance, 3000 unless performance_data.length

  $request.fail ->
    setTimeout refreshPerformance, 3000 unless performance_data.length

performancecontent_onShow = ->
  showPerfChart()

rcon = (command) ->
  $.get "/?request=json&command=Send&rcon=#{command}"
  setTimeout refreshBanList, 500 if command.match /sv_(un)?ban/gi
  #setTimeout(refreshChat, 500) if command.match /sv_[tp]?say/gi

sendManualRcon = ->
  rcon $("input[name=manual_rcon]").val()
  $("input[name=manual_rcon]").val ""

sendConfirmedRcon = (message, command) ->
  rcon command if confirm(message)

confirmMapChange = (map) ->
  rcon "sv_changemap #{map}" if confirm "Change map to #{map}?"

sendChatMessage = ->
  chatType = $("select[name=chatmessagetype]").val()
  chatMessage = $("input[name=chat_message]").val()
  $("input[name=chat_message]").val ""
  if chatType is "all"
    rcon "sv_say #{chatMessage}"
  else if chatType is "marines"
    rcon "sv_tsay 1 #{chatMessage}"
  else rcon "sv_tsay 2 #{chatMessage}" if chatType is "aliens"

sendManualBan = ->
  steam_id = parseInt $("input[name=addban_steamid]").val()
  duration = parseInt $("input[name=addban_duration]").val()
  reason = $("input[name=addban_reason]").val()
  duration = 0 if duration < 0
  rcon "sv_ban #{steam_id} #{duration} #{reason}"
  $("input[name=addban_#{field}]").val "" for field in ['steamid', 'duration', 'reason']

$(document).ready ->
  $("#tabs > li").click ->
    $("#tabs > li").each ->
      $(this).removeClass "active"
      $("#" + $(this).attr("rel")).hide()

    $(this).addClass "active"
    $("#" + $(this).attr("rel")).show()
    window[$(this).attr("rel") + "_onShow"]?()

  $('.rconbutton').click -> rcon $(this).attr("command")

  setInterval refreshInfo, 2000
  refreshInfo()
  
  # Chat support is currently not implemented in the engine.
  setInterval refreshChat, 2000
  refreshChat()
  
  setInterval refreshBanList, 300000
  refreshBanList()
  
  setInterval refreshPerformance, 60000
  refreshPerformance()

  $("input[name=manual_rcon]").bind "keypress", (e) ->
    if e.keyCode is 13 # Enter
      sendManualRcon()
      e.preventDefault()

  $("input[name=chat_message]").bind "keypress", (e) ->
    if e.keyCode is 13 # Enter
      sendChatMessage()
      e.preventDefault()

  $("input[name=manual_rcon]").typeahead(source: rcon_commands)

  # Remove team res from interface    #TODO: add a configuration option for removing res info
  $('#serverstatus img').remove()
  $('#marineres, #alienres').remove()
  server_status = $('#serverstatus').html()
  whitespace_size = server_status.match(/&nbsp;&nbsp;\s*&nbsp;&nbsp;\s+$/)[0].length
  $('#serverstatus').html(server_status[0..-whitespace_size-1])


# Simple JavaScript Templating
# John Resig - http://ejohn.org/ - MIT Licensed
(->
  cache = {}
  @tmpl = tmpl = (str, data) ->
    
    # Figure out if we're getting a template, or if we need to
    # load the template - and be sure to cache the result.
    
    # Generate a reusable function that will serve as a template
    # generator (and which will be cached).
    
    # Introduce the data as local variables using with(){}
    
    # Convert the template into pure JavaScript
    fn = (if not /\W/.test(str) then cache[str] = cache[str] or tmpl(document.getElementById(str).innerHTML) else new Function("obj", "var p=[],print=function(){p.push.apply(p,arguments);};" + "with(obj){p.push('" + str.replace(/[\r\t\n]/g, " ").split("<%").join("\t").replace(/((^|%>)[^\t]*)'/g, "$1\r").replace(/\t=(.*?)%>/g, "',$1,'").split("\t").join("');").split("%>").join("p.push('").split("\r").join("\\'") + "');}return p.join('');"))
    
    # Provide some basic currying to the user
    (if data then fn(data) else fn)
)()