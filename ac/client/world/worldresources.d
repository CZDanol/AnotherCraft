module ac.client.world.worldresources;

import bindbc.opengl;
import std.exception;
import std.conv;

import ac.common.world.world;
import ac.common.world.chunk;
import ac.common.util.log;
import ac.common.math.vector;
import ac.client.game.gamerenderer;
import ac.client.gl.glresourcemanager;
import ac.client.resources;

/**
	WorldResources contains and handles resources (textures, ...) that are shared by multiple chunks
*/
final class WorldResources {

public:
	this(World world) {
		world_ = world;

		GLint val;
		glGetIntegerv(GL_MAX_3D_TEXTURE_SIZE, &val);
		enforce(val >= 256, "3D texture size limit is smaller than 256 (no me gusta)");

		nullVisibleArea_ = new VisibleArea();
	}

	void release() {
		foreach (visibleArea; visibleAreas_)
			visibleArea.release();

		VisibleArea area = firstReleasedVisibleArea_;
		while (area) {
			area.release();
			area = area.nextReleasedArea_;
		}
	}

public:
	void processChunkSetVisible(Chunk chunk) {
		requireVisibleAreaFor(chunk.pos).visibleChunks_++;
	}

	void processChunkReleaseVisible(Chunk chunk) {
		WorldVec pos = chunk.pos - (chunk.pos.to!WorldVecU % VisibleArea.areaSizeU).to!WorldVec;
		VisibleArea visibleArea = visibleAreas_[pos];
		assert(visibleArea);

		if (--visibleArea.visibleChunks_ == 0) {
			version (debugWorldResources)
				writeLog("Release visibleArea ", pos, "; active: ", visibleAreas_.length);

			visibleArea.nextReleasedArea_ = firstReleasedVisibleArea_;
			firstReleasedVisibleArea_ = visibleArea;
			visibleAreas_.remove(pos);
		}
	}

	/// If the area is not visible, returns nullArea
	VisibleArea maybeVisibleAreaFor(WorldVec pos) {
		return visibleAreas_.get(pos - (pos.to!WorldVecU % VisibleArea.areaSizeU).to!WorldVec, nullVisibleArea_);
	}

	auto visibleAreaFor(Chunk chunk) {
		WorldVec pos = chunk.pos;
		const WorldVec offset = (pos.to!WorldVecU % VisibleArea.areaSizeU).to!WorldVec;
		pos -= offset;

		debug assert(pos in visibleAreas_);

		static struct Result {
			VisibleArea visibleArea;
			WorldVec offset;
			alias visibleArea this;
		}

		return Result(visibleAreas_[pos], offset);
	}

	VisibleArea requireVisibleAreaFor(WorldVec pos) {
		pos -= (pos.to!WorldVecU % VisibleArea.areaSizeU).to!WorldVec;

		if (auto it = pos in visibleAreas_)
			return *it;

		VisibleArea visibleArea;
		if (firstReleasedVisibleArea_) {
			visibleArea = firstReleasedVisibleArea_;
			firstReleasedVisibleArea_ = visibleArea.nextReleasedArea_;

			version (debugWorldResources)
				writeLog("Setup (reuse) visibleArea ", pos, "; active: ", visibleAreas_.length);
		}
		else {
			visibleArea = new VisibleArea();

			version (debugWorldResources)
				writeLog("Setup (new) visibleArea ", pos, "; active: ", visibleAreas_.length);
		}

		// This is to prevent dark border on chunk edges
		ushort clearColor = 0b1111_0000_0000_0000;
		glClearTexImage(visibleArea.lightMap, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, &clearColor);

		visibleAreas_[pos] = visibleArea;
		visibleArea.setup(this, pos);

		return visibleArea;
	}

	VisibleArea nullVisibleArea() {
		return nullVisibleArea_;
	}

public:
	void processChunkLoad(Chunk chunk) {
		requireActiveAreaFor(chunk.pos).activeChunks_++;
	}

	void processChunkUnload(Chunk chunk) {
		WorldVec pos = chunk.pos - (chunk.pos.to!WorldVecU % ActiveArea.areaSizeU).to!WorldVec;
		ActiveArea activeArea = activeAreas_[pos];
		assert(activeArea);

		if (--activeArea.activeChunks_ == 0) {
			version (debugWorldResources)
				writeLog("Release activeArea ", pos, "; active: ", activeAreas_.length);

			activeArea.nextReleasedArea_ = firstReleasedActiveArea_;
			firstReleasedActiveArea_ = activeArea;
			activeAreas_.remove(pos);
		}
	}

	/// Assumes the area is ready
	auto activeAreaFor(WorldVec pos) {
		const WorldVec offset = (pos.to!WorldVecU % ActiveArea.areaSizeU).to!WorldVec;
		pos -= offset;

		debug assert(pos in activeAreas_);

		static struct Result {
			ActiveArea activeArea;
			WorldVec offset;
			alias activeArea this;
		}

		return Result(activeAreas_[pos], offset);
	}

	ActiveArea maybeActiveAreaFor(WorldVec pos) {
		return activeAreas_.get(pos - (pos.to!WorldVecU % ActiveArea.areaSizeU).to!WorldVec, cast(ActiveArea) null);
	}

	ActiveArea requireActiveAreaFor(WorldVec pos) {
		pos -= (pos.to!WorldVecU % ActiveArea.areaSizeU).to!WorldVec;

		if (auto it = pos in activeAreas_)
			return *it;

		ActiveArea activeArea;
		if (firstReleasedActiveArea_) {
			activeArea = firstReleasedActiveArea_;
			firstReleasedActiveArea_ = activeArea.nextReleasedArea_;

			version (debugWorldResources)
				writeLog("Setup (reuse) activeArea ", pos, "; active: ", activeAreas_.length);
		}
		else {
			activeArea = new ActiveArea();

			version (debugWorldResources)
				writeLog("Setup (new) activeArea ", pos, "; active: ", activeAreas_.length);
		}

		activeAreas_[pos] = activeArea;
		return activeArea;
	}

	/// Binds appropriate blockIDMaps to image units 0 - 4 so that 3x3 area about specified chunk is bound
	/// Returns offset from the first area to the first chunk
	Vec2I bindSurroundingBlockIDMaps(WorldVec chunkPos) {
		WorldVec pos = chunkPos - WorldVec(Chunk.width, Chunk.width, 0);
		auto baseArea = activeAreaFor(pos);

		glBindImageTexture(0, baseArea.blockIdMap, 0, GL_TRUE, 0, GL_READ_ONLY, GL_R16UI);

		// If the 3x3 chunk area intersects multiple WorldResources areas, we have to bind all of'em

		if (baseArea.offset.x + Chunk.width * 2 >= ActiveArea.areaWidth)
			glBindImageTexture(1, activeAreaFor(pos + WorldVec(ActiveArea.areaWidth, 0, 0)).blockIdMap, 0, GL_TRUE, 0, GL_READ_ONLY, GL_R16UI);

		if (baseArea.offset.y + Chunk.width * 2 >= ActiveArea.areaWidth)
			glBindImageTexture(2, activeAreaFor(pos + WorldVec(0, ActiveArea.areaWidth, 0)).blockIdMap, 0, GL_TRUE, 0, GL_READ_ONLY, GL_R16UI);

		if (baseArea.offset.x + Chunk.width * 2 >= ActiveArea.areaWidth && baseArea.offset.y + Chunk.width * 2 >= ActiveArea.areaWidth)
			glBindImageTexture(3, activeAreaFor(pos + WorldVec(ActiveArea.areaWidth, ActiveArea.areaWidth, 0)).blockIdMap, 0, GL_TRUE, 0, GL_READ_ONLY, GL_R16UI);

		return baseArea.offset.xy.to!Vec2I;
	}

public:
	static final class VisibleArea {

	public:
		enum WorldVec areaSize = WorldVec(areaWidth, areaWidth, areaHeight); ///< size of 3D texture maps (on height, they are always of chunk size)
		enum WorldVecU areaSizeU = areaSize.to!WorldVecU;

		enum areaWidth = 128;
		enum areaHeight = Chunk.height;
		enum areaVolume = areaWidth * areaWidth * areaHeight;
		enum areasArrayWidth = (GameRenderer.maxViewAreaWidthInBlocks + areaWidth - 1) / areaWidth;

	public:
		this() {
			lightMap = glResourceManager.create(GLResourceType.texture2DArray);

			glBindTexture(GL_TEXTURE_2D_ARRAY, lightMap);

			glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

			glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_BORDER);
			glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

			glTexStorage3D(GL_TEXTURE_2D_ARRAY, 1, GL_R16UI, areaWidth, areaWidth, areaHeight);

			GLfloat[4] color = [0, 0, 0, 0];
			glTexParameterfv(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_BORDER_COLOR, &color[0]);

			lightMapHandle = glGetTextureHandleARB(lightMap);
			glMakeTextureHandleResidentARB(lightMapHandle);

			calculatedVRAMUsage += areaWidth * areaWidth * areaHeight * 2;
		}

		void setup(WorldResources resources, WorldVec pos) {

		}

	public:
		GLuint lightMap;
		GLuint64 lightMapHandle;

	public:
		size_t visibleChunks() {
			return visibleChunks_;
		}

	private:
		size_t visibleChunks_; ///< How many chunks are visible in the visibleArea (when dropped to zero, the visibleArea is released)
		VisibleArea nextReleasedArea_;

	private:
		void release() {
			glResourceManager.release(GLResourceType.texture2DArray, lightMap);

			calculatedVRAMUsage -= areaWidth * areaWidth * areaHeight * 2;
		}

	}

	static final class ActiveArea {

	public:
		enum WorldVec areaSize = WorldVec(areaWidth, areaWidth, areaHeight); ///< size of 3D texture maps (on height, they are always of chunk size)
		enum WorldVecU areaSizeU = areaSize.to!WorldVecU;

		enum areaWidth = 32;
		enum areaHeight = Chunk.height;
		enum areaVolume = areaWidth * areaWidth * areaHeight;

	public:
		this() {
			blockIdMap = glResourceManager.create(GLResourceType.texture3D);
			glBindTexture(GL_TEXTURE_3D, blockIdMap);

			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAX_LEVEL, 0);

			glTexStorage3D(GL_TEXTURE_3D, 1, GL_R16UI, areaWidth, areaWidth, areaHeight);

			calculatedVRAMUsage += areaWidth * areaWidth * areaHeight * 2;
		}

	public:
		GLuint blockIdMap;

	public:
		size_t activeChunks() {
			return activeChunks_;
		}

	private:
		size_t activeChunks_; ///< How many chunks are active in the visibleArea (when dropped to zero, the visibleArea is released)
		ActiveArea nextReleasedArea_;

	private:
		void release() {
			glResourceManager.release(GLResourceType.texture3D, blockIdMap);

			calculatedVRAMUsage -= areaWidth * areaWidth * areaHeight * 2;
		}

	}

private:
	World world_;

private:
	VisibleArea[WorldVec] visibleAreas_;
	VisibleArea nullVisibleArea_, firstReleasedVisibleArea_;

private:
	ActiveArea[WorldVec] activeAreas_;
	ActiveArea firstReleasedActiveArea_;

}
