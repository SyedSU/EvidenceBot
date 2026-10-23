extends SceneTree
func _initialize():
	var a=load("res://scripts/assistant.gd").new()
	a.path="user://corrupt-test-"+str(Time.get_ticks_usec())+".json"
	var file=FileAccess.open(a.path,FileAccess.WRITE);file.store_string("broken");file.close()
	assert(not a.start())
	assert(not a.grant("apps",true))
	assert(a.preview("calculator").is_empty())
	assert(FileAccess.get_file_as_string(a.path)=="broken")
	print("PASS corrupt save preserved; all actions blocked")
	quit()
