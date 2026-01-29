extends CharacterBody2D

const SPEED = 150.0

enum {
	MOVE,
	ATTACK,
	COMBO1,
	COMBO2,
	BLOCK,
	SLIDE,
	DAMAGE,
	CAST,
	DEATH
}

var state = MOVE
var run_speed = 1
var combo = false
var attack_cooldown = false
var damage_multiplier = 1
var damage_current
var recovery = false

@onready var animPlayer: AnimationPlayer = $AnimationPlayer
@onready var animatedSprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats: CanvasLayer = $stats
@onready var leaves: GPUParticles2D = $Leaves
@onready var smack: AudioStreamPlayer2D = $Sounds/Smack



func _ready():
	Signals.connect("enemy_attack", Callable(self, "_on_damage_received"))
	

func _physics_process(delta: float) -> void:
		# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	if velocity.y > 0:
		animPlayer.play("Fall")
		
	Global.player_damage = (Global.damage_basic + Global.char_damage_bonus()) * damage_multiplier
		
	match state:
		MOVE:
			move_state()
		ATTACK:
			attack_state()
		COMBO1:
			combo1_state()
		COMBO2:
			combo2_state()
		BLOCK:
			block_state()
		SLIDE:
			slide_state()
		DEATH:
			death_state()
		DAMAGE:
			damage_state()
		
	move_and_slide()
	
	Global.player_pos = self.position

func move_state():
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED * run_speed
		if velocity.y == 0:
			if run_speed == 1:
				animPlayer.play("Walk")
			else:
				animPlayer.play("Run")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if velocity.y == 0:
			animPlayer.play("Idle")
	if direction == -1:
		animatedSprite.flip_h = true
		$AttackDirection.scale=Vector2(-1,1)
	elif direction == 1:
		animatedSprite.flip_h = false
		$AttackDirection.scale=Vector2(1,1)
		
	if Input.is_action_pressed("run") and !recovery:
		run_speed = 2
		stats.stamina -= stats.run_cost
	else:
		run_speed = 1
		
	if Input.is_action_just_pressed("attack"):
		if !recovery:
			stats.stamina_cost = stats.attack_cost
			if !attack_cooldown and stats.stamina > stats.stamina_cost:
				state = ATTACK
		
	if Input.is_action_pressed("block") and velocity.x != 0:
		if !recovery:
			stats.stamina_cost = stats.slide_cost
			if  stats.stamina > stats.stamina_cost:
				state = SLIDE
	elif Input.is_action_pressed("block") and velocity.x == 0:
		if !recovery:
			if stats.stamina > 1:
				state = BLOCK
	

func block_state():
	stats.stamina -= stats.block_cost
	velocity.x = move_toward(velocity.x, 0, SPEED)
	animPlayer.play("Block")
	if Input.is_action_just_released("block") or recovery:
		state = MOVE
		
func slide_state():
	animPlayer.play("Slide")
	await animPlayer.animation_finished
	state = MOVE

func attack_state():
	stats.stamina_cost = stats.attack_cost
	damage_multiplier = 1
	if Input.is_action_just_pressed("attack") and combo and stats.stamina > stats.stamina_cost:
		state = COMBO1
	velocity.x = move_toward(velocity.x, 0, SPEED)
	animPlayer.play("Attack")
	await animPlayer.animation_finished
	attack_freeze()
	state = MOVE
	
func death_state():
	velocity.x = 0
	animPlayer.play("Death")
	await animPlayer.animation_finished
	queue_free()
	get_tree().change_scene_to_file.bind("res://scn/menu/menu.tscn").call_deferred()

func combo1_state():
	stats.stamina_cost = stats.attack_cost
	damage_multiplier = 1.2
	if Input.is_action_just_pressed("attack") and combo and stats.stamina > stats.stamina_cost:
		state = COMBO2
	animPlayer.play("Attack2")
	await animPlayer.animation_finished
	state = MOVE

func combo2():
	combo = true
	await animPlayer.animation_finished
	combo = false

func combo2_state():
	damage_multiplier = 2
	animPlayer.play("Attack3")
	await animPlayer.animation_finished
	state = MOVE
	
func combo1():
	combo = true
	await animPlayer.animation_finished
	combo = false

func attack_freeze():
	attack_cooldown = true
	await get_tree().create_timer(0.5).timeout
	attack_cooldown = false

func damage_state():
	animPlayer.play("Damage")
	await animPlayer.animation_finished
	state = MOVE
	
func _on_damage_received(enemy_damage):
	smack.play()
	if state == BLOCK:
		enemy_damage /= 2
	elif state == SLIDE:
		enemy_damage = 0
	else:
		state = DAMAGE
		damage_anim()
	stats.health -= enemy_damage
	if stats.health <= 0:
		stats.health = 0
		state = DEATH
	else:
		state = DAMAGE
	

func _on_stats_no_stamina() -> void:
	recovery = true
	await get_tree().create_timer(2).timeout
	recovery = false

func damage_anim():
	animatedSprite.modulate = Color(1,0,0,1)
	if animatedSprite.flip_h:
		velocity.x = 200
	else:
		velocity.x = -200
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(self, "velocity", Vector2.ZERO, 0.1)
	tween.parallel().tween_property(animatedSprite, "modulate", Color(1,1,1,1), 0.1)

func steps():
	leaves.emitting = true
	leaves.one_shot = true
