# scenes/common/Carta.gd
extends Control
class_name Carta

@export var palo := 0
@export var numero := 1

@onready var imagen = $Imagen
@onready var label_debug = $DebugValor

var dorso_texture = preload("res://assets/cartas/dorso.png")
var es_jugable := false
var escala_original := Vector2.ONE

signal carta_clickeada(carta: Carta)

func mostrar_carta():
	var ruta = "res://assets/cartas/%d_%s.png" % [numero, ["oro","copa","espada","basto"][palo]]
	imagen.texture = load(ruta)
	label_debug.visible = false

func mostrar_dorso():
	imagen.texture = dorso_texture
	label_debug.visible = false

func habilitar_click():
	es_jugable = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func deshabilitar_click():
	es_jugable = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready():
	deshabilitar_click()
	escala_original = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and es_jugable:
			carta_clickeada.emit(self)

func _on_mouse_entered():
	if es_jugable:
		scale = escala_original * 1.1
		modulate = Color(1.2, 1.2, 1.2)

func _on_mouse_exited():
	scale = escala_original
	modulate = Color.WHITE
