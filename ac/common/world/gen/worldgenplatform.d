module ac.common.world.gen.worldgenplatform;

import ac.common.world.gen.worldgen;
import ac.common.world.gen.worldgencodebuilder;
import ac.common.world.world;
import ac.common.world.chunk;

/// World gen platform is a wrapper for world generation implementation
/// You can for example have GPU-accelerated world generation or running on CPU
/// Because of this wrapper, the usage is exactly the same
abstract class WorldGenPlatform {

public:
	void initialize(WorldGen worldGen) {
		assert(worldGen !is null && worldGen_ is null);

		worldGen_ = worldGen;
	}

	void release() {

	}

	abstract Chunk generateChunk(WorldVec pos);

public:
	pragma(inline) final WorldGen worldGen() {
		return worldGen_;
	}

public:
	/// There is one invocation for each (x,y) position in the chunk
	abstract WorldGenCodeBuilder add2DPass();

	/// There is one invocation for each voxel in the chunk (and around)
	abstract WorldGenCodeBuilder add3DPass();

	/// Iterative passes are executed after the main pass. Invocations are requested using the iterativeCall() function in the codebuilder.
	/// There are two variants of the iterativeCall2D and iterativeCall3D. The 2D requires an additional Z parameter.
	/*abstract WorldGenCodeBuilder addIterativePass();*/

	abstract void finish();

private:
	WorldGen worldGen_;

}
