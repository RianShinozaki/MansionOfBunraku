class_name Meatball

extends Grabbable

func on_dropped():
	Player.instance.play_eating_sfx()
	queue_free()
