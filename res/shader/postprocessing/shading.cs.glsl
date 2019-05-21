vec4 decompressLightValues(uint data) {
	return vec4(data & 15, (data >> 4) & 15, (data >> 8) & 15, (data >> 12) & 15);
}

usampler2DArray getLightMap(ivec2 areaIndex) {
	const uint ix = areaIndex.y * AREAS_ARRAY_WIDTH + areaIndex.x;
	const uvec4 vec = lightMaps[ix / 2];
	return usampler2DArray((ix & 1) == 1 ? vec.zw : vec.xy);
}

vec3 shading(vec3 worldCoords, vec3 normal, float glow) {
	vec4 lightValue;

	// Shading
	{
		const vec3 samplePos = worldCoords + normal * 0.5 - 0.5;

		const ivec2 areaOriginOffset = ivec2(floor(samplePos.xy)) - mapsOrigin;
		const ivec2 areaIndex = areaOriginOffset / AREA_WIDTH;

		// Check if the read world coords are not outside the light mapped area
		if(areaOriginOffset.x < 0 || areaOriginOffset.y < 0 || areaIndex.x >= AREAS_ARRAY_WIDTH || areaIndex.y >= AREAS_ARRAY_WIDTH)
			return vec3(1,0,0);

		const ivec2 areaPos = mapsOrigin + areaIndex * AREA_WIDTH;
		const vec3 posInArea = samplePos - vec3(areaPos, 0);

		uvec4 texelLightValue[2];

		// Check if the sample needs to interpolate between multiple textures (because we're sampling on the edge of one light map)...
		if(posInArea.x <= AREA_WIDTH - 1 && posInArea.y <= AREA_WIDTH - 1) {
			const vec3 texCoords = vec3((floor(posInArea.xy) + 0.5) / AREA_WIDTH, floor(posInArea.z));
			const usampler2DArray lightMap = getLightMap(areaIndex);

			#pragma unroll
			for(uint j = 0; j < 2; j++) 
				texelLightValue[j] = textureGather(lightMap, texCoords + vec3(0, 0, float(j))).wzxy;

		}
		else {
			// If we are on the edge of the light map, we have to sample neighbours as well... bummer...
			const ivec3 posInAreaI = ivec3(floor(posInArea));

			#pragma unroll
			for(int j = 0; j < 4; j ++) {
				const ivec2 offsetVec = posInAreaI.xy + ivec2(j % 2, j / 2);
				const ivec2 pos = offsetVec % AREA_WIDTH;
				const usampler2DArray lightMap = getLightMap(areaIndex + offsetVec / AREA_WIDTH);

				texelLightValue[0][j] = texelFetch(lightMap, ivec3(pos, posInAreaI.z), 0).r;
				texelLightValue[1][j] = texelFetch(lightMap, ivec3(pos, posInAreaI.z + 1), 0).r;
			}
		}

		const float xCoef = fract(posInArea.x), xCoefInv = 1 - xCoef;
		const vec4 interpolation1 = decompressLightValues(texelLightValue[0][0]) * xCoefInv + decompressLightValues(texelLightValue[0][1]) * xCoef;
		const vec4 interpolation2 = decompressLightValues(texelLightValue[0][2]) * xCoefInv + decompressLightValues(texelLightValue[0][3]) * xCoef;
		const vec4 interpolation3 = decompressLightValues(texelLightValue[1][0]) * xCoefInv + decompressLightValues(texelLightValue[1][1]) * xCoef;
		const vec4 interpolation4 = decompressLightValues(texelLightValue[1][2]) * xCoefInv + decompressLightValues(texelLightValue[1][3]) * xCoef;

		const float yCoef = fract(posInArea.y), yCoefInv = 1 - yCoef;
		const vec4 interpolation5 = interpolation1 * yCoefInv + interpolation2 * yCoef;
		const vec4 interpolation6 = interpolation3 * yCoefInv + interpolation4 * yCoef;

		const float zCoef = fract(posInArea.z);
		lightValue = mix(interpolation5, interpolation6, zCoef) / 15;

		// Inverting daylight value so that black color (outside light areas, most notably above) is full daylight instead of black
		//lightValue.a = 1 - lightValue.a;
		
		lightValue = pow(lightValue, vec4(0.85));
	}

	const float daylightValue = lightValue.a;

	const vec3 baseDirectionalDaylightComponent = directionalDaylightColor * max(0, dot(normal, daylightDirection));

	#if SHADOW_MAPPING
		const vec4 shadowSampleScreenPosW = shadowSamplingMatrix * vec4(worldCoords + normal * 0.1, 1);
		const vec3 shadowSampleScreenPos = shadowSampleScreenPosW.xyz / shadowSampleScreenPosW.w;
		const vec2 shadowSampleFragPos = shadowSampleScreenPos.xy * textureSize(inShadowMap, 0) - 0.498; // Idk why it has to be 0.498 but 0.5 causes artifacts (empirically tested)

		const vec4 shadowData = textureGather(inShadowMap, shadowSampleScreenPos.xy, shadowSampleScreenPos.z);

		const vec2 shadowSampleFragPosFract = fract(shadowSampleFragPos);
		const vec2 smInterpolation1 = mix(vec2(shadowData[2],shadowData[3]), vec2(shadowData[1], shadowData[0]), shadowSampleFragPosFract.y);
		const float isOutsideShadow = mix(smInterpolation1.y, smInterpolation1.x, shadowSampleFragPosFract.x);
		
		//const float isOutsideShadow = (shadowData[0] + shadowData[1] + shadowData[2] + shadowData[3]) / 4;
		const float distanceFromPlayer = distance(worldCoords, cameraPos);

		const vec3 directionalDaylightComponent = baseDirectionalDaylightComponent * daylightValue * mix(isOutsideShadow, 1, min(1, distanceFromPlayer * 0.02));
		//const vec3 directionalDaylightComponent = vec3(shadowData.x, shadowSampleFragPosFract);
	#else
		const vec3 directionalDaylightComponent = baseDirectionalDaylightComponent * daylightValue;
	#endif

	const vec3 daylightComponent = ambientDaylightColor * daylightValue + directionalDaylightComponent;

	return (lightValue.rgb + glow) * (1 - (artificialLightEffectReduction * lightValue.a)) + ambientLightColor + daylightComponent;
}