extends Node
signal changed(message)
const Protocol=preload("res://scripts/google_protocol.gd")
var protocol=Protocol.new()
var assistant
var allowed=false
var access_token=""
var expires=0
var pending={}
var outcome="Unconfigured · live provider acceptance UNRUN"
var transport:Callable
var http:HTTPRequest
var server:TCPServer
var peer:StreamPeerTCP
var buffer=""
var peer_deadline=0
var operation=""
var request_generation=0
func connected():return allowed and not access_token.is_empty() and Time.get_ticks_msec()<expires
func status(value):outcome=value;changed.emit(value)
func configure(raw):
	revoke_local()
	var ok=protocol.configure(raw)
	status("Client configured in memory; disconnected" if ok else "Invalid installed desktop client JSON")
	return ok
func sign_in():
	if not operation.is_empty() or connected() or not pending.is_empty() or protocol.client_id.is_empty() or not allowed or not assistant.ready or not assistant.active:return false
	stop_listener();server=TCPServer.new()
	if server.listen(0,"127.0.0.1")!=OK:status("Loopback listener failed");return false
	var url=protocol.begin(server.get_local_port(),int(Time.get_ticks_msec()/1000))
	if url.is_empty():stop_listener();return false
	if OS.shell_open(url)!=OK:stop_listener();status("Browser could not open");return false
	status("Waiting for Google consent (5 minutes)");return true
func stop_listener():
	if peer!=null:peer.disconnect_from_host();peer=null
	if server!=null:server.stop();server=null
	buffer=""
func _process(_delta):
	if server==null:return
	var now=int(Time.get_ticks_msec()/1000)
	if now>=protocol.deadline:stop_listener();protocol.oauth_state="";status("Authorization expired");return
	if peer==null and server.is_connection_available():peer=server.take_connection();peer_deadline=now+10;buffer=""
	if peer==null:return
	peer.poll()
	if now>=peer_deadline or peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:peer.disconnect_from_host();peer=null;buffer="";return
	var size=peer.get_available_bytes()
	if size>0:
		if size+buffer.length()>8192:peer.disconnect_from_host();peer=null;buffer="";return
		buffer+=peer.get_data(size)[1].get_string_from_ascii()
	if not buffer.contains("\r\n\r\n"):return
	var token_fields=protocol.callback(buffer,now)
	var success=not token_fields.is_empty()
	var response="Authorization received. Return to EvidenceBot." if success else "Invalid callback. Return to EvidenceBot."
	peer.put_data(("HTTP/1.1 "+("200 OK" if success else "400 Bad Request")+"\r\nContent-Type: text/plain\r\nConnection: close\r\nContent-Length: "+str(response.length())+"\r\n\r\n"+response).to_ascii_buffer())
	if success:
		stop_listener();protocol.verifier="";operation="token"
		if request(Protocol.TOKEN,["Content-Type: application/x-www-form-urlencoded"],protocol.form(token_fields))!=OK:
			operation="";status("Authorization request could not start; disconnected")
	else:peer.disconnect_from_host();peer=null;buffer=""
func request(url,headers,body):
	request_generation+=1
	if transport.is_valid():return transport.call(url,headers,body)
	if http!=null:http.cancel_request();http.queue_free()
	http=HTTPRequest.new();http.timeout=30;http.body_size_limit=65536;http.max_redirects=0;add_child(http);http.request_completed.connect(completed.bind(request_generation))
	return http.request(url,headers,HTTPClient.METHOD_POST,body)
func preview(kind,fields):
	pending={}
	if not operation.is_empty() or not connected() or not assistant.ready or not assistant.active or kind not in ["gmail","calendar"]:return {}
	var payload=protocol.gmail(fields) if kind=="gmail" else protocol.calendar(fields)
	if payload.is_empty():return {}
	var snapshot=JSON.stringify(payload)
	pending={"id":Crypto.new().generate_random_bytes(24).hex_encode(),"digest":snapshot.sha256_text(),"kind":kind,"payload":snapshot,"fields":fields.duplicate(true)}
	if not assistant.record("preview_google_"+kind):pending={}
	return pending.duplicate(true)
func confirm(id,digest):
	if not connected() or not assistant.active or not assistant.ready or pending.get("id")!=id or pending.get("digest")!=digest or pending.get("payload","").sha256_text()!=digest:return false
	var action=pending.duplicate(true);pending={}
	if not assistant.record("confirmed_attempt_google_"+action.kind):return false
	operation=action.kind
	status("Request in progress; interruption may leave outcome UNKNOWN")
	var result=request(Protocol.GMAIL if action.kind=="gmail" else Protocol.CALENDAR,["Authorization: Bearer "+access_token,"Content-Type: application/json"],action.payload)
	if result!=OK:status("Request could not start; no automatic retry");operation="";return false
	return true
func completed(result,code,_headers,body,response_generation=-1):
	if response_generation!=-1 and response_generation!=request_generation:return
	var op=operation;operation=""
	if op.is_empty():return
	if result!=HTTPRequest.RESULT_SUCCESS:
		status("Outcome UNKNOWN; check Google before any new attempt" if op in ["gmail","calendar","revoke"] else "Authorization transport failed; disconnected");return
	if op=="token":
		var value=JSON.parse_string(body.get_string_from_utf8())
		if code!=200 or not value is Dictionary or not value.get("access_token") is String or value.access_token.is_empty() or value.access_token.length()>8192 or not value.get("expires_in") is float or value.expires_in<=0 or value.expires_in>86400 or value.get("token_type","").to_lower()!="bearer":status("Authorization rejected; disconnected");return
		for character in value.access_token:
			if character.unicode_at(0)<33 or character.unicode_at(0)>126:status("Invalid authorization token; disconnected");return
		var scopes=str(value.get("scope","")).split(" ")
		for scope in Protocol.SCOPES.split(" "):
			if scope not in scopes:status("Required scopes not granted; disconnected");return
		access_token=value.access_token;expires=Time.get_ticks_msec()+int(value.expires_in*1000);status("Connected for this session; Google authorization persists until revoked");return
	if op=="revoke":status("Google token revocation accepted" if code==200 else "Google revocation not confirmed; review Google account permissions");return
	var data=JSON.parse_string(body.get_string_from_utf8())
	var accepted=code>=200 and code<300 and data is Dictionary and data.get("id") is String
	status("Provider accepted request" if accepted else "Provider response did not confirm acceptance; check Google before any new attempt")
	assistant.record("google_"+op+("_accepted" if accepted else "_unconfirmed"))
func revoke_local():
	request_generation+=1
	pending={};allowed=false;access_token="";expires=0;stop_listener();protocol.clear()
	if http!=null:http.cancel_request();http.queue_free();http=null
	var unknown=operation in ["gmail","calendar","revoke"];operation=""
	status("Local access cleared; outcome UNKNOWN, check Google" if unknown else "Local access cleared; Google authorization may persist")
func revoke_google():
	var token=access_token
	revoke_local()
	if token.is_empty():status("No session token; revoke EvidenceBot in your Google account permissions");return false
	operation="revoke"
	if request(Protocol.REVOKE,["Content-Type: application/x-www-form-urlencoded"],protocol.form({"token":token}))!=OK:operation="";status("Google revocation not confirmed; review account permissions");return false
	status("Local access cleared; requesting Google token revocation");return true
func cancel_action():
	pending={}
	if operation not in ["gmail","calendar"]:return
	request_generation+=1
	if http!=null:http.cancel_request();http.queue_free();http=null
	operation="";status("Outcome UNKNOWN after cancellation; check Google before any new attempt")
