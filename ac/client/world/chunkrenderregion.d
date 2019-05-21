module ac.client.world.chunkrenderregion;

import bindbc.opengl;
import std.conv;
import std.algorithm;
import std.math;
import std.stdio;
import std.format;
import std.typecons;
import core.bitop;

import ac.client.application;
import ac.client.block.renderer.standardblockrenderer;
import ac.client.game.gamerenderer;
import ac.client.gl.glbindingsvao;
import ac.client.gl.glprogramcontext;
import ac.client.gl.glstate;
import ac.client.resources;
import ac.client.world.chunkrenderbuffers;
import ac.common.block.block;
import ac.common.math.matrix;
import ac.common.math.vector;
import ac.common.util.log;
import ac.common.util.perfwatch;
import ac.common.world.blockcontext;
import ac.common.world.chunk;
import ac.common.world.world;

/// Chunk is not the smalles unit for rendering - chunks are further divided into render regions
final class ChunkRenderRegion {
	static assert(Chunk.width < 256 && Chunk.height <= 256, "Need to change ubyte to something else for some buffers");
	static assert(Chunk.height % height == 0);

public:
	enum width = Chunk.width;
	enum height = 64;
	enum volume = width * width * height;
	enum countPerChunk = Chunk.height / height;

public:
	alias Update = Chunk.Update;
	alias UpdateFlags = Chunk.UpdateFlags;
	enum updateFlagsMask = Update.staticRender;

public:
	this() {
		staticDrawBuffers_ = ChunkRenderBuffers(0);
	}

	void setup(int regionIndex, Chunk chunk) {
		chunk_ = chunk;
		zOffset_ = cast(ubyte)(regionIndex * height);
		updateFlags_ = 0;
	}

	void reset() {
		staticDrawBuffers_.clear();
		staticDrawEventId_++;
	}

public:
	pragma(inline) Chunk chunk() {
		return chunk_;
	}

	pragma(inline) WorldVec.T zStart() {
		return zOffset_;
	}

	pragma(inline) WorldVec.T zEnd() {
		return zOffset_ + height;
	}

	pragma(inline) ref ChunkRenderBuffers staticDrawBuffers() {
		return staticDrawBuffers_;
	}

public:
	void step(bool isPriority) {
		if (!updateFlags_)
			return;

		if (auto _ftgd = application.condFreeTimeGuard((updateFlags_ & Update.staticRender) && !gameRenderer.isGLJobQueueFull(isPriority), "staticRenderRegion")) {
			resources.blockRenderList_program.bind();
			auto res = resources.blockRenderListCalcResources.obtain();

			Vec2I offset = chunk_.world.resources.bindSurroundingBlockIDMaps(chunk_.pos) + Chunk.width;
			glUniform3i(0, offset.x, offset.y, zOffset_); // Maps offset

			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, chunk_.world.game.blockListBuffer);
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, res.recordBuffer);
			glBindBufferBase(GL_ATOMIC_COUNTER_BUFFER, 0, res.counterBuffer);

			glDispatchCompute(width / 8, width / 8, height / 8);
			glMemoryBarrier(GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT | GL_ATOMIC_COUNTER_BARRIER_BIT);

			gameRenderer.addGlJob("staticRenderRegion2", &onStaticDrawFinished, ++staticDrawEventId_, &onStaticDrawReleaseResources, res.index, isPriority);
			updateFlags_ ^= Update.staticRender;
		}
	}

	void update(Chunk.UpdateFlags flags) {
		debug assert((flags & updateFlagsMask) == flags);

		updateFlags_ |= flags;
	}

private:
	void onStaticDrawFinished(size_t eventId, size_t resourcesId) {
		// There was a new static draw request since the last time
		if (staticDrawEventId_ != eventId)
			return;

		auto res = resources.blockRenderListCalcResources.get(resourcesId);

		scope StandardBlockRenderer rr = new StandardBlockRenderer();
		scope MutableBlockContext ctx = new MutableBlockContext();

		GLuint cnt = *res.counterBufferData;
		*res.counterBufferData = 0;

		foreach (i; 0 .. cnt) {
			// Record data format: 4 uint: (x: 4b, y: 4b, z: 8b, faces: 8b) (aggregation [x: 4b, y: 4b] * 4) (aggregation [x: 4b, y: 4b] * 2)
			GLuint[4] record = res.recordBufferData[i];

			rr.offset = Vec3U8(record[0] & 0xf, (record[0] >> 4) & 0xf, (record[0] >> 8) & 0xff);
			rr.visibleFaces = cast(Block.FaceFlags)((record[0] >> 16) & 0xff);
			rr.faceAggregation = record[1] | (ulong(record[2]) << 32);

			ctx.setContext(chunk_, Chunk.blockIndex(rr.offset.x, rr.offset.y, rr.offset.z + zOffset_));

			// This could happen if the block id has changed since the computation request
			if (ctx.isAir)
				continue;

			ctx.block.b_staticRender(ctx, rr);
		}

		staticDrawBuffers_.upload(rr.buffersBuilder, true);

		version (debugWorldUpdates)
			writeLog("chunk updateStaticDraw ", updateStaticDrawCounter_, " ", chunk_.pos);

		if (gameRenderer.visualiseLoadedChunks) {
			import ac.client.gl.gldebugrenderer;
			import ac.client.game.gamerenderer;

			auto mat = gameRenderer.renderConfig.cameraViewMatrix;
			auto pos = chunk_.pos.to!Vec3F + Vec3F(0, 0, zOffset_) + gameRenderer.renderConfig.coordinatesOffset.to!Vec3F;
			glDebugRenderer.drawBox(mat, pos, pos + Vec3F(width, width, height));
			glDebugRenderer.drawLine(Vec4F(0, 0, 0, 1), mat * (pos + Vec3F(width / 2, width / 2, height / 2)));

		}
	}

	static void onStaticDrawReleaseResources(size_t resourcesId) {
		resources.blockRenderListCalcResources.release(resourcesId);
	}

private:
	Chunk chunk_;
	UpdateFlags updateFlags_;
	ubyte zOffset_;

private:
	size_t staticDrawEventId_;

private:
	ChunkRenderBuffers staticDrawBuffers_;

}
