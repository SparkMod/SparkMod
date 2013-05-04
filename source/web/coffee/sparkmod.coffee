# SparkMod web interface extension

server_loading_html = "<html><head><meta http-equiv='refresh' content='5'></head><body>Loading server...<body></html>"

editor_themes = "ambiance blackboard cobalt eclipse elegant erlang-dark lesser-dark midnight monokai neat night rubyblue twilight vibrant-ink xq-dark xq-light"
editor_themes = editor_themes.split(' ')
editor_themes.push 'solarized dark'
editor_themes.push 'solarized light'

loaded_themes = ['vibrant-ink']

is_loading_file = false
is_save_pending = false
is_saving       = false

current_plugin_file = null
current_plugin_name = null

editor = null

is_server_loading = false
is_connected_to_server = true

# General helpers
load_js = (file_names...) ->
  for file_name in file_names
    script = document.createElement('script')
    script.type = 'text/javascript'
    script.src = "/js/#{file_name}.js"
    document.getElementsByTagName('head')[0].appendChild(script)

now = -> new Date().getTime() / 1000

is_server_loading_response = (resp) ->
  typeof(resp) == "string" and resp.indexOf(server_loading_html) != -1

# HTML building
load_stylesheet = (css_subpaths...) ->
  for subpath in css_subpaths
    $('head').append $('<link rel="stylesheet" type="text/css"/>').attr('href', "/css/#{subpath}.css")

btn_group = (el) -> $('<div class="btn-group"/>').append(el)
button = (name, display_name, classes) ->
  $('<button class="btn"/>').attr('id', "#{name}-button").addClass(classes).html(display_name)

# Plugin editor
attempt_save = ->
  $('#save-button').addClass('btn-primary').text 'Saving...'
  req = $.post '/', request: 'savepluginfile', file: current_plugin_file, contents: editor.getValue(), reset_save_button
  req.done (response) ->
    if is_server_loading_response(response)
      on_save_failed()
    else
      is_saving = false
      reset_save_button()

  req.fail(on_save_failed)

reset_save_button = ->
  $('#save-button').removeClass('btn-primary').removeClass('btn-danger')
  $('#save-button').text('Save changes').attr('title', '')

save_active_file = ->
  if is_save_pending
    is_saving = true
    attempt_save()
    is_save_pending = false

load_file = (file_path) ->
  save_active_file()
  if not is_connected_to_server or is_server_loading
    alert "You are not currently connected to the server"
    return
  is_loading_file = true
  $.getJSON '/', request: 'filecontents', file: file_path, (response) ->
    if response.error
      alert(response.error)
      return is_loading_file = false

    current_plugin_name = response.plugin
    current_plugin_file = response.file
    editor.setValue(response.contents)
    is_loading_file = false

    $('#reload-plugin-button').text("Reload #{current_plugin_name}").show()

# Events
on_save_failed = ->
  $('#save-button').removeClass('btn-primary').addClass('btn-danger')
  $('#save-button').text('Save failed').attr('title', 'File will be saved as soon as the server comes back online')

on_disconnected = ->
  toggle_redplug_fade = ->
    $("#redplug").fadeToggle 'fast', ->
      toggle_redplug_fade() unless is_connected_to_server

  $('#server-loading').hide()
  toggle_redplug_fade()

on_reconnected = ->
  attempt_save() if is_saving

$sparkmod_content = null

initialize_sparkmod_tab = ->
  $toolbar = $('<div class="btn-toolbar center"/>')

  # Save button
  $toolbar.append btn_group(button('save', 'Save changes'))

  # Reload plugin button
  $toolbar.append btn_group(button('reload-plugin', 'Reload plugin', 'btn-primary'))
  
  # Change editor theme button
  $editor_theme_button = button('editor-theme', 'Change editor theme', 'btn-primary')
  $editor_theme_button.append $('<span class="caret"/>')
  
  $theme_list = $('<li id="theme-list"/>')
  $theme_list.append $('<a href="#"/>').text(theme) for theme in editor_themes
  
  $dropdown_menu = $('<ul class="dropdown-menu"/>').append($theme_list)
  
  $button_group = btn_group($editor_theme_button).append($dropdown_menu)
  
  $toolbar.append($button_group)
  
  # SparkMod tab body
  $sparkmod_body = $('<div class="well"/>')
  
  $file_tree_container = $('<div id="file-tree-container" class="column"/>').text('Loading...')
  
  $text_area = $('<textarea id="code-editor" name="code-editor" class="column"/>')
  $text_area.text '-- Select a file to open it'
  
  $sparkmod_body.append $file_tree_container
  $sparkmod_body.append $text_area
  
  # Page tab
  $sparkmod_content = $('<div id="sparkmodcontent" class="row"/>')

  $sparkmod_content.append($toolbar).append($sparkmod_body)
  
  $('.content-span').append $sparkmod_content

  $('#editor-theme-button').dropdown()

  $('#theme-list a').click ->
    theme = $(this).text()
    
    theme_name = theme.split(' ')[0]
    if loaded_themes.indexOf(theme_name) < 0
      loaded_themes.push(theme_name)
      load_stylesheet "theme/#{theme_name}"
    
    editor.setOption('theme', theme)

  # SparkMod functionality
  $('#file-tree-container').fileTree script: '/', root: 'sparkmod/plugins', (file_path, el) ->
    $('.jqueryFileTree a.selected').removeClass 'selected'
    $(el).addClass 'selected'
    load_file(file_path)

  editor = CodeMirror.fromTextArea $('#code-editor')[0], lineNumbers: true, theme: "vibrant-ink"

  editor.on 'change', ->
    if current_plugin_file and not is_loading_file
      is_save_pending = true
      $('#save-button').addClass('btn-primary')

  editor.on 'blur', save_active_file

  $('#save-button').click(save_active_file)

  $('#reload-plugin-button').click ->
    unless current_plugin_name
      return alert "There is currently no plugin related file open"

    $.post '/', request: 'reloadplugin', plugin: current_plugin_name, (response) ->
      $('#reload-plugin-button').text("Reload #{current_plugin_name}")
      alert "Error loading plugin: #{response.error}" if response.error

    $('#reload-plugin-button').text("Reloading #{current_plugin_name}...")

$(document).ready ->
  # Extend base ns2 web interface
  $('#tabs a').click ->
    $('.span12').removeClass('span12').addClass('span10')

  $menu_link = $('<a href="#"/>').text('SparkMod')
  $li = $('<li/>').attr('rel', 'sparkmodcontent').append $menu_link
  $("#tabs").append $li

  $connection_status = $('<div id="connection-status"/>')

  $connection_status.append $('<div id="redplug" title="There is no connection to the server"/>')
  $connection_status.append $('<div id="server-loading" title="The server is loading"/>').html($('<div id="loading-spinner"/>'))

  $("#tabs").append $('<li/>').html($connection_status)

  $menu_link.click ->
    initialize_sparkmod_tab() unless $sparkmod_content

    # Hide any other visible tabs and show the SparkMod tab
    $('#tabs > li').removeClass('active').each ->
      $('#' + $(this).attr("rel")).hide()

    $li.addClass('active')

    $('.span10').removeClass('span10').addClass('span12')
    $(window).resize()

    $sparkmod_content.show()

  $('.span10').addClass('content-span')

  $(window).resize ->
    if $sparkmod_content
      $('.well', $sparkmod_content).css(height: $(window).height() - 200)

  # Monitor connection to server
  last_successful_request_at = now()

  $(document).ajaxSuccess (event, xhr, settings) ->
    if not is_connected_to_server
      is_connected_to_server = true
    
    if is_server_loading_response(xhr.responseText)
      is_server_loading = true
      $("#redplug").hide()
      $('#server-loading').show()
    else if is_server_loading
      is_server_loading = false
      $('#server-loading').hide()
      on_reconnected()
    
    last_successful_request_at = now()

  $(document).ajaxError (event, jqxhr, settings, exception) ->
    if is_connected_to_server and now() - last_successful_request_at > 2
      is_connected_to_server = false
      on_disconnected()

  # Preload icons which need to be displayed when offline
  $('<img src="/images/loading-spinner.gif"/>').load ->
    $('#server-loading').hide().css(visibility: 'visible')

  $('<img src="/images/redplug.png"/>').load ->
    $('#redplug').hide().css(visibility: 'visible')

# Load JS dependencies
load_js 'codemirror', 'jquery-filetree'

# Load CSS dependencies
load_stylesheet 'sparkmod', 'jquery-filetree', 'codemirror', 'theme/vibrant-ink'