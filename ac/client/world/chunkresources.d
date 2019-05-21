module ac.client.world.chunkresources;

import bindbc.opengl;
import std.array;
import std.algorithm;
import std.range;

import ac.client.application;
import ac.client.game.gamerenderer;
import ac.client.gl.gltexture;
import ac.client.resources;
import ac.common.block.block;
import ac.common.util.log;
import ac.common.util.perfwatch;
import ac.common.world.blockcontext;
import ac.common.world.chunk;

/**
	ChunkResources stores GPU-related resources for chunks.
	Those resources are required always, not only when the chunk is visible (for visible chunk resources, there's the GameRenderer class).

	This is for example light properties map, which can be required by neighbour chunks even when this chunk is not visible
*/
struct ChunkResources {

public:
	alias Update = Chunk.Update;
	alias UpdateFlags = Chunk.UpdateFlags;
	enum updateFlagsMask = Update.gpuBlockIDMap;

public:
	this(Chunk chunk) {
		chunk_ = chunk;
	}

	void setup() {
		updateGPUBlockIDMapCounter_ = 0;
	}

public:
	pragma(inline) bool isGPUBlockIDMapUpdated() {
		return isGPUBlockIDMapUpdated_;
	}

public:
	/// Returns updates that have been performed (might have not been all because of no time to perform them)
	UpdateFlags performUpdate(UpdateFlags flags) {
		debug assert((flags & updateFlagsMask) == flags);

		UpdateFlags result = 0;

		isGPUBlockIDMapUpdated_ &= !(flags & Update.gpuBlockIDMap);

		if (auto _ftgd = application.condFreeTimeGuard(flags & Update.gpuBlockIDMap, "gpuBlockIDMapUpdate")) {
			static assert(Block.LightValue.sizeof == 1);
			import core.stdc.string : memset;

			auto area = chunk_.world.resources.activeAreaFor(chunk_.pos);

			glTextureSubImage3D(area.blockIdMap, 0, area.offset.x, area.offset.y, area.offset.z, Chunk.width, Chunk.width, Chunk.height, GL_RED_INTEGER, GL_UNSIGNED_SHORT, chunk_.blockIdArray);

			result |= Update.gpuBlockIDMap;
			isGPUBlockIDMapUpdated_ = true;

			chunk_.globalUpdate(Update.lightMap | Update.staticRender);
			chunk_.activeNeighbours8.each!(ch => ch.globalUpdate(Update.lightMap | Update.staticRender));

			gameRenderer.visualiseChunk(chunk_.pos, 2);

			version (debugWorldUpdates)
				writeLog("chunk updateGPUBlockIDMap ", ++updateGPUBlockIDMapCounter_, " ", chunk_.pos);
		}

		return result;
	}

private:
	Chunk chunk_;
	bool isGPUBlockIDMapUpdated_;
	size_t updateGPUBlockIDMapCounter_;

}
