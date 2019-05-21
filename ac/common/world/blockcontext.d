module ac.common.world.blockcontext;

import ac.common.block.block;
import ac.common.block.blockdata;
import ac.common.game.game;
import ac.common.world.chunk;
import ac.common.world.world;
import ac.content.content;

class BlockContext {

public:
	this() {

	}

	this(World world, WorldVec pos) {
		setContext_(world, pos);
	}

	this(Chunk chunk, Chunk.BlockIndex blockIndex) {
		setContext_(chunk, blockIndex);
	}

	this(BlockContext other) {
		state_ = other.state_;
	}

public pragma(inline):
	pragma(inline) final WorldVec pos() {
		return state_.pos_;
	}

	pragma(inline) final Game game() {
		return state_.chunk_.world.game;
	}

	pragma(inline) final World world() {
		return state_.chunk_.world;
	}

	pragma(inline) final Chunk chunk() {
		return state_.chunk_;
	}

	pragma(inline) final Block block() {
		return state_.block_;
	}

	pragma(inline) final Block.ID blockId() {
		return state_.chunk_.blockId(state_.blockIndex_);
	}

	pragma(inline) final Chunk.BlockIndex blockIndex() {
		return state_.blockIndex_;
	}

	pragma(inline) final ref Block.SmallData smallData() {
		return state_.chunk_.blockSmallData(state_.blockIndex_);
	}

	pragma(inline) final BlockData data() {
		return state_.chunk_.blockData(state_.blockIndex_);
	}

public:
	pragma(inline) final bool isAir() {
		return state_.block_ is null;
	}

	pragma(inline) final bool isValid() {
		return state_.chunk_ !is null;
	}

public:
	/// Updates the data about the block (if the block type was changed)
	void refresh() {
		state_.block_ = game.block(state_.chunk_.blockId(state_.blockIndex_));
	}

public:
	static struct State {

	private:
		Chunk chunk_;
		WorldVec pos_;
		Chunk.BlockIndex blockIndex_;
		Block block_;
		bool iterationEnded_ = true;

	}

protected:
	final void setContext_(World world, WorldVec pos) {
		state_.pos_ = pos;
		state_.chunk_ = world.chunkAt(Chunk.chunkPos(pos));
		state_.blockIndex_ = Chunk.blockIndex(pos);
		state_.block_ = /*chunk_ ? */ game.block(state_.chunk_.blockId(state_.blockIndex_)); // : null;
	}

	final void setContext_(Chunk chunk, Chunk.BlockIndex blockIndex) {
		state_.chunk_ = chunk;
		state_.pos_ = chunk.blockWorldPos(blockIndex);
		state_.blockIndex_ = blockIndex;
		state_.block_ = game.block(state_.chunk_.blockId(state_.blockIndex_));
	}

	final bool maybeSetContext_(World world, WorldVec pos) {
		state_.pos_ = pos;
		state_.chunk_ = world.maybeChunkAt(Chunk.chunkPos(pos));
		state_.blockIndex_ = Chunk.blockIndex(pos);
		state_.block_ = state_.chunk_ ? game.block(state_.chunk_.blockId(state_.blockIndex_)) : null;

		return state_.chunk_ !is null;
	}

private:
	State state_;

}

final class MutableBlockContext : BlockContext {

public:
	this() {

	}

	this(World world, WorldVec pos) {
		setContext_(world, pos);
	}

	this(Chunk chunk, Chunk.BlockIndex blockIndex) {
		setContext_(chunk, blockIndex);
	}

	/// Constructs the context and calls beginChunkIteration(chunk)
	this(Chunk chunk) {
		beginChunkIteration(chunk);
	}

	this(BlockContext other) {
		state_ = other.state_;
	}

public:
	pragma(inline) void setContext(World world, WorldVec pos) {
		setContext_(world, pos);
	}

	pragma(inline) void setContext(Chunk chunk, Chunk.BlockIndex blockIndex) {
		setContext_(chunk, blockIndex);
	}

	pragma(inline) bool maybeSetContext(World world, WorldVec pos) {
		return maybeSetContext_(world, pos);
	}

public:
	void beginChunkIteration(Chunk chunk, Chunk.BlockIndex iterationStart = 0) {
		state_.blockIndex_ = cast(Chunk.BlockIndex)(iterationStart - 1);
		state_.chunk_ = chunk;
		state_.iterationEnded_ = false;
	}

	/// Returns false if iteration ended. Make sure you've called beginChunkIteration before
	bool nextBlockInChunk(Chunk.BlockIndex iterationEnd = cast(Chunk.BlockIndex) Chunk.volume) {
		if (state_.iterationEnded_)
			return false;

		state_.blockIndex_++;
		state_.iterationEnded_ = state_.blockIndex_ == iterationEnd - 1;
		state_.pos_ = state_.chunk_.blockWorldPos(state_.blockIndex_);
		state_.block_ = game.block(state_.chunk_.blockId(state_.blockIndex_));
		return true;
	}

	/// Returns false if iteration ended. Make sure you've called beginChunkIteration before
	/// This should be faster than iterating over all blocks and checking if it is air manually after
	bool nextNonAirBlockInChunk(Chunk.BlockIndex iterationEnd = cast(Chunk.BlockIndex) Chunk.volume) {
		iterationEnd--;

		do {
			if (state_.iterationEnded_)
				return false;

			state_.blockIndex_++;
			state_.iterationEnded_ = (state_.blockIndex_ == iterationEnd);
			Block.ID blockId = state_.chunk_.blockId(state_.blockIndex_);
		}
		while (blockId == 0);

		state_.pos_ = state_.chunk_.blockWorldPos(state_.blockIndex_);
		state_.block_ = game.block(blockId);
		return true;
	}

public:
	State saveState() {
		return state_;
	}

	void restoreState(ref State state) {
		state_ = state;
	}

}
