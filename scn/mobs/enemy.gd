extends CharacterBody2D
class_name Enemy

enum {
	IDLE,
	ATTACK,
	CHASE,
	DAMAGE,
	DEATH,
	RECOVER,
}
var state: int = 0:
	set(value):
		state = value
		match state:
			IDLE:
				idle_state()
			ATTACK:
				attack_state()
			DAMAGE:
				damage_state()
			DEATH:
				death_state()
			RECOVER:
				recover_state()
			
@onready var animationPlayer: AnimationPlayer = $AnimationPlayer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


var direction = Vector2.ZERO
var damage = 20
var move_speed = 150

func _ready():
	state = CHASE

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if state == CHASE:
		chase_state()
		
	move_and_slide()

func _on_attack_range_body_entered(_body: Node2D) -> void:
	state = ATTACK
	
func idle_state():
	velocity.x = 0
	animationPlayer.play("Idle")
	state = CHASE
	
func attack_state():
	velocity.x = 0
	animationPlayer.play("Attack")
	await animationPlayer.animation_finished
	state = RECOVER

func chase_state():
	animationPlayer.play("Run")
	direction = (Global.player_pos - self.position).normalized()
	if direction.x < 0:
		sprite.flip_h = true
		$AttackDirection.scale=Vector2(-1,1)
	else:
		sprite.flip_h = false
		$AttackDirection.scale=Vector2(1,1)
	velocity.x = direction.x * move_speed

func damage_state():
	velocity.x = 0
	damage_anim()
	animationPlayer.play("Damage")
	await animationPlayer.animation_finished
	state = IDLE
	
func death_state():
	velocity.x = 0
	animationPlayer.play("Death")
	await animationPlayer.animation_finished
	queue_free()
	
func recover_state():
	velocity.x = 0
	animationPlayer.play("Recover")
	await animationPlayer.animation_finished
	if $AttackDirection/AttackRange.has_overlapping_bodies():
		state = ATTACK
	else:
		state = IDLE
	
func _on_hit_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		Signals.emit_signal("enemy_attack", damage, sprite.flip_h)
		return

	if area.is_in_group("shop_hurtbox"):
		var target = area.get_owner()
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", damage)
		return

	print("Entered by:", area.name, " path:", str(area.get_path()))



func damage_anim():
	direction = (Global.player_pos - self.position).normalized()
	if direction.x < 0:
		velocity.x = 200
	elif direction.x > 0:
		velocity.x = -200
	var tween = get_tree().create_tween()
	tween.tween_property(self, "velocity", Vector2.ZERO, 0.1)


func _on_run_timeout() -> void:
	move_speed = move_toward(move_speed, randi_range(120, 170), 100)
