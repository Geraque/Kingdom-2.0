extends Node

signal enemy_attack(enemy_damage, flip_h)

signal enemy_died(enemy_position, state)

signal spawner_destroyed(spawner_position, multiplier)

signal day_time(state, day_count)

# active_mask: 1 = left, 2 = right, 3 = both
signal night_wave(day_count: int, active_mask: int)
