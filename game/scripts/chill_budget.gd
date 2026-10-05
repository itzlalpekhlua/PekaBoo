extends RefCounted
## Targets a 60 FPS frame budget by scaling only 3D pixels, never the UI.
## Hysteresis and a warm-up period avoid oscillation and reacting to shader compilation.

const TARGET_FRAME := 1.0 / 55.0
var base_scale := 1.0
var minimum_scale := 0.5
var _warmup := 3.0
var _time := 0.0
var _frames := 0
var _fast_windows := 0

func reset(viewport: Viewport, mobile: bool) -> void:
	base_scale = viewport.scaling_3d_scale
	minimum_scale = minf(base_scale, 0.5 if mobile else 0.65)
	_warmup = 3.0
	_time = 0.0
	_frames = 0
	_fast_windows = 0

func update(viewport: Viewport, delta: float) -> void:
	if _warmup > 0.0:
		_warmup -= delta
		return
	_time += delta
	_frames += 1
	if _time < 1.5:
		return
	var average := _time / maxi(1, _frames)
	var current := viewport.scaling_3d_scale
	if average > TARGET_FRAME:
		# A heavily loaded GPU benefits from a larger first step.
		var step := 0.08 if average > 1.0 / 40.0 else 0.04
		viewport.scaling_3d_scale = maxf(minimum_scale, current - step)
		_fast_windows = 0
	elif average < 1.0 / 58.0:
		_fast_windows += 1
		if _fast_windows >= 3:
			viewport.scaling_3d_scale = minf(base_scale, current + 0.025)
			_fast_windows = 0
	else:
		_fast_windows = 0
	_time = 0.0
	_frames = 0
