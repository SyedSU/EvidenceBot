extends SceneTree
func _initialize():
	var source=load("res://scripts/google_provider.gd")
	if source==null:quit(1);return
	var p=source.new();root.add_child(p)
	assert(not p.connected())
	var a=load("res://scripts/assistant.gd").new();a.path="user://provider-test.json";assert(a.start());a.activate("EvidenceBot")
	p.assistant=a
	assert(p.preview("gmail",{"to":"a@example.com","subject":"hello","body":"body"}).is_empty())
	# Explicit synthetic completion transport: no HTTP nodes, browser or real credentials.
	p.access_token="synthetic";p.expires=Time.get_ticks_msec()+60000;p.allowed=true
	var preview=p.preview("gmail",{"to":"a@example.com","subject":"hello","body":"body"})
	assert(not preview.is_empty())
	assert(not p.confirm(preview.id,"wrong"))
	p.transport=func(url,_headers,body):assert(url==p.Protocol.GMAIL);assert(JSON.parse_string(body).has("raw"));return OK
	assert(p.confirm(preview.id,preview.digest))
	assert(not p.confirm(preview.id,preview.digest))
	assert(p.preview("gmail",{"to":"a@example.com","subject":"hi","body":"hi"}).is_empty())
	p.completed(HTTPRequest.RESULT_SUCCESS,200,[], '{"id":"synthetic-provider-id"}'.to_utf8_buffer())
	assert(p.outcome=="Provider accepted request")
	preview=p.preview("calendar",{"summary":"test","start":"2026-11-01T10:00:00Z","end":"2026-11-01T11:00:00Z"})
	assert(not preview.is_empty());p.revoke_local();assert(p.pending.is_empty() and not p.connected())
	assert(not p.confirm(preview.id,preview.digest))
	p.access_token="synthetic";p.expires=Time.get_ticks_msec()+60000;p.allowed=true
	preview=p.preview("gmail",{"to":"a@example.com","subject":"hello","body":"body"})
	var other=load("res://scripts/assistant.gd").new();other.path=a.path;assert(other.start())
	p.transport=func(_url,_headers,_body):assert(false,"No transport after audit failure");return OK
	assert(not p.confirm(preview.id,preview.digest));assert(p.pending.is_empty())
	p.operation="gmail";p.completed(HTTPRequest.RESULT_TIMEOUT,0,[],PackedByteArray());assert("UNKNOWN" in p.outcome)
	p.operation="gmail";assert(not p.sign_in());p.cancel_action();assert("UNKNOWN" in p.outcome)
	p.operation="calendar";p.revoke_local();assert("UNKNOWN" in p.outcome)
	assert(TCPServer.new().has_method("get_local_port"))
	p.operation="token"
	p.completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"access_token":"bad\r\ntoken","expires_in":3600,"token_type":"Bearer","scope":p.Protocol.SCOPES}).to_utf8_buffer())
	assert(p.access_token.is_empty() and not p.connected())
	p.operation="gmail";var generation=p.request_generation;p.revoke_local();p.operation="token"
	p.completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"access_token":"synthetic","expires_in":3600,"token_type":"Bearer","scope":p.Protocol.SCOPES}).to_utf8_buffer(),generation)
	assert(p.access_token.is_empty())
	# Interrupted send uncertainty must survive revoke-all, token revocation and reconfiguration.
	p.operation="gmail";p.cancel_action();p.revoke_local()
	assert("UNKNOWN" in p.outcome,"Revoke-all hid interrupted send uncertainty")
	p.access_token="synthetic";p.expires=Time.get_ticks_msec()+60000;p.allowed=true;p.operation="calendar"
	p.transport=func(_url,_headers,_body):return OK
	assert(p.revoke_google())
	p.completed(HTTPRequest.RESULT_SUCCESS,200,[],PackedByteArray())
	assert("UNKNOWN" in p.outcome,"Token revocation hid interrupted Calendar outcome")
	assert(p.configure('{"installed":{"client_id":"sample.apps.googleusercontent.com"}}'))
	assert("UNKNOWN" in p.outcome,"Reconfiguration hid interrupted action")
	# Generic Cancel terminates loopback authorization and invalidates late token completion.
	p.server=TCPServer.new();assert(p.server.listen(0,"127.0.0.1")==OK)
	p.protocol.begin(p.server.get_local_port(),int(Time.get_ticks_msec()/1000))
	p.cancel_action();assert(p.server==null and p.protocol.oauth_state.is_empty())
	p.operation="token";generation=p.request_generation
	p.cancel_action();assert(p.operation.is_empty())
	p.completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"access_token":"synthetic","expires_in":3600,"token_type":"Bearer","scope":p.Protocol.SCOPES}).to_utf8_buffer(),generation)
	assert(p.access_token.is_empty())
	p.operation="";p.queue_free()
	print("PASS synthetic Google transport: activation, disconnected default, digest binding, durable intent, consumption, response, local revocation")
	quit()
