extends Area3D
## An invisible zone that magic can hit. The owner sets `handler` to a function
## that takes the projectile and returns true if the projectile should stop.

var handler: Callable


func take_hit(p: Projectile) -> bool:
	if handler.is_valid():
		return handler.call(p)
	return false
