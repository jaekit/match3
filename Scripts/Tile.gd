class_name Tile extends Sprite


enum Colour {
	None = 0,
	Red = 1,
	Blue = 2,
	Green = 4,
	Orange = 8,
	Wild = (1 << 4) - 1
}


enum Type {
	Normal = 1,
	Horizontal = 2,
	Vertical = 4,
	Bomb = 8,
	Rainbow = 16,
}

var colour: int
var row: int
var col: int
var type: int setget set_type


var _tween: Tween


func _init(colour: int, row: int, col: int) -> void:
	self.colour = colour
	self.row = row
	self.col = col
	position = Global.OFFSET + Vector2((Global.TILE_SIZE.x + Global.MARGIN.x) * col, (Global.TILE_SIZE.y + Global.MARGIN.y) * row)
	material = ShaderMaterial.new()
	material.shader = preload("res://Scripts/Tile.gdshader")
	type = Type.Normal


func _ready() -> void:
	_tween = Tween.new()
	add_child(_tween)
	
	if colour == Colour.Red:
		texture = preload("res://Assets/Red1.png")
	elif colour == Colour.Blue:
		texture = preload("res://Assets/Blue1.png")
	elif colour == Colour.Green:
		texture = preload("res://Assets/Green1.png")
	elif colour == Colour.Orange:
		texture = preload("res://Assets/Orange1.png")
	material.set_shader_param("base_texture", texture)
	material.set_shader_param("modifier_texture", preload("res://Assets/HShader.png"))
	material.set_shader_param("modifier_texture_2", preload("res://Assets/VShader.png"))
	material.set_shader_param("outline_texture", preload("res://Assets/Outline.png"))


func queue_move(direction: Vector2) -> void:
	row += direction.y
	col += direction.x
	_tween.interpolate_property(self, "position", position, position + direction * (Global.TILE_SIZE + Global.MARGIN), Global.DROP_TIME)
	_tween.start()


func set_type(value: int) -> void:
	if value == Type.Rainbow:
		colour = Colour.None
	type = value
	material.set_shader_param("type", value)
