module ac.common.world.gen.worldgen;

import ac.common.world.chunk;
import ac.common.world.world;
import ac.common.world.gen.worldgenplatform;

abstract class WorldGen {

public:
	final pragma(inline) World world() {
		return world_;
	}

	final void world(World set) {
		assert(world_ is null);
		world_ = set;
		seed_ = world_.seed;
	}

	final pragma(inline) WorldGenPlatform platform() {
		return platform_;
	}

	final void platform(WorldGenPlatform set) {
		assert(platform_ is null);
		platform_ = set;
	}

	final WorldGen setPlatform(WorldGenPlatform set) {
		platform = set;
		return this;
	}

	final pragma(inline) uint seed() {
		return seed_;
	}

public:
	void initialize() {
		assert(world_ !is null && platform_ !is null);
		platform_.initialize(this);
	}

	void release() {
		platform_.release();
	}

public:
	Chunk generateChunk(WorldVec pos) {
		return platform_.generateChunk(pos);
	}

private:
	uint seed_;
	World world_;
	WorldGenPlatform platform_;

}
