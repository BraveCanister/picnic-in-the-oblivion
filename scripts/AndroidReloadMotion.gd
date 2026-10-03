extends RefCounted
# First measured QA candidate: replay detects 6 mixed C gestures and no A/B events.
const WINDOW_MSEC = 450
const COOLDOWN_MSEC = 1500
const ROTATION_SPEED = 2.0
const LINEAR_PULSE = 4.0
var samples = []
var last_sample = -1
var last_trigger = -100000

func reset(now: int):
	samples.clear()
	last_sample = -1
	last_trigger = now # Suppress initialization/resume movement as well.

func feed(now: int, linear: Vector3, gyro: Vector3, allowed: bool) -> bool:
	if not allowed:
		reset(now)
		return false
	if last_sample >= 0 and (now <= last_sample or now - last_sample > 100):
		reset(now)
	last_sample = now
	if now - last_trigger < COOLDOWN_MSEC:
		samples.clear() # Never queue a shake that occurred during cooldown.
		return false
	while not samples.is_empty() and now - samples[0].time > WINDOW_MSEC:
		samples.pop_front()
	samples.append({"time":now,"gyro":gyro,"linear":linear.length()})
	var low = Vector3.ZERO
	var high = Vector3.ZERO
	var pulse = 0.0
	for sample in samples:
		low = low.min(sample.gyro)
		high = high.max(sample.gyro)
		pulse = maxf(pulse, sample.linear)
	for axis in range(3):
		if low[axis] <= -ROTATION_SPEED and high[axis] >= ROTATION_SPEED and pulse >= LINEAR_PULSE:
			last_trigger = now
			samples.clear()
			return true
	return false
