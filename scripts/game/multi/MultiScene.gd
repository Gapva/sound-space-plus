extends Node3D
class_name MultiScene

var mods:Mods = Mods.new()
var mapset:Mapset
var map_index:int

@onready var player_parent = $Players
@onready var local_player = $Players/LocalPlayer

var players:Array

func find_transform(index:int,total:int):
	match total:
		1:
			return Transform3D.IDENTITY.rotated(Vector3.UP,deg_to_rad(180)).translated(Vector3(3.5,0,SoundSpacePlus.settings.approach.distance/2))

func _ready():
	mods.no_fail = true
	
	local_player.network_player = Multiplayer.local_player
	local_player.name = str(Multiplayer.api.get_unique_id())
	local_player.set_multiplayer_authority(Multiplayer.api.get_unique_id())
	
	local_player.get_node("SyncManager").connect("finished",func(): rpc("ended"))
	local_player.get_node("Origin/Player").connect("failed",func(): rpc("ended"))
	
	players = Multiplayer.lobby.players.values()
	var i = 0
	for player in players:
		if player == Multiplayer.local_player: continue
		i += 1
		var scene = preload("res://prefabs/game/multi/MultiGameScene.tscn").instantiate()
		scene.root_path = get_path()
		scene.network_player = player
		scene.name = str(player.id)
		scene.set_multiplayer_authority(player.id)
		scene.transform = find_transform(i,players.size()-1)
		scene.get_node("Origin/Player/Cursor/DisplayName/Tag").text = player.nickname
		scene.get_node("Origin/Player/Cursor/DisplayName/Accuracy").text = player.accuracy
		var cursor:MeshInstance3D = scene.get_node("Origin/Player/Cursor/Real")
		cursor.material_override.albedo_color = player.color
		var ghost:MeshInstance3D = scene.get_node("Origin/Player/Cursor/Ghost")
		ghost.material_override.albedo_color = player.color
		print(
			"{name}'s player color is {color}".format({
				"name": player.nickname,
				"color": str(player.color)
			})
		)
		cursor.transparency = 0.8
		cursor.scale = Vector3.ONE * 0.3
		Multiplayer.mp_print("Adding %s" % player.id)
		player_parent.add_child(scene)

var players_ended = {}
@rpc("any_peer","call_local","reliable")
func ended():
	if !Multiplayer.api.is_server(): return
	var id = Multiplayer.api.get_remote_sender_id()
	players_ended[id] = true
	if players_ended.has_all(players.map(func(player): return player.id)):
		rpc("finish")

@rpc("authority","call_local","reliable")
func finish():
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

var players_done = {}
@rpc("any_peer","call_local","reliable")
func done():
	if !Multiplayer.api.is_server(): return
	var id = Multiplayer.api.get_remote_sender_id()
	players_done[id] = true
	if players_done.has_all(players.map(func(player): return player.id)):
		rpc("start")

@rpc("authority","call_local","reliable")
func start():
	local_player.sync_manager.start(-5)
