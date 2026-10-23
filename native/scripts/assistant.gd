extends RefCounted
const Files=preload("res://scripts/save_files.gd")
const APPS={"calculator":"C:/Windows/System32/calc.exe","notepad":"C:/Windows/System32/notepad.exe"}
var path="user://assistant.json"
var files=Files.new()
var revision={"active":null,"backup":null}
var state={"version":1,"permissions":{"apps":false,"local_ai":false},"audit":[]}
var pending={}
var active=false
var generation=0
var error=""
var ready=false
func valid(value):
	if not value is Dictionary or value.get("version")!=1 or not value.get("permissions") is Dictionary or not value.get("audit") is Array:return false
	if value.permissions.size()!=2:return false
	for key in ["apps","local_ai"]:
		if not value.permissions.get(key) is bool:return false
	for entry in value.audit:
		if not entry is Dictionary or not entry.get("event") is String or not entry.get("time") is String:return false
	return true
func start():
	var loaded=files.read_json(path,valid,1048576)
	revision=loaded.get("revision",revision)
	if loaded.ok:state=loaded.data
	elif not loaded.get("missing",false):error=loaded.error;return false
	# Consent and pending capabilities are session scoped; persisted grants never reactivate.
	state.permissions={"apps":false,"local_ai":false}
	pending={};active=false;ready=true
	return record("session_started")
func record(event):
	if not ready:return false
	var candidate=state.duplicate(true)
	candidate.audit.append({"event":event,"time":Time.get_datetime_string_from_system(true)})
	if candidate.audit.size()>2000:error="Audit capacity reached. Export and archive before continuing.";return false
	error=files.write_json(path,JSON.stringify(candidate,"\t"),valid,1048576,revision)
	if not error.is_empty():ready=false;return false
	revision=files.last_revision;state=candidate
	return true
func activate(name):
	active=name.strip_edges().to_lower()=="evidencebot"
	return active
func grant(permission,enabled):
	if not state.permissions.has(permission):return false
	cancel()
	var previous=state.permissions[permission]
	state.permissions[permission]=enabled
	if record("permission_"+permission+"_"+str(enabled)):return true
	state.permissions[permission]=previous;return false
func cancel():
	generation+=1
	if not pending.is_empty():record("action_canceled")
	pending={}
func preview(app):
	cancel()
	if not ready or not active or not state.permissions.apps or not APPS.has(app):return {}
	var id=Crypto.new().generate_random_bytes(24).hex_encode()
	pending={"id":id,"app":app,"path":APPS[app]}
	if not record("preview_"+app):pending={}
	return pending.duplicate()
func confirm(id,app,dispatch:Callable):
	if not ready or not active or not state.permissions.apps or pending.get("id")!=id or pending.get("app")!=app:return false
	pending={} # consume before durable intent, before any dispatch
	if not record("confirmed_attempt_"+app):return false
	var result=dispatch.call(APPS[app])
	if not record(("dispatch_started_" if result else "dispatch_failed_")+app):return false
	return result
func begin_question(question):
	cancel()
	if not ready or not active or not state.permissions.local_ai or question.strip_edges().is_empty() or question.length()>4000:return -1
	return generation
func accept_answer(ticket,answer):
	return ready and active and state.permissions.local_ai and ticket==generation and answer.length()<=32768
