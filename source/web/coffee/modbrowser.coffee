server_loading_html = "<html><head><meta http-equiv='refresh' content='5'></head><body>Loading server...<body></html>"

now = -> new Date().getTime() / 1000

_modPageNumber = 1
_subscribedMods = {}
_searchText = ""

updateModSubscribeStatus = (id) ->
  selector = $("#modbrowser_mod_" + id).find(".modbrowser_mod_subscribe")
  if _subscribedMods[id]
    selector.addClass "subscribed"
  else
    selector.removeClass "subscribed"

getModSubscribeHandler = (id) ->
  ->
    if _subscribedMods[id]
      _subscribedMods[id] = null
    else
      _subscribedMods[id] = true
      $.get "/?request=installmod&modid=#{id}"

    updateModSubscribeStatus id

getPageLink = (pageNumber, currentPage) ->
  unless pageNumber is currentPage
    "<a href='#'>" + pageNumber + "</a>"
  else
    pageNumber

getMods = (pageNumber) ->
  $("#modbrowser_loading").show()

  request_mods = ->
    requested_at = now()

    $.ajax
      url: "/"
      data:
        request: "getmods"
        searchtext: _searchText
        p: pageNumber

      success: (data) ->
        if data is server_loading_html
          setTimeout request_mods, 4000
          return

        if data?.loading
          latency = (now() - requested_at) / 2
          setTimeout request_mods, Math.max(100, 350 - latency * 1000)
          return

        $("#modbrowser_mods").empty()

        if data?.items?
          mods = data.items
          i = 0

          for mod in mods
            $("#modbrowser_mods").append tmpl("modbrowser_mod", mod)
            $("#modbrowser_mod_" + mod.id).find(".modbrowser_mod_subscribe").click getModSubscribeHandler(mod.id)
            updateModSubscribeStatus mod.id

        if data?.range?
          first = data.range.first
          last = data.range.last
          total = data.range.total
          numPerPage = 9
          currentPage = Math.floor(first / numPerPage) + 1
          numPages = Math.ceil(total / numPerPage)
          _modPageNumber = currentPage
          pageRange = 5
          pageRangeStart = currentPage - (pageRange - 1) / 2
          pageRangeEnd = pageRangeStart + pageRange
          pageRangeStart = 1 if pageRangeStart < 1
          pageRangeEnd = numPages if pageRangeEnd > numPages
          pages = ""
          
          # Always include the first page.
          if pageRangeStart > 1
            pages += getPageLink(1, currentPage) + " "
            pages += "... " if pageRangeStart > 2

          i = pageRangeStart

          while i <= pageRangeEnd
            pages += " " + getPageLink(i, currentPage) + " "
            ++i
          
          # Always include the last page.
          pages += "... " + getPageLink(numPages, currentPage) if pageRangeEnd < numPages and pageRangeEnd > 1
          $("#modbrowser_pages").html(pages).find("a").click ->
            getMods parseInt($(this).text())

        $("#modbrowser_loading").hide()

      error: (err) ->
        setTimeout request_mods, 3000

  request_mods()

doSearch = ->
  _modPageNumber = 1
  _searchText = $("#modbrowser_search").val()
  getMods _modPageNumber

$(document).ready ->
  $("#modbrowser_prev_button").button().click ->
    if _modPageNumber > 1
      --_modPageNumber
      getMods _modPageNumber

  $("#modbrowser_next_button").button().click ->
    ++_modPageNumber
    getMods _modPageNumber

  $("#modbrowser_search_button").button().click doSearch
  $("#modbrowser_search").keypress (e) ->
    if e.which is 13
      e.preventDefault()
      doSearch()
      false

  getMods _modPageNumber
