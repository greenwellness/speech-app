$ = jQuery
recognition = null
listening = false
currentPage = 'main'
prettifier = null
emptyStringRe = /^\s*$/

# Works with `global` instead of `window` when available (nodejs environment), no Backbone dependency,
# no ev[ai]l for rendering variables and a shorter `{...}` syntax.
window.t = (id, vars = {}) ->
  (i18n[__locale][id] or i18n.en[id] or "(?) #{id}")
    .replace /\{(\w+)\}/g, (a, k) -> vars[k] or "?#{k}"

i18n=
  nl:
    'Hello, {world}': '{world} hallo!'
    "Program error! Please report to developer! Error: {html}\n\nYou may try to continue by pressing OK.":
      "Programma fout! Aub melden aan ontwikkelaar. Fout: {html}\n\n\Je kunt proberen verder te gaan door op OK te drukken."
    "Cannot change font: {e}": "Kan lettertype niet wijzigen: {e}"
    "Stopping": "Aan het stoppen"
    "Starting": "Aan het starten"
    "Speech recognition error: {event.error}": "Spraakherkenning fout: {event.error}"
    "# The first word is the language code, used by the speech recognition engine.":
      "# Het eerste woord is de taalcode die door de spraakherkenning gebruikt wordt."
    "# The rest of the line is just a label for the language selection box.":
      "# De rest van de regel is slechts een label voor het keuzemenu."
    "At least one language must be specified.": "Tenminste één taal moet geselecteerd zijn."
    "Invalid line:\n {line}": "Ongeldige regel:\n {line}"

__locale = 'nl'

escapeHTML = (text) -> text
	.replace(/&/g,'&amp;')
	.replace(/</g,'&lt;')
	.replace(/>/g,'&gt;')

alert = null
$ ->
	template = $('div.alert')
	alert = (html) ->
		page = template.clone().insertBefore(template).show()
		$('.message', page).html(html.replace("\n", "<br>"))
		$('.ok', page).on 'click', (event) ->
			page.fadeOut -> page.remove()
			return

bug = (html) ->
	alert t "Program error! Please report to developer!\nError: {html}\n\nYou may try to continue by pressing OK.", html: html
	return $.Deferred.reject(escapeHTML(html))

doing = null
$ ->
	template = $('div.doing')
	doing = (message, defer) ->
		page = template.clone().insertBefore(template).show()
		$('.message', page).text(message)
		defer.always ->
			page.remove()
			return
		defer.fail (message) ->
			alert(escapeHTML(message))
			return
		# return defer
	return

# Controls the big button on the top left corner of the page.
# It's an incredibly ugly button, but it does its job.  :-)
changeStatus = (message, clickable = false) ->
	$('#start')
		.text(message)
		.prop('disabled', !clickable)
	return

# Insert text into the main input text area.
# Add spaces around text when necessary.
addTranscription = do ->
	endWithSpace = new RegExp('(^|\n| )$')
	startWithSpace = new RegExp('^( |\n|$)')
	return (text) ->
		input = $('#text')
		elem = input[0]
		startPosition = elem.selectionStart
		endPosition = elem.selectionEnd
		oldText = input.val()
		beforeText = oldText.substr(0, startPosition)
		afterText = oldText.substr(endPosition)
		text = text.replace(/^ +| +$/, '')
		text = " " + text unless endWithSpace.test(beforeText)
		text = text + " " unless startWithSpace.test(afterText)
		newText = beforeText + text + afterText
		input.val(newText).triggerHandler('change')
		newPosition = startPosition + text.length
		elem.setSelectionRange(newPosition, newPosition)
		return

setTextFont = (font) ->
	if typeof font isnt 'string' or font is ''
		return
	try
		[family, size] = font.split(/,\s+/)
		$('#text').css
			'font-family': (family or 'Arial')
			'font-size': Number(size or 14)
	catch e
		alert t "Cannot change font: {e}"
	return

$ ->
	if startRecognizer() is false then return
	new TextAutoSaver('text', $('#text'))
	new LanguagesSelectionPage()
	prettifier = new PrettifyRulesPage()
	new SnippetsPage()
	new FontsPage()
	attachEventHandlers()
	changeStatus("Start", true)
	$('#header .edit').fadeTo('slow', 0.5)
	$('#main-page').layoutPage()
	return

$ -> # Main menu
	button = $('#menu-button')
	list = $('#menu-list')
	button.on 'click', (event) ->
		list.slideDown('fast')
		return
	list.on 'mouseleave', (event) ->
		list.hide()
		return
	$('#menu-quit').on 'click', (event) ->
		window.close()
		return
	return

$.fn.sumHeights = ->
	height = 0
	for elem in @
		height += $(elem).outerHeight(true)
	return height

$.fn.layoutPage = ->
	return @each ->
		$this = $(@)
		textarea = $this.children('textarea')
		if textarea.length is 1
			prevHeights = textarea.prevAll('.layout:visible').sumHeights() +
				$('#titlebar').outerHeight(true)
			nextHeights = textarea.nextAll('.layout:visible').sumHeights()
			# <tag> margin+border+padding
			# <div#content> has border-top: 0
			# 20 = ( <div#content> 0+3+3 + <textarea> 0+1+2 <button> 0+1+2 )*2
			textarea.height(document.documentElement.clientHeight - prevHeights - nextHeights - 21 + 1)
			# <tag> margin+border+padding
			# 20 = ( <div#content> 0+3+3 + <textarea> 0+1+2 )*2
			textarea.width($(window).width() - 18)

$ ->
	window.onresize = (event) ->
		$('#' + currentPage + '-page').layoutPage()
		return

switchToPage = (name) ->
	currentPage = name
	document.body.scrollTop = 0
	$('body [id$=-page]:visible').hide()
	$('#' + name + '-page').fadeIn().layoutPage()
	# return the page's <div>

reLayoutPage = ->
	$('#' + currentPage + '-page').layoutPage()
	return

prettifyText = ->
	input = $('#text')
	doing "Prettifying", prettifier.magic(input.val())
	.done (text) ->
		input.val(text)
		input[0].setSelectionRange(0, input.val().length)
		input.focus()
		return
	# return defer

textCommand = (command) ->
	prettifyText()
	.done ->
		document.execCommand(command)
		return
	if listening
		toggleListening()
	return

toggleHelp = null
$ ->
	help = $('#help')
	toggleHelp = ->
		help.children().toggle()
		reLayoutPage()
		return

attachEventHandlers = ->
	$('body').on 'keydown', (event) ->
		if currentPage is 'main'
			if event.which in [27] # Escape
				toggleListening()
			# Show/hide help message on Control-H or F1
			if (event.which is 72 and event.ctrlKey is true) or event.which is 112
				toggleHelp()
			# Before copying (Control-C) or cutting (Control-X),
			# run 'prettify' if nothing is selected,
			# and then stop listening.
			if event.which is 67 and event.ctrlKey is true
				event.preventDefault()
				textCommand('copy')
			if event.which is 88 and event.ctrlKey is true
				event.preventDefault()
				textCommand('cut')
		return
	do (button = $("#start")) ->
		button.on 'click', (event) ->
			toggleListening()
			return
		return
	do (input = $('#text')) ->
		input.on 'select', (event) ->
			document.execCommand('copy')
			return
		$('#prettify').on 'click', (event) ->
			prettifyText()
			return
		return
	do (select = $('#snippets')) ->
		select.on 'change', (event) ->
			addTranscription(select.val())
			select.val('')
			return
		return
	do (select = $('#font')) ->
		select.on('change', -> setTextFont(select.val()))
		return
	return

toggleListening = ->
	if $("#start").prop('disabled') is true
		return # already starting or stopping
	if listening
		changeStatus t "Stopping"
		recognition.stop()
	else
		changeStatus t "Starting"
		recognition.lang = $('#language').val()
		recognition.start()
	return

startRecognizer = ->
	recognition = new webkitSpeechRecognition()
	recognition.continuous = true
	recognition.interimResults = true

	recognition.onstart = (event) ->
		changeStatus("Stop", true)
		$("#start").addClass('on')
		listening = true
		return

	recognition.onend = (event) ->
		changeStatus("Start", true)
		$("#start").removeClass('on')
		listening = false
		$('#interim').text("...")
		return

	recognition.onerror = (event) ->
		console.log event
		alert t "Speech recognition error: {event.error}"
		return

	recognition.onresult = (event) ->
		interim = ""
		i = event.resultIndex
		while i < event.results.length
			result = event.results[i]; i += 1
			if result.isFinal then addTranscription(result[0].transcript)
			else interim += result[0].transcript
		$('#interim').text(interim || "...")
		return

	return true

class Page
	constructor: ->
		@page = $('#' + @name + '-page')
		# Restore data
		doing "Loading", @get().then (data) => @parse(data)
		# Attach event handlers
		$('#menu-' + @name).on 'click', =>
			doing "Loading", @load().then => @open()
		$('#save-' + @name).on 'click', =>
			doing "Saving", @save().then => @close()
		$('#reset-' + @name).on 'click', =>
			doing "Resetting", @reset().then => @load()
	get: -> # Load data from storage
		defer = $.Deferred()
		chrome.storage.sync.get @name, (data) =>
			if chrome.runtime.lastError
				defer.reject("Error loading #{@name}: #{chrome.runtime.lastError.message}")
				return
			defer.resolve(data[@name] ? @default)
			return
		return defer
	set: (data) -> # Save data to storage (and to main page)
		if data is @default
			return @reset() # defer
		@parse(data).then =>
			defer = $.Deferred()
			if typeof(err = @validate?()) is 'string'
				return defer.reject("Validation error for #{@name}: #{err}")
			obj = {}
			obj[@name] = data
			chrome.storage.sync.set obj, =>
				if chrome.runtime.lastError
					defer.reject("Error saving #{@name}: #{chrome.runtime.lastError.message}")
					return
				defer.resolve()
				return
			return defer
		# return @parse()'s chained promise object
	open: -> # Show this page
		switchToPage(@name)
		return
	close: -> # Back to main page
		switchToPage('main')
		return
	load: -> # storage to DOM
		$.Deferred().resolve()
	save: -> # DOM to storage
		$.Deferred().resolve()
	parse: -> # data to main page
		$.Deferred().resolve()
	reset: ->
		defer = $.Deferred()
		chrome.storage.sync.remove @name, =>
			if chrome.runtime.lastError
				defer.reject("Error removing #{@name}: #{chrome.runtime.lastError.message}")
				return
			defer.resolve()
			return
		parsing = @parse(@default)
		defer.then => parsing
		# 'remove' and 'parse' together, but on 'remove' failure, ignore @parse()'s result.

class SingleTextboxPage extends Page
	constructor: ->
		super
		@textarea = $('textarea', @page)
	open: -> # Show this page
		super
		@textarea.focus()
		return
	load: -> # storage to DOM
		@get().done (data) =>
			@textarea.val(data)
			return
		# return defer
	save: -> # DOM to storage
		@set(@textarea.val())
		# return defer

class LanguagesSelectionPage extends SingleTextboxPage
	name: 'langs'
	constructor: ->
		@default = """
#{t "# The first word is the language code, used by the speech recognition engine."}
#{t "# The rest of the line is just a label for the language menu list."}
nl-NL Nederlands
en-US English"""
		createLanguageList 'lang', (code, language) =>
			@textarea.val("#{code} #{language}\n\n#{@textarea.val()}")
			return
		super
	validate: ->
		if @count() is 0
			return t "At least one language must be specified."
		return null # no error
	parse: (data) ->
		defer = $.Deferred()
		ul = $('#language').empty()
		for line in data.split(/\r*\n+/)
			if /^\s*(#|$)/.test(line)
				# Comment or empty
			else if mo = line.match(/^\s*(\S+)\s+(\S.*)$/)
				$('<li>')
					.text(mo[2] + " (" + mo[1] + ")")
					.add('<a href="#">' + mo[1] + '</a>')
					.appendTo(ul)
			else
				return defer.reject(t "Invalid line:\n {line}")
		defer.resolve()
	count: ->
		$('#language > li').length

class PrettifyRulesPage extends SingleTextboxPage
	name: 'rules'
	pending: null
	constructor: ->
		@default = """
			# Capitalize these words anywhere.
			[ /\\b(google|microsoft|nederlandse|english|nederland|tilburg|wellnessbon|green wellness)\\b/g, capitalize ]
			[ /(free|open|net|dragon)bsd\\b/gi, function(_, a) { return capitalize(a) + 'BSD' } ]

			# Capitalize the first letter of each line.
			[ /^\\w/gm, capitalize ]

      # Replace literals with punctuation signs
      [ /\\komma\\b/gi, ', ' ]
      [ /\\punt\\b/gi, '. ' ]

			# Capitalize the first letter after .?!
			[ /([.?!] )(\\w)/g, function(_, a, b) { return a + capitalize(b) } ]

			# Remove whitespace between end of sentence and .?!
			[ /(\\w) ([.?!])/g, function(_, a, b) { return a + b } ]

			# Commonly misrecognized words.
			[ /\\big\\b/gi, 'e' ]
			[ /\\buol\\b/gi, 'ou' ]
      [ /\\welmers\\b/gi, 'wellness' ]
      [ /\\zijden\\b/gi, 'zij de' ]
			"""
		@iframe = $.Deferred()
		addEventListener 'message', (event) =>
			if event.data.target is 'prettifyRules'
				@receive(event.data)
			return
		super
	send: (command, data = null) ->
		if @pending isnt null
			return bug("PrettifyRulesPage.pending is set") # defer
		@iframe.then (iframe) =>
			@pending = $.Deferred().always => @pending = null; return
			message = command: command, data: data
			iframe.contentWindow.postMessage(message, '*')
			return @pending
		# return @iframe's chained promise object
	receive: (data) ->
		switch data.command
			when 'load'
				@iframe.resolve($('#prettifier')[0])
			when 'parse'
				if data.return is null then @pending.resolve()
				else @pending.reject(data.return)
			when 'magic'
				@pending.resolve(data.return)
		return
	parse: (data) ->
		@send('parse', data)
		# return defer
	magic: (text) ->
		@send('magic', text)
		# return defer

class SnippetsPage extends SingleTextboxPage
	name: 'snippets'
	constructor: ->
		@default = """
			?
			!
			.
			,
			:-)
			:-(
			"""
		super
	parse: (data) ->
		defer = $.Deferred()
		ul = $('#snippets').empty()
		$('<li>')
			.add('<a href="#"></a>')
			.appendTo(ul)
		for line in data.split(/\r*\n+/)
			if /^\s*(#|$)/.test(line)
				# Comment or empty
			else
				$('<li>')
					.text(line)
					.add('<a href="#">' + line + '</a>')
					.appendTo(ul)
		defer.resolve()

class FontsPage extends SingleTextboxPage
	name: 'fonts'
	constructor: ->
		@default = """
			# Font name, size:
      Andale Mono, 20
      Consolas, 28
			Monospace, 14
			Arial, 12
			Trebuchet MS, 14
			"""
		super
	parse: (data) ->
		defer = $.Deferred()
		ul = $('#font').empty()
		for line in data.split(/\r*\n+/)
			if /^\s*(#|$)/.test(line)
				# Comment or empty
			else
				$('<li>')
					.text(line)
					.add('<a href="#">' + line + '</a>')
					.appendTo(ul)
		#setTextFont(ul.val()) #### wont work
		defer.resolve()

class ValueAutoSaver
	timerId: null
	constructor: (@name, @input) ->
		@load()
		@timeoutHandler = => @timeout()
		@input.on 'change keyup', => @start(); return
	load: -> # fileSystem to DOM
		readFile(@name)
		.then null, (error, e) ->
			if e.code is e.NOT_FOUND_ERR
				return $.Deferred().resolve("")
			return arguments # no change
		.done (data) =>
			@input.val(data)
			return
		# return readFile()'s chained defer
	save: -> # DOM to fileSystem
		removeFile(@name)
		.then null, (error, e) ->
			if e.code is e.NOT_FOUND_ERR
				return $.Deferred().resolve()
			return arguments # no change
		.then =>
			if (data = @input.val()) is ""
				return "" # no data to save, resolve defer
			return writeFile(@name, data) # defer
		# return removeFile()'s chained defer
	start: ->
		if @timerId isnt null then clearTimeout(@timerId)
		@timerId = setTimeout(@timeoutHandler, 1000)
	timeout: do ->
		saving = null
		return ->
			@timerId = null
			if saving is null
 				saving = @save().always -> saving = null; return
 			else if saving isnt 'scheduled' # and isnt null
 				saving.always => @save(); return
 				saving = 'scheduled'
			return

class TextAutoSaver extends ValueAutoSaver
	constructor: ->
		super
		@div = $('#autosave')
	load: ->
		doing "Loading last value", super
		# return defer
	save: ->
		@div.text('Saving...')
		super.done =>
			now = new Date()
			@div.text('Last saved: ' + now.toLocaleTimeString())
			return
		.fail (message) =>
			@div.text(message)
			return
		# return defer
	start: ->
		@div.text('May contain unsaved work!')
		super

$ -> # Drag and drop files into any text area
	$('body').on 'dragenter', 'textarea', (event) ->
		$(event.target).addClass('dragover')
		return
	$('body').on 'dragleave drop', 'textarea', (event) ->
		$(event.target).removeClass('dragover')
		return
	$('body').on 'drop', 'textarea', (event) ->
		data = event.originalEvent.dataTransfer
		if typeof(data) isnt 'object'
			return # possible?
		if data.files?.length > 0 # dropping files
			event.stopPropagation()
			event.preventDefault()
			if data.files.length > 1
				alert("Only one file may be dropped here")
				return
			file = data.files[0]
			doing "Reading file #{file.name}", readFileHandle(file).done (data) ->
				$(event.target).val(data).triggerHandler('change')
				return
			return # file dropped successfully
		return
	return
