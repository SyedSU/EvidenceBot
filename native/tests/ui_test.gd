extends SceneTree
func _initialize():call_deferred("run")
func run():
	var scene=load("res://main.tscn").instantiate()
	scene.assistant.path="user://synthetic-ui-"+str(Time.get_ticks_usec())+".json"
	root.add_child(scene)
	await process_frame
	assert(scene.status.text.contains("Ready"))
	assert(scene.assistant.state.permissions=={"apps":false,"local_ai":false})
	assert(not scene.assistant.active)
	assert(scene.answer.editable==false)
	scene.preview("calculator")
	assert(not scene.confirmation.visible) # Linux: never launch native apps
	scene.cancel_request()
	scene.queue_free()
	await process_frame
	print("PASS native UI startup and unavailable-platform guard (no external actions)")
	quit()
