# scenes/common/Carta.gd
extends Control
class_name Carta

# Constantes
const COLOR_CARTA_HOVER = Color(1.2, 1.2, 1.2)
const COLOR_CARTA_NORMAL = Color.WHITE
const ESCALA_HOVER_MULTIPLICADOR = 1.1

@export var palo := 0
@export var numero := 1

@onready var imagen = $Imagen
@onready var label_debug = $DebugValor

var dorso_texture: Texture2D = null
var es_jugable := false
var escala_original := Vector2.ONE

signal carta_clickeada(carta: Carta)

func mostrar_carta():
	var palos = ["Oro", "Copa", "Espada", "Basto"]
	var palo_nombre = palos[palo]
	var ruta_png = "res://assets/cartas-nuevas/carta_%s%d.png" % [palo_nombre, numero]
	var tex = load(ruta_png)
	imagen.texture = tex
	label_debug.visible = false

func mostrar_dorso():
	if dorso_texture == null:
		dorso_texture = load("res://assets/cartas-nuevas/carta_Dorso.png")
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
		scale = escala_original * ESCALA_HOVER_MULTIPLICADOR
		modulate = COLOR_CARTA_HOVER

func _on_mouse_exited():
	scale = escala_original
	modulate = COLOR_CARTA_NORMAL
