module ac.client.world.chunkrenderer;

import bindbc.opengl;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import std.range;

import ac.client.application;
import ac.client.game.gamerenderer;
import ac.client.resources;
import ac.client.world.chunkrenderregion;
import ac.client.world.chunkresources;
import ac.client.world.worldresources;
import ac.common.block.block;
import ac.common.math.vector;
import ac.common.util.log;
import ac.common.util.perfwatch;
import ac.common.world.chunk;
import ac.common.world.world;

/// This class holds all resources used when rendering a chunk (one ChunkRenderer instance for each rendered chunk)
final class ChunkRenderer {

public:
	alias Update = Chunk.Update;
	alias UpdateFlags = Chunk.UpdateFlags;
	enum updateFlagsMask = Update.lightMap | ChunkRenderRegion.updateFlagsMask;

public:
	// Linked list of released renderers
	private static ChunkRenderer firstReleasedRenderer_;
	private ChunkRenderer nextReleasedRenderer_;

	static ChunkRenderer obtain(Chunk chunk) {
		//if (!firstReleasedRenderer_)
		return new ChunkRenderer(chunk);

		/*ChunkRenderer result = firstReleasedRenderer_;
		firstReleasedRenderer_ = result.nextReleasedRenderer_;
		result.setup(chunk);
		return result;*/
	}

	void release() {
		foreach (ChunkRenderRegion reg; renderRegions_)
			reg.reset();

		/*nextReleasedRenderer_ = firstReleasedRenderer_;
		firstReleasedRenderer_ = this;
		lightMapUpdateEventId_++;*/
	}

public:
	pragma(inline) bool isRenderReady() {
		return isLightMapReady_;
	}

public:
	void step(bool isPriority) {
		// Request keeping all the neighbour chunks loaded
		Chunk[Chunk.Neighbour.count8] neighbours;
		static foreach (n; Chunk.Neighbour.first .. Chunk.Neighbour.count8)
			neighbours[n] = chunk_.maybeLoadNeighbour(n);

		// Neighbour chunks are not loaded -> cannot do practically anything
		const bool neighbourChunksLoaded = neighbours[].all!(n => n !is null);
		if (!neighbourChunksLoaded)
			return;

		// Application has no free time for updates -> cannot do practically anything
		if (!application.hasFreeTime())
			return;

		foreach (ChunkRenderRegion reg; renderRegions_)
			reg.step(isPriority);

		if (!updateFlags_)
			return;

		if (auto _ftgd = application.condFreeTimeGuard((updateFlags_ & Update.lightMap) && !gameRenderer.isGLJobQueueFull(isPriority), "lightMapUpdate")) {
			auto res = resources.lightMapCalcResources.obtain();

			WorldResources worldResources = chunk_.world.resources;
			const WorldVec chunkPos = chunk_.pos;
			Vec2I offset;

			// Prepare the lighting (setup to initial emitters + vertically propagate daylight)
			{
				resources.lighting_preparationProgram.bind();

				offset = worldResources.bindSurroundingBlockIDMaps(chunkPos);
				glUniform2i(0, offset.x, offset.y); // Maps offset
				glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, chunk_.world.game.blockListBuffer);
				glBindImageTexture(4, res.texture, 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA8);

				glDispatchCompute(Chunk.width * 3 / 8, Chunk.width * 3 / 8, 1);
			}

			// Propagate the light
			{
				resources.lighting_propagationProgram.bind();
				glUniform2i(0, offset.x, offset.y); // Maps offset

				glUniform1ui(1, 0); // Offset
				glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
				glDispatchCompute(Chunk.width * 3 / 8, Chunk.width * 3 / 8, Chunk.height / 8);

				foreach (i; 0 .. 2) {
					glUniform1ui(1, 4); // Offset
					glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
					glDispatchCompute(Chunk.width * 3 / 8, Chunk.width * 3 / 8, Chunk.height / 8);

					glUniform1ui(1, 0); // Offset
					glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
					glDispatchCompute(Chunk.width * 3 / 8, Chunk.width * 3 / 8, Chunk.height / 8);
				}

				// Image bindings are kept from previous program
			}

			// Save the results to appropriate maps
			{
				auto rr = worldResources.visibleAreaFor(chunk_);

				// Copy the results to the area light map (and appropriately retype (rgba8 -> r16ui))
				{
					resources.lighting_exportProgram.bind();
					glUniform3i(0, rr.offset.x, rr.offset.y, rr.offset.z);

					glBindImageTexture(0, rr.lightMap, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_R16UI);

					glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
					glDispatchCompute(Chunk.width / 4, Chunk.width / 4, Chunk.height / 4);
				}

				glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);
			}

			version (debugWorldUpdates)
				writeLog("chunk updateLightMap ", chunk_.pos);

			gameRenderer.addGlJob("lightMapUpdate2", &onLightMapUpdateFinished, ++lightMapUpdateEventId_, &onLightMapUpdateReleaseResources, res.index, isPriority);
			gameRenderer.visualiseChunk(chunk_.pos, 3);
			updateFlags_ ^= Update.lightMap;
		}
	}

	void update(Chunk.UpdateFlags flags) {
		debug assert((flags & updateFlagsMask) == flags);

		/*
			If the lighting update or redraw is requested and neighbour chunks are not loaded
			or any of this or neighbour chunks does not block id map properties texture updated,
			we don't store the lighting update request.

			The update request will be emitted when the lighting properties texture is updated in any of the chunks again.
		*/
		if (flags & (Update.lightMap | Update.staticRender) && (!chunk_.resources.isGPUBlockIDMapUpdated || chunk_.maybeNeighbours8.any!(x => !x || !x.resources.isGPUBlockIDMapUpdated)))
			flags &= ~(Update.lightMap | Update.staticRender);

		const Chunk.UpdateFlags regionFlags = flags & ChunkRenderRegion.updateFlagsMask;
		if (regionFlags) {
			flags &= ~regionFlags;
			foreach (ChunkRenderRegion reg; renderRegions_)
				reg.update(regionFlags);
		}

		updateFlags_ |= flags;
	}

	ChunkRenderRegion regionFor(Chunk.BlockIndex ix) {
		return renderRegions_[Chunk.blockLocalZ(ix) / ChunkRenderRegion.height];
	}

	ChunkRenderRegion region(size_t ix) {
		return renderRegions_[ix];
	}

private:
	this(Chunk chunk) {
		static foreach (i; 0 .. ChunkRenderRegion.countPerChunk)
			renderRegions_[i] = scoped!ChunkRenderRegion();

		setup(chunk);
	}

	void setup(Chunk chunk) {
		chunk_ = chunk;
		isLightMapReady_ = false;
		updateFlags_ = 0;
		lastRequestVisibleTime = 0;

		foreach (int i, ChunkRenderRegion reg; renderRegions_)
			reg.setup(i, chunk);
	}

private:
	void onLightMapUpdateFinished(size_t eventId, size_t resourcesId) {
		if (eventId != lightMapUpdateEventId_)
			return;

		isLightMapReady_ = true;
	}

	static void onLightMapUpdateReleaseResources(size_t resourcesId) {
		resources.lightMapCalcResources.release(resourcesId);
	}

public:
	World.Time lastRequestVisibleTime;

private:
	typeof(scoped!ChunkRenderRegion())[ChunkRenderRegion.countPerChunk] renderRegions_;
	UpdateFlags updateFlags_;
	Chunk chunk_;

private:
	/// If the light map was already calculated (does not necessairly have to be actual, but you cannot render anything without at least outdated light map)
	bool isLightMapReady_;
	size_t lightMapUpdateEventId_;

}
