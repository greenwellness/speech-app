$(document).ready ->
  openAll = ->
    $(".page_collapsible").collapsible "openAll"

  closeAll = ->
    $(".page_collapsible").collapsible "closeAll"

  hljs.tabReplace = "    "
  hljs.initHighlightingOnLoad()
  $.fn.slideFadeToggle = (speed, easing, callback) ->
    @animate
      opacity: "toggle"
      height: "toggle"
    , speed, easing, callback

  $(".collapsible").collapsible
    defaultOpen: "section1"
    cookieName: "nav"
    speed: "slow"
    animateOpen: (elem, opts) ->
      elem.next().slideFadeToggle opts.speed

    animateClose: (elem, opts) ->
      elem.next().slideFadeToggle opts.speed

    loadOpen: (elem) ->
      elem.next().show()

    loadClose: (elem, opts) ->
      elem.next().hide()

  $(".page_collapsible").collapsible
    defaultOpen: "body_section1"
    cookieName: "body2"
    speed: "slow"
    animateOpen: (elem, opts) ->
      elem.next().slideFadeToggle opts.speed

    animateClose: (elem, opts) ->
      elem.next().slideFadeToggle opts.speed

    loadOpen: (elem) ->
      elem.next().show()

    loadClose: (elem, opts) ->
      elem.next().hide()


  #listen for close/open all
  $("#closeAll").click (event) ->
    event.preventDefault()
    closeAll()

  $("#openAll").click (event) ->
    event.preventDefault()
    openAll()

