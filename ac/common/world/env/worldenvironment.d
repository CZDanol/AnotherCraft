module ac.common.world.env.worldenvironment;

import std.algorithm;

import ac.common.world.world;
import ac.common.math.vector;

/**
	WorldEnvironment takes care of various world environment pararameters,
	such as light colors/directions
*/
abstract class WorldEnvironment {

public:
	pragma(inline) final World world() {
		return world_;
	}

	final void world(World set) {
		assert(world_ is null);
		world_ = set;
	}

	abstract void step();

public:
	static struct LightSettings {

	public:
		Vec3F daylightDirection;
		Vec3F directionalDaylightColor;
		Vec3F ambientDaylightColor;
		Vec3F ambientLightColor;

	public:
		Vec3F skyColor, sunColor, horizonHaloColor, sunHorizonHaloColor;
		float sunSize, sunHaloPow;

	public:
		float artificialLightEffectReduction;

	}

	final ref const(LightSettings) lightSettings() {
		return lightSettings_;
	}

protected:
	static Vec3F interpolateColors(float progress, Vec3F[] nodes, float[] nodePositions) {
		if (progress <= nodePositions[0])
			return nodes[0];

		if (progress >= nodePositions[$ - 1])
			return nodes[$ - 1];

		const size_t i = nodePositions.countUntil!"a >= b"(progress) - 1;
		const float p = interpolationConst((progress - nodePositions[i]) / (nodePositions[i + 1] - nodePositions[i]));

		// Gamma-corrected interpolation
		enum float gamma = 2.2;
		return (nodes[i].pow(gamma) * (1 - p) + nodes[i + 1].pow(gamma) * p).map!(x => x.clamp(0, 1)).pow(1 / gamma);
	}

	static auto interpolate(T)(float progress, T[] nodes, float[] nodePositions) {
		if (progress <= nodePositions[0])
			return nodes[0];

		if (progress >= nodePositions[$ - 1])
			return nodes[$ - 1];

		const size_t i = nodePositions.countUntil!"a >= b"(progress) - 1;
		const float p = interpolationConst((progress - nodePositions[i]) / (nodePositions[i + 1] - nodePositions[i]));

		return nodes[i] * (1 - p) + nodes[i + 1] * p;
	}

	static float interpolationConst(float val) {
		const float val2 = val * val;
		const float val4 = val2 * val2;

		return  //
		6 * val * val4 // 6 * t^5
		 - 15 * val4 // - 15 * t^4
		 + 10 * val2 * val; // + 10 * t^3
	}

protected:
	LightSettings lightSettings_;

private:
	World world_;

}
