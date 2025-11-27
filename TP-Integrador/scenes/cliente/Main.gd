# Main.gd
extends Node2D

func _ready():
	# Cargar el menú inicial donde el usuario elige servidor o cliente
	call_deferred("_cambiar_a_menu")

func _cambiar_a_menu():
	get_tree().change_scene_to_file("res://scenes/menu/MenuInicial.tscn")
