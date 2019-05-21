float interpolationConst(float progress) {
	const float ppow2 = progress * progress;
	const float ppow4 = ppow2 * ppow2;

	return //
		6 * progress * ppow4 // 6 * t^5
		- 15 * ppow4 // - 15 * t^4
		+ 10 * ppow2 * progress; // + 10 * t^3
}

float interpolationConstGradient(float progress) {
	const float pm1 = progress - 1;
	// d/dt 6 * t^5 - 15 * t^4 + 10 * t^3 = 30 * (t-1)^2 * t^2
	return 30 * (pm1 * pm1) * (progress * progress);
}