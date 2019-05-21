module ac.common.world.chunk;

import core.bitop;
import core.memory;
import core.stdc.stdlib;
import d2sqlite3.results;
import std.algorithm;
import std.array;
import std.container.array;
import std.conv;
import std.format;
import std.stdio;
import std.traits;
import std.zlib;

import ac.common.world.world;
import ac.common.block.block;
import ac.common.block.blockdata;
import ac.common.world.blockcontext;
import ac.common.math.vector;
import ac.common.util.perfwatch;
import ac.common.util.log;

version (client) {
	import ac.client.world.chunkrenderer;
	import ac.client.world.chunkresources;
	import ac.client.world.chunkrenderregion;
}

final class Chunk {

public:
	enum width = 16;
	enum height = 256;

	enum surface = width * width;
	enum volume = width * width * height;

	/// How many seconds (in world time) the chunk stays active after last requestActive call
	enum World.Time activeTimeout = 5;

	/// How many seconds (in world time) the chunk stays active after last requestVisible call
	enum World.Time visibleTimeout = 1;

	static immutable size = WorldVec(width, width, height);
	static immutable sizeU = size.to!WorldVecU;
	alias BlockIndex = ushort;

public:
	alias UpdateFlags = uint;
	enum Update : UpdateFlags {
		staticRender = 1 << 0,

		/// A map of block IDs is stored also in the GPU
		gpuBlockIDMap = 1 << 1,

		/// !!! Quite definitely you want to update gpuBlockIDMap, not lightMap
		/// lightMap is automatically scheduled for updating after gpuBlockIDMap
		lightMap = 1 << 2,

		/// When block is changed, you might need to update static draw for neighbouring blocks
		neighbourStaticRender = 1 << 3,
	}

	enum updateFlagsMask = 0; ///< Update events that are handled by the chunk, not by the renderer

	enum UpdateEvent : UpdateFlags {
		enterWorld = Update.gpuBlockIDMap,
		setVisible = Update.staticRender | Update.lightMap,
		blockChange = Update.staticRender | Update.gpuBlockIDMap | Update.neighbourStaticRender,
	}

	version (client) enum RenderPass : ubyte {
		staticDraw = 1 << 0,
	}

	version (client) enum RenderPasses : ubyte {
		none = 0,
		all = RenderPass.staticDraw
	}

public:
	// Linked list for released chunks
	private static Chunk firstReleasedChunk_;
	private Chunk nextReleasedChunk_;

	static Chunk obtain(World world, WorldVec pos) {
		if (!firstReleasedChunk_)
			return new Chunk(world, pos);

		Chunk result = firstReleasedChunk_;
		firstReleasedChunk_ = result.nextReleasedChunk_;
		result.setup(world, pos);
		return result;
	}

	void release() {
		nextReleasedChunk_ = firstReleasedChunk_;
		firstReleasedChunk_ = this;
	}

	~this() {
		pureFree(blockIds_);
		pureFree(blockSmallData_);
	}

	void loadFromDB(Row row) {
		ubyte[] blocksData = cast(ubyte[])(row["blocks"].as!(void[]).uncompress);
		assert(blocksData.length == Chunk.volume * (Block.ID.sizeof + Block.SmallData.sizeof));

		enum blockIDsEnd = Block.ID.sizeof * volume;
		enum blockSmallDataEnd = blockIDsEnd + Block.SmallData.sizeof * volume;

		blockIds_[0 .. volume] = cast(Block.ID[]) blocksData[0 .. blockIDsEnd];
		blockSmallData_[0 .. volume] = cast(Block.SmallData[]) blocksData[blockIDsEnd .. blockSmallDataEnd];
	}

	void saveToDB() {
		void[] blocks = ((cast(void[]) blockIds_[0 .. volume]) ~ (cast(void[]) blockSmallData_[0 .. volume])).compress;

		world.game.db.execute( //
				"INSERT OR REPLACE INTO chunks (world, x, y, blocks) VALUES (?, ?, ?, ?)", //
				world.worldId, pos_.x, pos_.y, blocks);
	}

	private this(World world, WorldVec pos) {
		blockIds_ = cast(Block.ID*) malloc(Block.ID.sizeof * volume);
		blockSmallData_ = cast(Block.SmallData*) pureMalloc(Block.SmallData.sizeof * volume);

		version (client)
			resources_ = ChunkResources(this);

		setup(world, pos);
	}

	private void setup(World world, WorldVec pos) {
		debug assert(world);
		debug assert(pos == chunkPos(pos), "Chunk position not aligned to the grid (%s)".format(pos));

		world_ = world;
		pos_ = pos;

		version (client)
			resources_.setup();
	}

public:
	pragma(inline) World world() {
		return world_;
	}

	/// Position of a corner block of the chunk
	pragma(inline) WorldVec pos() {
		return pos_;
	}

	version (client) pragma(inline) ref ChunkResources resources() {
		return resources_;
	}

public:
	enum Neighbour {
		first,

		left = first,
		right,

		front,
		back,

		count4,

		leftFront = count4,
		rightBack,

		leftBack,
		rightFront,

		count8,
		count = count8
	}

	static immutable WorldVec[Neighbour.count] neighbourOffset = [ //
	WorldVec(-width, 0, 0), // left
		WorldVec(width, 0, 0), // right

		WorldVec(0, -width, 0), // front
		WorldVec(0, width, 0), // back

		WorldVec(-width, -width, 0), // leftFront
		WorldVec(width, width, 0), // rightBack

		WorldVec(-width, width, 0), // leftBack
		WorldVec(width, -width, 0), // rightFront
		];

	static pragma(inline) Neighbour oppositeNeighbour(Neighbour n) {
		return cast(Neighbour)(n ^ 1);
	}

	/// Returns a chunk right adjacent to the current chunk (loads it if necessary, always returns a chunk)
	pragma(inline) Chunk neighbour(Neighbour n) {
		if (auto ch = neighbours_[n])
			return ch;

		return world.chunkAt(pos + neighbourOffset[n]);
	}

	pragma(inline) Chunk maybeNeighbour(Neighbour n) {
		return neighbours_[n];
	}

	pragma(inline) Chunk maybeLoadNeighbour(Neighbour n) {
		if (auto ch = neighbours_[n]) {
			ch.requestActive();
			return ch;
		}

		Chunk chk = world.maybeLoadChunkAt(pos + neighbourOffset[n]);
		assert(!chk);
		return null;
	}

	/// Returns range of neighbour 8 chunks (null if chunks are not loaded)
	pragma(inline) auto maybeNeighbours8() {
		return neighbours_[];
	}

	/// Returns range of active neighbour 8 chunks (excludes chunk that are not loaded)
	pragma(inline) auto activeNeighbours8() {
		return neighbours_[].filter!"a !is null";
	}

	/// Returns range of active neighbour 4 chunks (excludes chunk that are not loaded)
	pragma(inline) auto activeNeighbours4() {
		return neighbours_[0 .. Neighbour.count4].filter!"a !is null";
	}

public:
	void globalUpdate(UpdateFlags flags) {
		version (client)
			if (flags & Update.neighbourStaticRender) {
				activeNeighbours4.each!(ch => ch.globalUpdate(Update.staticRender));
				flags ^= Update.neighbourStaticRender;
			}

		updateFlags_ |= flags;
	}

	/// Some updates (for example static draw) need not to be performed for the entire chunk, but only locally. So it is better to call this function.-
	void localUpdate(UpdateFlags flags, BlockContext ctx) {
		debug assert(ctx.chunk is this);

		version (client) {
			if (isVisible && flags & ChunkRenderRegion.updateFlagsMask) {
				renderer.regionFor(ctx.blockIndex).update(flags & ChunkRenderRegion.updateFlagsMask);
				flags &= ~ChunkRenderRegion.updateFlagsMask;
			}

			if (flags & Update.neighbourStaticRender) {
				flags ^= Update.neighbourStaticRender;
				const WorldVec localPos = blockLocalPos(ctx.blockIndex);

				if (localPos.x == 0 && maybeNeighbour(Neighbour.left)) {
					scope BlockContext ctx2 = new BlockContext(maybeLoadNeighbour(Neighbour.left), blockIndex(Chunk.width - 1, localPos.y, localPos.z));
					ctx2.chunk.localUpdate(Update.staticRender, ctx2);
				}

				if (localPos.x == Chunk.width - 1 && maybeNeighbour(Neighbour.right)) {
					scope BlockContext ctx2 = new BlockContext(maybeLoadNeighbour(Neighbour.right), blockIndex(0, localPos.y, localPos.z));
					ctx2.chunk.localUpdate(Update.staticRender, ctx2);
				}

				if (localPos.y == 0 && maybeNeighbour(Neighbour.front)) {
					scope BlockContext ctx2 = new BlockContext(maybeLoadNeighbour(Neighbour.front), blockIndex(localPos.x, Chunk.width - 1, localPos.z));
					ctx2.chunk.localUpdate(Update.staticRender, ctx2);
				}

				if (localPos.y == Chunk.width - 1 && maybeNeighbour(Neighbour.back)) {
					scope BlockContext ctx2 = new BlockContext(maybeLoadNeighbour(Neighbour.back), blockIndex(localPos.x, 0, localPos.z));
					ctx2.chunk.localUpdate(Update.staticRender, ctx2);
				}

				if (isVisible && localPos.z % ChunkRenderRegion.height == 0)
					renderer.regionFor(blockIndexFromZ(localPos.z - 1)).update(Update.staticRender);

				if (isVisible && localPos.z % ChunkRenderRegion.height == ChunkRenderRegion.height - 1)
					renderer.regionFor(blockIndexFromZ(localPos.z + 1)).update(Update.staticRender);
			}
		}

		globalUpdate(flags);
	}

	void step(bool isPriority) {
		if (world.time - lastRequestActiveTime_ > activeTimeout) {
			world.unloadChunk(this);
			return;
		}

		if (updateFlags_ & updateFlagsMask)
			performUpdates(updateFlagsMask);

		version (client) {
			static assert((updateFlagsMask & ChunkResources.updateFlagsMask) == 0);
			static assert((updateFlagsMask & ChunkRenderer.updateFlagsMask) == 0);
			static assert((ChunkRenderer.updateFlagsMask & ChunkResources.updateFlagsMask) == 0);

			if (updateFlags_ & ChunkResources.updateFlagsMask)
				updateFlags_ &= ~resources.performUpdate(updateFlags_ & ChunkResources.updateFlagsMask);

			if (isVisible) {
				if (updateFlags_ & ChunkRenderer.updateFlagsMask) {
					renderer.update(updateFlags_ & ChunkRenderer.updateFlagsMask);
					updateFlags_ &= ~ChunkRenderer.updateFlagsMask;
				}

				renderer.step(isPriority);

				if (world.time - renderer.lastRequestVisibleTime > visibleTimeout)
					releaseVisible();
			}
		}
	}

	void performUpdates(UpdateFlags flags) {
		flags &= updateFlags_;
	}

	/// Marks the chunk to be active. If the chunk is not requested active for a while, it is unloaded
	pragma(inline) void requestActive() {
		lastRequestActiveTime_ = world.time;
	}

	version (client) pragma(inline) void requestVisible() {
		if (!isVisible)
			setVisible();

		renderer.lastRequestVisibleTime = world.time;
		requestActive();
	}

	/// This function is called when the chunk starts being rendered
	version (client) void setVisible() {
		assert(!renderer);

		auto _pgd = perfGuard("setVisible");

		version (debugWorld)
			writeLog("chunk setVisible ", pos);

		renderer = ChunkRenderer.obtain(this);
		world.visibleChunks_.insert(this);
		world.resources.processChunkSetVisible(this);
		globalUpdate(UpdateEvent.setVisible);
		requestVisible();
	}

	version (client) void releaseVisible() {
		assert(renderer);

		auto _pgd = perfGuard("releaseVisible");

		version (debugWorld)
			writeLog("chunk releaseVisible ", pos);

		world.resources.processChunkReleaseVisible(this);
		renderer.release();
		renderer = null;
		world.visibleChunks_ -= this;
	}

	version (client) pragma(inline) bool isVisible() {
		return renderer !is null;
	}

public:
	static pragma(inline) BlockIndex blockIndex(uint x, uint y, uint z) {
		return cast(BlockIndex)(x + y * width + z * width * width);
	}

	static pragma(inline) BlockIndex blockIndex(WorldVec blockPos) {
		return blockIndex((cast(Unsigned!(WorldVec.T)) blockPos.x) % width, (cast(Unsigned!(WorldVec.T)) blockPos.y) % width, blockPos.z);
	}

	static pragma(inline) BlockIndex blockIndexFromZ(WorldVec.T z) {
		return cast(BlockIndex)(z * width * width);
	}

	/// Returns position of the block relative to the chunk origin
	static pragma(inline) WorldVec blockLocalPos(BlockIndex blockIndex) {
		return WorldVec(blockIndex % width, (blockIndex / width) % width, blockLocalZ(blockIndex));
	}

	static pragma(inline) WorldVec.T blockLocalZ(BlockIndex blockIndex) {
		return blockIndex / (width * width);
	}

	/// Returns position of the block in the world
	pragma(inline) WorldVec blockWorldPos(BlockIndex blockIndex) {
		return pos_ + blockLocalPos(blockIndex);
	}

	/// Returns position of the chunk based on block position
	static pragma(inline) WorldVec chunkPos(WorldVec blockPos) {
		return blockPos - (blockPos.to!WorldVecU % sizeU).to!WorldVec;
	}

	pragma(inline) ref Block.ID blockId(BlockIndex blockIndex) {
		return blockIds_[blockIndex];
	}

	pragma(inline) ref Block.SmallData blockSmallData(BlockIndex blockIndex) {
		return blockSmallData_[blockIndex];
	}

	pragma(inline) BlockData blockData(BlockIndex blockIndex) {
		return blockData_[blockSmallData_[blockIndex]];
	}

	/// DO NOT USE THIS FUNCTION! ONLY USED FROM WorldGenPlatform WHEN GENERATING
	pragma(inline) Block.ID* blockIdArray() {
		return blockIds_;
	}

public:
	/// Only used when the chunk is active
	version (client) ChunkRenderer renderer;

	/// Resources are held even when the chunk is not visible
	version (client) ChunkResources resources_;

private:
	World world_;
	WorldVec pos_;
	package Chunk[Neighbour.count] neighbours_;

private:
	UpdateFlags updateFlags_;
	World.Time lastRequestActiveTime_;

private:
	BlockData[] blockData_;
	/*Block.ID[volume] blockIds_;
	Block.SmallData[volume] blockSmallData_;*/
	Block.ID* blockIds_;
	Block.SmallData* blockSmallData_;

package:
	version (client) size_t activeChunksIndex_; ///< Position in the activeChunks array

}

pragma(inline) void iterateBlocks(alias func)(Chunk chunk) {
	scope BlockContext context = new BlockContext;

	foreach (Chunk.BlockIndex i; 0 .. Chunk.volume) {
		context.setContext(chunk, i);
		func(context);
	}
}
