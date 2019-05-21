uint hash(uint x) {
	x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = ((x >> 16) ^ x) * 0x45d9f3b;
  x = (x >> 16) ^ x;
  return x;
}

uint hash(uint seed, uvec2 v) {
	uint result = hash(seed ^ v.x);
	result = hash(result ^ v.y);
	return result;
}

uint hash(uint seed, uvec3 v) {
	uint result = hash(seed ^ v.x);
	result = hash(result ^ v.y);
	result = hash(result ^ v.z);
	return result;
}

uint hash(uint seed, ivec3 v) {
	uint result = hash(seed ^ uint(v.x));
	result = hash(result ^ uint(v.y));
	result = hash(result ^ uint(v.z));
	return result;
}

uint hash(uint seed, ivec2 v) {
	uint result = hash(seed ^ uint(v.x));
	result = hash(result ^ uint(v.y));
	return result;
}