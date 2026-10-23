extends RefCounted
const SCOPES="https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/calendar.events.owned"
const TOKEN="https://oauth2.googleapis.com/token"
const REVOKE="https://oauth2.googleapis.com/revoke"
const GMAIL="https://gmail.googleapis.com/gmail/v1/users/me/messages/send"
const CALENDAR="https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=none"
var client_id=""
var client_secret=""
var verifier=""
var oauth_state=""
var redirect_uri=""
var deadline=0
func base64url(bytes):return Marshalls.raw_to_base64(bytes).replace("+","-").replace("/","_").replace("=","")
func challenge(value):return base64url(value.sha256_buffer())
func configure(raw):
	if raw.length()>8192:return false
	var parsed=JSON.parse_string(raw)
	if not parsed is Dictionary or not parsed.get("installed") is Dictionary:return false
	var config=parsed.installed
	if not config.get("client_id") is String or not config.client_id.ends_with(".apps.googleusercontent.com") or config.client_id.length()>256:return false
	if not config.get("client_secret","") is String or config.get("client_secret","").length()>256:return false
	client_id=config.client_id;client_secret=config.get("client_secret","");return true
func form(values):
	var parts=PackedStringArray()
	for key in values:parts.append(str(key).uri_encode()+"="+str(values[key]).uri_encode())
	return "&".join(parts)
func begin(port,now):
	if client_id.is_empty() or port<1024 or port>65535:return ""
	verifier=base64url(Crypto.new().generate_random_bytes(32))
	oauth_state=base64url(Crypto.new().generate_random_bytes(32));deadline=now+300
	redirect_uri="http://127.0.0.1:"+str(port)+"/oauth/callback"
	return "https://accounts.google.com/o/oauth2/v2/auth?"+form({"client_id":client_id,"redirect_uri":redirect_uri,"response_type":"code","scope":SCOPES,"state":oauth_state,"code_challenge":challenge(verifier),"code_challenge_method":"S256","access_type":"online","prompt":"consent"})
func callback(raw,now):
	if oauth_state.is_empty() or now>=deadline or raw.length()>8192 or not raw.ends_with("\r\n\r\n"):return {}
	var lines=raw.split("\r\n")
	var first=lines[0].split(" ")
	if first.size()!=3 or first[0]!="GET" or first[2]!="HTTP/1.1" or not first[1].begins_with("/oauth/callback?"):return {}
	for line in lines:
		if line.to_lower().begins_with("content-length:") or line.to_lower().begins_with("transfer-encoding:"):return {}
	var query={}
	for field in first[1].substr(16).split("&"):
		var pair=field.split("=",true,1)
		if pair.size()!=2:return {}
		var key=pair[0].uri_decode()
		if query.has(key):return {}
		query[key]=pair[1].uri_decode()
	if query.get("state")!=oauth_state or not query.get("code") is String or query.code.is_empty() or query.code.length()>4096:return {}
	oauth_state=""
	return {"code":query.code,"client_id":client_id,"client_secret":client_secret,"redirect_uri":redirect_uri,"grant_type":"authorization_code","code_verifier":verifier}
func gmail(value):
	if value.size()!=3:return {}
	for key in ["to","subject","body"]:
		if not value.get(key) is String:return {}
	var to=value.to
	for character in to:
		var point=character.unicode_at(0)
		if point<33 or point>126:return {}
	if to.length()>254 or to.is_empty() or to.contains("\r") or to.contains("\n") or to.contains(" ") or to.contains("<") or to.contains(">") or to.contains(",") or to.contains(";") or to.contains(":") or to.count("@")!=1:return {}
	if value.subject.length()>200 or value.subject.contains("\r") or value.subject.contains("\n") or value.body.length()>20000:return {}
	var words=PackedStringArray();var chunk=""
	for character in value.subject:
		if (chunk+character).to_utf8_buffer().size()>42:
			words.append("=?UTF-8?B?"+Marshalls.raw_to_base64(chunk.to_utf8_buffer())+"?=");chunk=""
		chunk+=character
	if not chunk.is_empty():words.append("=?UTF-8?B?"+Marshalls.raw_to_base64(chunk.to_utf8_buffer())+"?=")
	var subject="\r\n ".join(words)
	var encoded_body=Marshalls.raw_to_base64(value.body.to_utf8_buffer())
	var wrapped=""
	for offset in range(0,encoded_body.length(),76):wrapped+=encoded_body.substr(offset,76)+"\r\n"
	return {"raw":base64url(("To: "+to+"\r\nSubject: "+subject+"\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"+wrapped).to_utf8_buffer())}
func utc(value):
	if not value is String or value.length()!=20 or value.substr(10,1)!="T" or not value.ends_with("Z"):return -1
	var stamp=Time.get_unix_time_from_datetime_string(value)
	if Time.get_datetime_string_from_unix_time(stamp)+"Z"!=value:return -1
	return stamp
func calendar(value):
	if value.size()!=3 or not value.get("summary") is String or value.summary.is_empty() or value.summary.length()>200:return {}
	var start=utc(value.get("start"));var end=utc(value.get("end"))
	if start<0 or end<=start:return {}
	return {"id":Crypto.new().generate_random_bytes(20).hex_encode(),"summary":value.summary,"start":{"dateTime":value.start},"end":{"dateTime":value.end}}
func clear():client_id="";client_secret="";verifier="";oauth_state="";redirect_uri="";deadline=0
