#define SSAO_MAX_SAMPLE_COUNT 8
#define SSAO_MIN_SAMPLE_COUNT 2

const vec3 ssaoSamples[8] = {
	// Generated using etc/ssaoSamples.d
vec3(0.05,-0,0.0691984),
vec3(-0.0264872,0.0815191,0.0867045),
vec3(-0.0982378,-0.0713739,0.156415),
vec3(0.127131,-0.0923662,0.181359),
vec3(0.0595961,0.183418,0.0700563),
vec3(-0.228571,-1.32602e-07,0.0661359),
vec3(0.081669,-0.251351,0.101557),
vec3(0.242705,0.176336,0.108717),
};

float ssao(float z, vec3 worldCoords, vec3 normal) {
	// Source: https://learnopengl.com/Advanced-Lighting/SSAO
	const uint randVal = hash(18132, uvec3(fract(worldCoords)*256));
	const vec3 randVec = vec3(randVal & 255, (randVal >> 8) & 255, (randVal >> 16) & 255);

	const vec3 tangent = normalize(randVec - normal * dot(randVec, normal));
	const vec3 bitangent = cross(normal, tangent);
	const mat4 sampleMat = viewMatrix * mat4(vec4(tangent, 0), vec4(bitangent, 0), vec4(normal, 0), vec4(worldCoords,1));

	const float sampleCountF = SSAO_MIN_SAMPLE_COUNT + max(0, 1 - z * 0.05) * (SSAO_MAX_SAMPLE_COUNT - SSAO_MIN_SAMPLE_COUNT);
	const uint sampleCount = uint(sampleCountF);

	if(sampleCount == 0)
		return 1;

	float occlusion = 0;
	for(uint i = 0; i < sampleCount; i++) {
		const vec4 sampleScreenPosW = sampleMat * vec4(ssaoSamples[i], 1);
		const vec3 sampleScreenPos = vec3(sampleScreenPosW.xyz / sampleScreenPosW.w);
		const float sampleZ = depthToZ(sampleScreenPos.z);

		const vec2 sampleUVPos = sampleScreenPos.xy * 0.5 + 0.5;

		const float sampledDepth = texture(inDepth, sampleUVPos).x * 2 - 1;
		const float sampledZ = depthToZ(sampledDepth);

		const float factor = 1 - clamp((sampleZ - sampledZ) * 5, 0, 1);

		occlusion += (sampledZ <= sampleZ) ? factor : 0;
	}

	return 1 - occlusion / SSAO_MAX_SAMPLE_COUNT;
}