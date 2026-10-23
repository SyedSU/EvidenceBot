extends SceneTree
func _initialize():
	var source=load("res://scripts/google_protocol.gd")
	assert(source!=null,"Google protocol implementation missing")
	if source==null:quit(1);return
	var p=source.new()
	assert(p.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")=="E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
	assert(p.configure('{"installed":{"client_id":"sample.apps.googleusercontent.com","client_secret":"secret"}}'))
	var auth=p.begin(45678,100)
	assert(auth.begins_with("https://accounts.google.com/o/oauth2/v2/auth?"))
	assert("code_challenge_method=S256" in auth and "gmail.send" in auth)
	var state=p.oauth_state
	assert(p.callback("POST /oauth/callback?state="+state+"&code=x HTTP/1.1\r\n\r\n",101).is_empty())
	assert(p.callback("GET /oauth/callback?state="+state+"&state="+state+"&code=x HTTP/1.1\r\n\r\n",101).is_empty())
	assert(p.callback("GET /oauth/callback?state=wrong&code=x HTTP/1.1\r\n\r\n",101).is_empty())
	assert(p.callback("GET /oauth/callback?state="+state+"&code=x HTTP/1.1\r\n\r\n",101).code=="x")
	assert(p.callback("GET /oauth/callback?state="+state+"&code=x HTTP/1.1\r\n\r\n",101).is_empty())
	p.begin(45678,100);state=p.oauth_state
	assert(p.callback("GET /oauth/callback?state="+state+"&code=x HTTP/1.1\r\n\r\n",401).is_empty())
	assert(p.gmail({"to":"a@example.com","subject":"Hi\r\nBcc: x","body":"hi"}).is_empty())
	assert(p.gmail({"to":"a@example.com","subject":"こんにちは","body":"hi"}).has("raw"))
	assert(p.gmail({"to":"a\t@example.com","subject":"hello","body":"hi"}).is_empty())
	var long_raw=p.gmail({"to":"a@example.com","subject":"界".repeat(200),"body":"hello"}).raw
	var long_mime=Marshalls.base64_to_raw(long_raw.replace("-","+").replace("_","/")+"=".repeat((4-long_raw.length()%4)%4)).get_string_from_utf8()
	for word in long_mime.replace("\r\n"," ").split(" "):
		if word.begins_with("=?UTF-8?B?"):assert(word.length()<=75)
	var mime=Marshalls.base64_to_raw(p.gmail({"to":"a@example.com","subject":"Hi","body":"x".repeat(500)}).raw.replace("-","+").replace("_","/")+"==").get_string_from_utf8()
	for line in mime.split("\r\n"):assert(line.length()<=998)
	assert(p.calendar({"summary":"Meeting","start":"2026-11-01T10:00:00Z","end":"2026-11-01T09:00:00Z"}).is_empty())
	var event=p.calendar({"summary":"Meeting","start":"2026-11-01T10:00:00Z","end":"2026-11-01T11:00:00Z"})
	assert(event.has("id") and not event.has("attendees"))
	p.begin(45678,100);state=p.oauth_state
	assert(p.callback("GET /wrong?state="+state+"&code=x HTTP/1.1\r\n\r\n",101).is_empty())
	assert(p.callback("GET /oauth/callback?state="+state+"&code=x HTTP/1.1\r\nContent-Length: 0\r\n\r\n",101).is_empty())
	assert(p.callback("GET /oauth/callback?state="+state+"&code="+"x".repeat(9000)+" HTTP/1.1\r\n\r\n",101).is_empty())
	p.clear();assert(p.client_id.is_empty() and p.oauth_state.is_empty())
	print("PASS Google pure protocol: PKCE vector, authorization URL, callback bounds/state/duplicates/expiry/replay, payload validation")
	quit()
