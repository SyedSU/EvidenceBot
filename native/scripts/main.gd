extends Control
const Assistant=preload("res://scripts/assistant.gd")
var assistant=Assistant.new()
var status:Label
var activation:LineEdit
var question:TextEdit
var answer:TextEdit
var model:LineEdit
var port:SpinBox
var http:HTTPRequest
var ticket=-1
var confirmation:ConfirmationDialog
var selected={}
var google=preload("res://scripts/google_provider.gd").new()
var google_client:LineEdit
var google_preview_text:TextEdit
var google_confirmation:ConfirmationDialog
var google_selected={}
var gmail_to:LineEdit
var gmail_subject:LineEdit
var gmail_body:TextEdit
var event_summary:LineEdit
var event_start:LineEdit
var event_end:LineEdit
func _ready():
	if "--package-smoke" in OS.get_cmdline_user_args():call_deferred("_package_review_smoke")
	add_child(google);google.assistant=assistant
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme_resource=Theme.new()
	theme_resource.default_font_size=18
	theme_resource.set_color("font_color","Label",Color("f2ead6"))
	theme=theme_resource
	var scroll=ScrollContainer.new();scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(scroll)
	var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",12);scroll.add_child(box)
	label(box,"EvidenceBot · typed name activation",28)
	label(box,"Type EvidenceBot to activate this session. Microphone / voice wake is unavailable.")
	activation=LineEdit.new();activation.placeholder_text="EvidenceBot";box.add_child(activation)
	button(box,"Activate",func():assistant.activate(activation.text);show_status("Activated" if assistant.active else "Exact assistant name required"))
	label(box,"Permissions expire at restart. App actions always require a separate preview and confirmation.")
	for permission in ["apps","local_ai"]:
		var control=CheckBox.new();control.text="Allow Windows app opening" if permission=="apps" else "Allow local Q&A requests (loopback only)"
		box.add_child(control)
		control.toggled.connect(func(enabled):cancel_request();if not assistant.grant(permission,enabled):show_status(assistant.error))
	button(box,"Revoke all permissions and cancel",func():cancel_request();google.revoke_local();assistant.grant("apps",false);assistant.grant("local_ai",false);for child in box.get_children():
		if child is CheckBox:child.set_pressed_no_signal(false)
	)
	label(box,"Local OpenAI-compatible server · HTTP 127.0.0.1 only. No cloud fallback. No API keys.")
	port=SpinBox.new();port.min_value=1024;port.max_value=65535;port.value=8080;box.add_child(port)
	model=LineEdit.new();model.placeholder_text="Explicit local model identifier (required)";box.add_child(model)
	question=TextEdit.new();question.placeholder_text="Ask a question (maximum 4,000 characters)";question.custom_minimum_size.y=100;box.add_child(question)
	button(box,"Send to local model",ask)
	button(box,"Cancel pending question / action",func():cancel_request();show_status("Canceled; late responses ignored"))
	answer=TextEdit.new();answer.editable=false;answer.custom_minimum_size.y=140;answer.placeholder_text="Model answers are untrusted text, never commands or actions.";box.add_child(answer)
	for app in ["calculator","notepad"]:button(box,"Preview opening "+app,func():preview(app))
	label(box,"Google desktop OAuth · live provider acceptance UNRUN. Supply your own installed desktop client JSON. Tokens and client configuration stay in memory; restart disconnects locally. Google authorization persists until revoked in Google account permissions.")
	google_client=LineEdit.new();google_client.secret=true;google_client.placeholder_text="Paste installed desktop OAuth client JSON (never saved)";box.add_child(google_client)
	button(box,"Load client into memory",func():google.configure(google_client.text);google_client.clear())
	var google_permission=CheckBox.new();google_permission.text="Allow this session: Gmail send and events in calendars I own";box.add_child(google_permission)
	google_permission.toggled.connect(func(enabled):
		if not enabled:google.revoke_local()
		else:google.allowed=true
	)
	button(box,"Sign in with Google (opens browser)",func():if not google.sign_in():show_status("Activate, load desktop client, and enable Google permission first"))
	button(box,"Disconnect locally and cancel Google action",func():google.revoke_local();google_permission.set_pressed_no_signal(false))
	button(box,"Revoke Google session token and disconnect",func():google.revoke_google();google_permission.set_pressed_no_signal(false))
	var google_status=label(box,google.outcome)
	google.changed.connect(func(value):google_status.text=value)
	label(box,"Gmail: one typed recipient, subject and plain text body. Preview and separately confirm each send. Model output cannot trigger actions.")
	gmail_to=field(box,"Recipient email address")
	gmail_subject=field(box,"Subject (maximum 200 characters)")
	gmail_body=TextEdit.new();gmail_body.placeholder_text="Plain text message (maximum 20,000 characters)";gmail_body.custom_minimum_size.y=120;box.add_child(gmail_body)
	button(box,"Preview Gmail send",func():preview_google("gmail",{"to":gmail_to.text,"subject":gmail_subject.text,"body":gmail_body.text}))
	label(box,"Calendar: primary calendar only; UTC start/end; no attendees or invitations (sendUpdates=none).")
	event_summary=field(box,"Event summary")
	event_start=field(box,"UTC start: 2026-11-01T10:00:00Z")
	event_end=field(box,"UTC end: 2026-11-01T11:00:00Z")
	button(box,"Preview Calendar event",func():preview_google("calendar",{"summary":event_summary.text,"start":event_start.text,"end":event_end.text}))
	google_confirmation=ConfirmationDialog.new();google_confirmation.title="Confirm one Google action";google_confirmation.ok_button_text="Confirm this exact action once";add_child(google_confirmation)
	google_preview_text=TextEdit.new();google_preview_text.editable=false;google_preview_text.custom_minimum_size=Vector2(650,320);google_confirmation.add_child(google_preview_text)
	google_confirmation.confirmed.connect(func():google.confirm(google_selected.get("id"),google_selected.get("digest"));google_selected={})
	google_confirmation.canceled.connect(func():google.pending={};google_selected={})
	label(box,"Android accessibility: unavailable. Requires an Android service, explicit device permission and per-action review. No accessibility service is active.")
	button(box,"Inspect / export audit",export_audit)
	label(box,"Recovery: JSON and .backup in the EvidenceBot user folder. Corrupt saves are preserved and block actions. Close instances, archive originals, then restore a known backup manually.")
	status=label(box,"Starting…")
	
	confirmation=ConfirmationDialog.new();confirmation.title="Confirm this one app action";confirmation.ok_button_text="Open this app once";add_child(confirmation)
	confirmation.confirmed.connect(func():var ok=assistant.confirm(selected.get("id"),selected.get("app"),dispatch);selected={};show_status("Launch requested" if ok else "Blocked / failed. "+assistant.error))
	confirmation.canceled.connect(func():assistant.cancel();selected={})
	show_status("Ready · permissions off · inactive" if assistant.start() else assistant.error)
func label(parent,text_value,size=18):
	var node=Label.new();node.text=text_value;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.add_theme_font_size_override("font_size",size);parent.add_child(node);return node
func button(parent,text_value,action):
	var node=Button.new();node.text=text_value;node.custom_minimum_size.y=44;node.pressed.connect(action);parent.add_child(node)
func show_status(value):status.text=value
func cancel_request():
	assistant.cancel();selected={};google.cancel_action();google_selected={}
	if google_confirmation!=null:google_confirmation.hide()
	if http!=null:
		http.cancel_request();http.queue_free();http=null
	if confirmation!=null:confirmation.hide()
func ask():
	cancel_request()
	if model.text.strip_edges().is_empty() or model.text.length()>128:show_status("Enter a local model identifier");return
	ticket=assistant.begin_question(question.text)
	if ticket<0:show_status("Activate by name and grant local Q&A permission; check question length");return
	var payload={"model":model.text.strip_edges(),"messages":[{"role":"system","content":"Answer questions only. You have no tools or device capabilities."},{"role":"user","content":question.text}],"max_tokens":512,"stream":false}
	http=HTTPRequest.new();http.timeout=20;http.body_size_limit=65536;http.max_redirects=0;add_child(http)
	http.request_completed.connect(received.bind(ticket))
	var result=http.request("http://127.0.0.1:"+str(int(port.value))+"/v1/chat/completions",["Content-Type: application/json"],HTTPClient.METHOD_POST,JSON.stringify(payload))
	show_status("Waiting for local model (20 second timeout)" if result==OK else "Local request could not start")
func received(result,code,_headers,body,response_ticket):
	if response_ticket!=assistant.generation:return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:show_status("Local model unavailable / rejected request. No fallback.");return
	var parsed=JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("choices") is Array or parsed.choices.is_empty():show_status("Invalid local model response");return
	var first=parsed.choices[0]
	if not first is Dictionary or not first.get("message") is Dictionary or not first.message.get("content") is String:show_status("Invalid answer");return
	var content=first.message.content
	if assistant.accept_answer(response_ticket,content):answer.text=content;show_status("Local answer · untrusted plain text")
func preview(app):
	cancel_request()
	if OS.get_name()!="Windows":show_status("Windows app opening unavailable on this platform");return
	selected=assistant.preview(app)
	if selected.is_empty():show_status("Activate and grant app permission first");return
	confirmation.dialog_text="Open "+app+" once?\nFixed executable: "+selected.path+"\nNo arguments, model text or shell commands."
	confirmation.popup_centered(Vector2i(600,220))
func dispatch(executable):
	if OS.get_name()!="Windows" or not executable in Assistant.APPS.values() or not FileAccess.file_exists(executable):return false
	return OS.create_process(executable,[])>0
func export_audit():
	answer.text=JSON.stringify(assistant.state,"\t")
	var target="user://audit-export.json"
	var file=FileAccess.open(target,FileAccess.WRITE)
	if file==null:show_status("Export failed");return
	file.store_string(answer.text);file.close()
	show_status("Inspectable JSON: "+ProjectSettings.globalize_path(target)+" · no questions, answers or secrets stored")

func field(parent,placeholder):
	var control=LineEdit.new();control.placeholder_text=placeholder;parent.add_child(control);return control
func preview_google(kind,fields):
	cancel_request()
	google_selected=google.preview(kind,fields)
	if google_selected.is_empty():show_status("Google action blocked: activate, connect and check typed fields");return
	google_confirmation.dialog_text="Send one Gmail message?" if kind=="gmail" else "Create one event in your primary calendar? No attendees or invitations."
	google_confirmation.dialog_text+="\nAfter sending, cancellation cannot undo a provider action. Interrupted outcomes may be UNKNOWN; check Google before trying again."
	google_preview_text.text=JSON.stringify(google_selected.fields,"  ")+"\nConfirmation: "+google_selected.id+"\nSHA-256: "+google_selected.digest
	google_confirmation.popup_centered(Vector2i(720,500))

func _package_review_smoke():
	var smoke=preload("res://package_smoke.gd").new()
	await smoke.run(get_tree())
