module ac.common.world.worldloader;

import core.stdc.stdlib;
import core.sync.condition;
import core.sync.mutex;
import core.thread;
import std.algorithm;
import std.array;
import std.container.array;
import std.container.dlist;
import std.stdio;

import ac.common.world.world;
import ac.common.util.log;
import ac.common.world.gen.worldgen;
import ac.common.world.chunk;
import ac.common.util.set;
import ac.common.block.block;
import ac.common.world.blockcontext;
import ac.common.game.game;

/// WorldLoader handles asynchronous word loading/saving/generation in a separate thread
final class WorldLoader {

public:
	this(World world) {
		world_ = world;
		game_ = world.game;
		worldId_ = world.worldId;

		thread_ = new Thread(&run);
		syncMutex_ = new Mutex();
		priorityCondition_ = new Condition(syncMutex_);
		newRequestCondition_ = new Condition(syncMutex_);
	}

	~this() {
		release();
	}

public:
	void worldGen(WorldGen set) {
		assert(worldGen_ is null); // World gen is not set

		worldGen_ = set;
		thread_.start();
	}

	void release() {
		canRun_ = false;
		newRequestCondition_.notify();
		thread_.join();
	}

	/// Requires the chunk to be immediately loaded/generated; returns the chunk
	Chunk requireChunk(WorldVec pos) {
		assert(pos == Chunk.chunkPos(pos));

		synchronized (syncMutex_) {
			// If the chunk was already generated but not yet synced, return it
			if (auto it = pos in chunkLoadResultAA_) {
				Chunk chunk = *it;
				chunkLoadResultAA_.remove(pos);
				chunkLoadResultQueue_.linearRemoveElement(chunk);
				return chunk;
			}

			debug assert(!isPriorityChunkSet_);
			isPriorityChunkSet_ = true;
			priorityChunkPos_ = pos;
			chunkLoadQueue_.linearRemoveElement(pos);

			newRequestCondition_.notify();
			priorityCondition_.wait();

			return priorityChunkResult_;
		}
	}

	/// Issued the loading of the chunk (somewhen in the future)
	void issueChunkLoad(WorldVec pos) {
		assert(pos == Chunk.chunkPos(pos));

		version (debugWorld)
			writeLog("chunk issueLoad ", pos);

		synchronized (syncMutex_) {
			debug assert(pos !in chunkLoadResultAA_);

			chunkLoadQueue_ ~= pos;
			newRequestCondition_.notify();
		}
	}

	/// Unloads the chunk (stores it on the disk/somewhere)
	void unloadChunk(Chunk chunk) {
		synchronized (syncMutex_) {
			chunkUnloadQueue_ ~= chunk;
			newRequestCondition_.notify();
		}
	}

	/// Returns a newly loaded chunk if there is one ready (otherwise null)
	Chunk getLoadedChunk() {
		synchronized (syncMutex_) {
			if (chunkLoadResultQueue_.empty)
				return null;

			Chunk ch = chunkLoadResultQueue_.front;
			chunkLoadResultQueue_.removeFront();
			chunkLoadResultAA_.remove(ch.pos);
			return ch;
		}
	}

private:
	void run() {
		try {

			// Game is a thread-local variable, so we have to initialize it
			game = world_.game;
			worldGen_.initialize();

			enum Task {
				generateChunk,
				unloadChunks
			}

			WorldVec pos;
			Chunk chunk;
			Task task;
			auto localUnloadQueue = Array!Chunk();
			size_t localUnloadIx = 0;

			mainLoop: while (true) {
				synchronized (syncMutex_) {
					while (true) {
						localUnloadQueue ~= chunkUnloadQueue_;
						chunkUnloadQueue_.clear();

						if (isPriorityChunkSet_) {
							pos = priorityChunkPos_;
							task = Task.generateChunk;
							break;
						}

						else if (canRun_ && !chunkLoadQueue_.empty && (localUnloadQueue.length - localUnloadIx) < 128) {
							pos = chunkLoadQueue_.front;
							task = Task.generateChunk;
							chunkLoadQueue_.removeFront();
							break;
						}

						else if (!localUnloadQueue.empty) {
							task = Task.unloadChunks;
							break;
						}

						else if (!canRun_)
							break mainLoop;

						else
							newRequestCondition_.wait();
					}
				}

				if (task == Task.generateChunk) {
					auto result = game.db.execute("SELECT * FROM chunks WHERE world = ? AND x = ? AND y = ?", worldId_, pos.x, pos.y);
					if (result.empty) {
						import ac.common.util.perfwatch;

						perfBegin("generateChunk", "");
						chunk = worldGen_.generateChunk(pos);
						perfEnd();

						version (debugWorld)
							writeLog("chunk generate ", pos);
					}
					else {
						chunk = Chunk.obtain(world_, pos);
						chunk.loadFromDB(result.front);

						version (debugWorld)
							writeLog("chunk loadFromDB ", pos);
					}

					synchronized (syncMutex_) {
						// When the chunk is returned as priority, it is synced with the priority request -> do not put it into generated chunks
						if (isPriorityChunkSet_ && priorityChunkPos_ == pos) {
							isPriorityChunkSet_ = false;
							priorityChunkResult_ = chunk;
							priorityCondition_.notify();
						}
						else {
							chunkLoadResultQueue_ ~= chunk;
							chunkLoadResultAA_[pos] = chunk;
						}
					}
				}
				else if (task == Task.unloadChunks) {
					size_t i = 32;
					game_.db.begin();
					while (localUnloadIx < localUnloadQueue.length && --i > 0) {
						Chunk ch = localUnloadQueue[localUnloadIx++];

						version (debugWorld)
							writeLog("chunk saveToDB ", ch.pos);

						ch.saveToDB();
						ch.release();
					}
					game_.db.commit();

					if (localUnloadIx == localUnloadQueue.length) {
						localUnloadQueue.length = 0;
						localUnloadIx = 0;
					}
				}
				else
					assert(0);
			}

			worldGen_.release();
		}
		catch (Throwable t) {
			import std.file;

			auto f = File("exception.txt", "w");
			f.writeln(t.toString);

			stderr.writeln(t.toString);
			exit(5);
		}
	}

private:
	Game game_;
	World world_;
	WorldGen worldGen_;
	int worldId_;

private:
	DList!WorldVec chunkLoadQueue_;
	Array!Chunk chunkUnloadQueue_;

	Chunk[WorldVec] chunkLoadResultAA_;
	DList!Chunk chunkLoadResultQueue_;
private:
	WorldVec priorityChunkPos_; ///< Chunk that should be generated prioritely
	bool isPriorityChunkSet_;
	Chunk priorityChunkResult_;

private:
	Mutex syncMutex_;
	Condition priorityCondition_, newRequestCondition_;

private:
	Thread thread_;
	bool canRun_ = true;

}
