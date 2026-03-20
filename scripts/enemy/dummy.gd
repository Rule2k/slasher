extends StaticBody3D

var health: float = 100.0

func take_damage(amount: float) -> void:
	health -= amount
	print("Dummy touché ! Dégâts: %s — Vie restante: %s" % [amount, health])
