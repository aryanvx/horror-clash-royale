extends Node2D

# Game Configuration
const ELIXIR_RATE = 1.0  # Elixir per second
const MAX_ELIXIR = 10
const TOWER_HEALTH = 100

# Card Types
enum CardType { SKELETON, GHOST, ZOMBIE, DEMON }

# Game State
var player_elixir = 5.0
var enemy_elixir = 5.0
var player_tower_health = TOWER_HEALTH
var enemy_tower_health = TOWER_HEALTH
var game_over = false

# Card Data
var cards = {
	CardType.SKELETON: {"name": "Skeleton", "cost": 1, "health": 10, "damage": 2, "speed": 100, "color": Color.WHITE},
	CardType.GHOST: {"name": "Ghost", "cost": 2, "health": 15, "damage": 3, "speed": 80, "color": Color.CYAN},
	CardType.ZOMBIE: {"name": "Zombie", "cost": 3, "health": 30, "damage": 5, "speed": 50, "color": Color.GREEN},
	CardType.DEMON: {"name": "Demon", "cost": 5, "health": 50, "damage": 10, "speed": 60, "color": Color.RED}
}

# Unit tracking
var player_units = []
var enemy_units = []

# UI References
@onready var elixir_label = $CanvasLayer/ElixirLabel
@onready var player_health_label = $CanvasLayer/PlayerHealthLabel
@onready var enemy_health_label = $CanvasLayer/EnemyHealthLabel
@onready var game_over_label = $CanvasLayer/GameOverLabel
@onready var mute_button = $CanvasLayer/MuteButton
@onready var do_not_press_button = $CanvasLayer/DoNotPressButton

# Music Reference
@onready var music_player = $MusicPlayer

# Music State
var is_muted = false

func _ready():
	setup_game()
	game_over_label.visible = false

	# Ensure autoplay is OFF
	music_player.playing = false

	# Start playing music manually
	play_music()

	# Update mute button text
	update_mute_button()

	# Connect mute button signal
	if mute_button:
		mute_button.connect("pressed", Callable(self, "_on_mute_button_pressed"))
	if do_not_press_button:
		do_not_press_button.connect("pressed", Callable(self, "_on_do_not_press_button_pressed"))

	# Make sure DO NOT PRESS button is GIANT
	do_not_press_button.text = "DO NOT PRESS"
	do_not_press_button.size = Vector2(400, 120)
	do_not_press_button.position = Vector2(120, 180) # Adjust as needed to center

func setup_game():
	print("Horror Clash Royale - Game Started!")
	print("Deploy units by clicking the card buttons")

func play_music():
	if music_player:
		# If stream not set in Inspector, set it here (otherwise, just call play.)
		# music_player.stream = load("res://your_music_file.ogg")
		music_player.play()
		print("Music started!")

func toggle_mute():
	is_muted = !is_muted
	if music_player:
		music_player.stream_paused = is_muted
	update_mute_button()
	print("Music muted: ", is_muted)

func update_mute_button():
	if mute_button:
		mute_button.text = "Unmute" if is_muted else "Mute"

func _process(delta):
	if game_over:
		return

	# Regenerate elixir
	player_elixir = min(player_elixir + ELIXIR_RATE * delta, MAX_ELIXIR)
	enemy_elixir = min(enemy_elixir + ELIXIR_RATE * delta, MAX_ELIXIR)

	# Update UI
	update_ui()
	enemy_ai(delta)
	update_units(delta)
	check_game_over()

func update_ui():
	if elixir_label:
		elixir_label.text = "Elixir: %.1f" % player_elixir
	if player_health_label:
		player_health_label.text = "Your Tower: %d" % player_tower_health
	if enemy_health_label:
		enemy_health_label.text = "Enemy Tower: %d" % enemy_tower_health

func spawn_unit(card_type: CardType, is_player: bool, spawn_x: float):
	var unit_data = cards[card_type].duplicate()
	var unit = {
		"type": card_type,
		"position": Vector2(spawn_x, 500 if is_player else 100),
		"health": unit_data.health,
		"max_health": unit_data.health,
		"damage": unit_data.damage,
		"speed": unit_data.speed,
		"is_player": is_player,
		"attack_timer": 0.0,
		"color": unit_data.color
	}

	# Create visual sprite
	var sprite = ColorRect.new()
	sprite.size = Vector2(20, 20)
	sprite.position = unit.position
	sprite.color = unit_data.color
	if not is_player:
		sprite.modulate = Color.DARK_RED
	add_child(sprite)
	unit["sprite"] = sprite

	# Create health bar
	var health_bar = ColorRect.new()
	health_bar.size = Vector2(20, 3)
	health_bar.position = Vector2(unit.position.x, unit.position.y - 5)
	health_bar.color = Color.GREEN
	add_child(health_bar)
	unit["health_bar"] = health_bar

	if is_player:
		player_units.append(unit)
	else:
		enemy_units.append(unit)

	print("%s spawned %s!" % ["Player" if is_player else "Enemy", unit_data.name])

func update_units(delta):
	for unit in player_units:
		move_unit(unit, delta, false)
		update_unit_visual(unit)
	for unit in enemy_units:
		move_unit(unit, delta, true)
		update_unit_visual(unit)

	# Remove dead units
	for unit in player_units:
		if unit.health <= 0:
			remove_unit_visual(unit)
	for unit in enemy_units:
		if unit.health <= 0:
			remove_unit_visual(unit)

	player_units = player_units.filter(func(u): return u.health > 0)
	enemy_units = enemy_units.filter(func(u): return u.health > 0)

func update_unit_visual(unit):
	if unit.has("sprite") and unit.sprite:
		unit.sprite.position = unit.position
	if unit.has("health_bar") and unit.health_bar:
		unit.health_bar.position = Vector2(unit.position.x, unit.position.y - 5)
		var health_percent = float(unit.health) / float(unit.max_health)
		unit.health_bar.size.x = 20 * health_percent
		unit.health_bar.color = Color.RED.lerp(Color.GREEN, health_percent)

func remove_unit_visual(unit):
	if unit.has("sprite") and unit.sprite:
		unit.sprite.queue_free()
	if unit.has("health_bar") and unit.health_bar:
		unit.health_bar.queue_free()

func move_unit(unit, delta, move_down: bool):
	var target_found = false

	# Check for enemy units to attack
	var enemies = enemy_units if unit.is_player else player_units
	for enemy in enemies:
		var dist = unit.position.distance_to(enemy.position)
		if dist < 50:
			target_found = true
			unit.attack_timer += delta
			if unit.attack_timer >= 1.0:
				enemy.health -= unit.damage
				unit.attack_timer = 0.0
				print("%s attacked %s!" % [unit.type, enemy.type])
			break

	if not target_found:
		if move_down:
			unit.position.y += unit.speed * delta
			if unit.position.y >= 580:
				player_tower_health -= unit.damage
				unit.health = 0
				print("Enemy unit hit your tower!")
		else:
			unit.position.y -= unit.speed * delta
			if unit.position.y <= 20:
				enemy_tower_health -= unit.damage
				unit.health = 0
				print("Your unit hit enemy tower!")

func enemy_ai(delta):
	if randf() < 0.01:
		var affordable_cards = []
		for card_type in CardType.values():
			if cards[card_type].cost <= enemy_elixir:
				affordable_cards.append(card_type)

		if affordable_cards.size() > 0:
			var chosen_card = affordable_cards[randi() % affordable_cards.size()]
			var cost = cards[chosen_card].cost
			if enemy_elixir >= cost:
				enemy_elixir -= cost
				spawn_unit(chosen_card, false, randf_range(100, 500))

func deploy_card(card_type: CardType):
	if game_over:
		return

	var cost = cards[card_type].cost
	if player_elixir >= cost:
		player_elixir -= cost
		spawn_unit(card_type, true, randf_range(100, 500))
	else:
		print("Not enough elixir!")

func check_game_over():
	if player_tower_health <= 0:
		game_over = true
		game_over_label.text = "DEFEAT - The darkness consumed you..."
		game_over_label.visible = true
		print("Game Over - You Lost!")
	elif enemy_tower_health <= 0:
		game_over = true
		game_over_label.text = "VICTORY - You survived the horror!"
		game_over_label.visible = true
		print("Game Over - You Won!")

func _on_skeleton_button_pressed():
	deploy_card(CardType.SKELETON)

func _on_ghost_button_pressed():
	deploy_card(CardType.GHOST)

func _on_zombie_button_pressed():
	deploy_card(CardType.ZOMBIE)

func _on_demon_button_pressed():
	deploy_card(CardType.DEMON)

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func _on_mute_button_pressed():
	toggle_mute()

func _on_do_not_press_button_pressed():
	spawn_killer_clown()

func spawn_killer_clown():
	var clown = Sprite2D.new()
	clown.texture = load("res://clown.png")
	clown.position = Vector2(320, 240) # Center screen, adjust if needed
	clown.z_index = 100 # Bring to front
	add_child(clown)
