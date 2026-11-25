extends GdUnitTestSuite

## T-008 coverage for ImpactShakeDriver: how a wall-hit speed becomes the
## noise emitter's amplitude, hold time and decay time.

const FULL_SPEED: float = 24.0


## A real noise emitter with a driver child, added to the test tree.
func _driver() -> ImpactShakeDriver:
	var emitter: PhantomCameraNoiseEmitter3D = auto_free(PhantomCameraNoiseEmitter3D.new())
	emitter.noise = PhantomCameraNoise3D.new()
	var driver := ImpactShakeDriver.new()
	emitter.add_child(driver)
	add_child(emitter)
	return driver


func _emitter(driver: ImpactShakeDriver) -> PhantomCameraNoiseEmitter3D:
	return driver.get_parent() as PhantomCameraNoiseEmitter3D


func test_hits_at_or_below_min_speed_do_not_shake() -> void:
	var driver := _driver()

	assert_bool(driver.shake_for_impact(2.0, FULL_SPEED)).is_false()
	assert_bool(driver.shake_for_impact(driver.min_shake_speed, FULL_SPEED)).is_false()
	assert_bool(_emitter(driver).is_emitting()).is_false()


func test_full_speed_hit_uses_the_max_values() -> void:
	var driver := _driver()
	var emitter := _emitter(driver)

	assert_bool(driver.shake_for_impact(FULL_SPEED, FULL_SPEED)).is_true()

	assert_bool(emitter.is_emitting()).is_true()
	assert_float(emitter.noise.amplitude).is_equal_approx(driver.max_amplitude, 0.0001)
	assert_float(emitter.duration).is_equal_approx(driver.max_hold_time, 0.0001)
	assert_float(emitter.decay_time).is_equal_approx(driver.max_decay_time, 0.0001)


func test_values_scale_with_impact_speed() -> void:
	var driver := _driver()
	var emitter := _emitter(driver)
	# Halfway between min_shake_speed (3) and FULL_SPEED (24).
	var half_speed: float = (driver.min_shake_speed + FULL_SPEED) / 2.0

	assert_bool(driver.shake_for_impact(half_speed, FULL_SPEED)).is_true()

	assert_float(emitter.noise.amplitude).is_equal_approx(driver.max_amplitude / 2.0, 0.0001)
	assert_float(emitter.duration).is_equal_approx(
		(driver.min_hold_time + driver.max_hold_time) / 2.0,
		0.0001,
	)
	assert_float(emitter.decay_time).is_equal_approx(
		(driver.min_decay_time + driver.max_decay_time) / 2.0,
		0.0001,
	)


func test_faster_than_full_speed_is_clamped() -> void:
	var driver := _driver()

	assert_float(driver.shake_strength(40.0, FULL_SPEED)).is_equal(1.0)
	assert_float(driver.shake_strength(FULL_SPEED, FULL_SPEED)).is_equal(1.0)
	assert_float(driver.shake_strength(driver.min_shake_speed, FULL_SPEED)).is_equal(0.0)


func test_weaker_hit_does_not_cut_a_stronger_shake_short() -> void:
	var driver := _driver()
	var emitter := _emitter(driver)
	driver.shake_for_impact(FULL_SPEED, FULL_SPEED)

	assert_bool(driver.shake_for_impact(6.0, FULL_SPEED)).is_false()
	assert_float(emitter.noise.amplitude).is_equal_approx(driver.max_amplitude, 0.0001)


func test_driver_scales_its_own_copy_of_the_noise() -> void:
	var emitter: PhantomCameraNoiseEmitter3D = auto_free(PhantomCameraNoiseEmitter3D.new())
	var shared_noise := PhantomCameraNoise3D.new()
	shared_noise.amplitude = 10.0
	emitter.noise = shared_noise
	var driver := ImpactShakeDriver.new()
	emitter.add_child(driver)
	add_child(emitter)

	driver.shake_for_impact(6.0, FULL_SPEED)

	assert_object(emitter.noise).is_not_same(shared_noise)
	assert_float(shared_noise.amplitude).is_equal(10.0)
