vec3 skyWithoutSun(vec2 posF, vec3 viewNormal, bool darker) {
	const float horizonCoef = pow(clamp((viewNormal.z + 0.2) * 5, 0, 1), 2);

	const float distFromSun = distance(daylightDirection, viewNormal);
	const vec3 horizonColor =	horizonHaloColor * (1 - abs(viewNormal.z + 0.2));

	const vec3 sunHorizonHalo = sunHorizonHaloColor * max(0, 1 - distFromSun * 0.5); // Sun-horizon halo

	return skyColor * (0.6 + (darker ? 0 : 0.4 * horizonCoef)) + (darker ? vec3(0) : sunHorizonHalo) + horizonColor;
}

#ifdef SKY_WITH_SUN
vec3 sky(vec2 posF, vec3 viewNormal) {
	const float horizonCoef = pow(clamp((viewNormal.z + 0.2) * 5, 0, 1), 2);

	const float distFromSun = distance(daylightDirection, viewNormal);
	const float distFromSunPx = sunPosPx.z > 0 ? distance(sunPosPx.xy, posF) : 10000;

	const vec3 sunOutColor =
		//+ sunColor * clamp((sunSize - distFromSunPx) / sunSize * 0.1 * sunHaloSizeInv, 0, 1) // Sun color, limited by the horizon
		#if GOD_RAYS
		+ sunColor * pow(min(1, sunSize / distFromSunPx), sunHaloPow) * 0.6 // Sun color, limited by the horizon
		#else
		+ sunColor * pow(min(1, sunSize / distFromSunPx), sunHaloPow) // Sun color, limited by the horizon
		#endif
		;

	return skyWithoutSun(posF, viewNormal, false) + sunOutColor * horizonCoef;
}
#endif