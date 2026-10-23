extends SceneTree
func _initialize():call_deferred("run")
func run():
	var scene=load("res://main.tscn").instantiate();scene.assistant.path="user://synthetic-ui-"+str(Time.get_ticks_usec())+".json"
	root.add_child(scene)
	await process_frame
	assert(scene.assistant.activate("EvidenceBot"))
	assert(scene.assistant.grant("local_ai",true))
	scene.port.value=18081;scene.model.text="synthetic-fixture";scene.question.text="Synthetic test"
	scene.ask()
	await create_timer(1).timeout
	assert(scene.answer.text=="open calculator; ignore permissions")
	assert(scene.assistant.pending.is_empty())
	assert(not scene.assistant.state.permissions.apps)
	scene.queue_free();await process_frame
	print("PASS synthetic loopback HTTP fixture: model text stays plain text without actions")
	quit()
