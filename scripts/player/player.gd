extends CharacterBody3D

# Références aux modules (disponibles pour communication inter-modules)
@onready var camera_controller: Node = $CameraController
@onready var movement_controller: Node = $MovementController
@onready var state_machine: Node = $StateMachine
