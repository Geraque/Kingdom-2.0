extends ParallaxBackground

@export var auto_scroll: bool = true
@export var scroll_speed: float = 100.0

@onready var _layer_1: ParallaxLayer = $ParallaxLayer
@onready var _sprite_1: Sprite2D = $ParallaxLayer/BackgroundLayer1
@onready var _layer_2: ParallaxLayer = $ParallaxLayer2
@onready var _sprite_2: Sprite2D = $ParallaxLayer2/BackgroundLayer2
@onready var _layer_3: ParallaxLayer = $ParallaxLayer3
@onready var _sprite_3: Sprite2D = $ParallaxLayer3/BackgroundLayer3

var _base_scale_1: Vector2
var _base_scale_2: Vector2
var _base_scale_3: Vector2

func _ready() -> void:
	# Сохранение исходных масштабов из сцены (чтобы при resize не происходило "зумирование" фона).
	_base_scale_1 = _sprite_1.scale
	_base_scale_2 = _sprite_2.scale
	_base_scale_3 = _sprite_3.scale

	var vp: Viewport = get_viewport()
	var cb: Callable = Callable(self, "_update_fit")
	if not vp.is_connected("size_changed", cb):
		vp.connect("size_changed", cb)

	_update_fit()
	set_process(auto_scroll)

func _process(delta: float) -> void:
	if auto_scroll:
		scroll_offset.x -= scroll_speed * delta

func _update_fit() -> void:
	# Используется размер окна, чтобы фон заполнял fullscreen.
	# При этом текстуры НЕ масштабируются — вместо этого включается тайлинг (repeat).
	var win_sizei: Vector2i = DisplayServer.window_get_size()
	var win_size: Vector2 = Vector2(float(win_sizei.x), float(win_sizei.y))

	# Учитывается масштаб CanvasLayer (ParallaxBackground наследуется от CanvasLayer).
	var gs: Vector2 = scale
	if gs.x == 0.0:
		gs.x = 1.0
	if gs.y == 0.0:
		gs.y = 1.0

	var target_local: Vector2 = Vector2(win_size.x / gs.x, win_size.y / gs.y)

	_tile_sprite(_layer_1, _sprite_1, _base_scale_1, target_local)
	_tile_sprite(_layer_2, _sprite_2, _base_scale_2, target_local)
	_tile_sprite(_layer_3, _sprite_3, _base_scale_3, target_local)

func _tile_sprite(layer: ParallaxLayer, sprite: Sprite2D, base_scale: Vector2, target_local: Vector2) -> void:
	var tex: Texture2D = sprite.texture
	if tex == null:
		return

	var tex_sizei: Vector2i = tex.get_size()
	if tex_sizei.x <= 0 or tex_sizei.y <= 0:
		return
	var tex_size: Vector2 = Vector2(float(tex_sizei.x), float(tex_sizei.y))

	# Восстановление исходного масштаба из сцены.
	sprite.scale = base_scale

	# Включение повторения текстуры и отрисовка прямоугольника (region) размером под экран.
	# Так сохраняется "масштаб мира" как в маленьком окне, но экран полностью заполняется.
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true

	var sx: float = base_scale.x
	var sy: float = base_scale.y
	if sx == 0.0:
		sx = 1.0
	if sy == 0.0:
		sy = 1.0

	# Размер region в координатах текстуры (пиксели текстуры), чтобы после scale покрыть target_local.
	var region_size: Vector2 = Vector2(target_local.x / sx, target_local.y / sy)

	# Небольшой запас, чтобы при авто-скролле/параллаксе не появлялись пустые края.
	region_size.x += tex_size.x * 2.0
	region_size.y += tex_size.y * 2.0

	sprite.region_rect = Rect2(Vector2.ZERO, region_size)
	# Центрирование под текущий размер.
	sprite.position = target_local / 2.0

	# Обёртка смещения по X на ширину одного тайла (как было настроено в сцене).
	layer.motion_mirroring = Vector2(tex_size.x * sx, 0.0)
