module ac.common.world.world;

import std.algorithm;
import std.conv;
import std.container.array;
import std.stdio;
import std.format;
import std.array;
import std.math;
import std.random;
import std.json;

import ac.client.application;
import ac.common.block.block;
import ac.common.game.game;
import ac.common.math.matrix;
import ac.common.math.vector;
import ac.common.util.json;
import ac.common.util.log;
import ac.common.util.perfwatch;
import ac.common.util.set;
import ac.common.world.blockcontext;
import ac.common.world.chunk;
import ac.common.world.env.worldenvironment;
import ac.common.world.gen.worldgen;
import ac.common.world.worldloader;

version (client) {
	import ac.client.world.chunkresources;
	import ac.client.world.worldresources;
	import ac.client.game.gamerenderer;
	import ac.client.graphicsettings;
}

alias WorldVec = Vector!(int, 3, "worldVec");
alias WorldVecU = Vector!(uint, 3, "worldVec");

final class World {

public:
	alias Time = float;

	/// Maximum delta time between two world steps
	enum maxDeltaTime = 0.2f;

public:
	this(Game game, int worldId) {
		game_ = game;
		loader_ = new WorldLoader(this);
		worldId_ = worldId;

		bool isNewWorld = game.db.execute("SELECT COUNT(*) FROM worlds WHERE id = ?", worldId).oneValue!size_t == 0;
		if (isNewWorld) {
			seed_ = unpredictableSeed;

			saveDataToDB();
		}
		else
			loadDataFromDB();

		version (client)
			resources_ = new WorldResources(this);
	}

public:
	pragma(inline) Game game() {
		return game_;
	}

	/// Returns world time
	pragma(inline) Time time() {
		return time_;
	}

	pragma(inline) int worldId() {
		return worldId_;
	}

	pragma(inline) uint seed() {
		return seed_;
	}

	version (client) pragma(inline) WorldResources resources() {
		return resources_;
	}

	pragma(inline) WorldEnvironment environment() {
		return environment_;
	}

	void environment(WorldEnvironment set) {
		assert(set.world is null);
		set.world = this;
		environment_ = set;
	}

	pragma(inline) size_t activeChunkCount() {
		return activeChunks_.length;
	}

	void worldGen(WorldGen set) {
		assert(chunks_.length == 0); // No chunks are generated yet
		assert(set.platform !is null, "Before setting the worldgen to the world, set the worldgen platform");

		if (set.world is null)
			set.world = this;

		assert(set.world is this); // World gen's world is this

		loader_.worldGen = set;
	}

public:
	static pragma(inline) bool isValidBlockPosition(WorldVec pos) {
		return pos.z >= 0 && pos.z < Chunk.height;
	}
	/// Returns chunk around $position. The chunk is immediately loaded if needed (blocking).
	Chunk chunkAt(WorldVec pos) {
		/*if (pos.z != 0)
			return null;*/
		assert(pos.z == 0);

		if (auto it = pos in chunks_)
			return *it;

		auto _pgd = perfGuard("requireChunk");

		version (debugWorld)
			writeLog("chunk require ", pos);

		Chunk chunk = processChunkLoad(loader_.requireChunk(pos));
		chunks_[pos] = chunk;
		return chunk;
	}

	/// Returns chunk around $position. If the chunk is not active, returns null.
	pragma(inline) Chunk maybeChunkAt(WorldVec pos) {
		if (auto result = pos in chunks_)
			return *result;

		return null;
	}

	pragma(inline) Chunk maybeLoadChunkAt(WorldVec pos) {
		if (auto result = pos in chunks_) {
			result.requestActive();
			return *result;
		}

		if (pos.z != 0)
			return null;

		if (issuedChunks_.tryInsert(pos))
			loader_.issueChunkLoad(pos);

		return null;
	}

	void step(Time deltaTime) {
		debug assert(!unloaded_);

		environment_.step();

		float delta = min(deltaTime, maxDeltaTime);
		time_ += delta;
		dayTime = fmod(1 + dayTime + graphicSettings.advanceDaytimeSpeed * delta * 0.001, 1);

		{
			auto _pgd = perfGuard("sortChunks");

			activeChunks_.length = chunks_.length;
			alias VT = Vector!(WorldVec.T, 2);
			VT cameraPosI = cameraPos.xy.to!VT;

			// We try to keep the data mostly sorted, so the sorting is fast
			foreach (ref ach; activeChunks_)
				ach.distanceFromCamera = (ach.chunk.pos.xy.to!VT - cameraPosI).vecLengthSqr;

			activeChunks_[].sort!("a.distanceFromCamera < b.distanceFromCamera", SwapStrategy.stable)();

			foreach (i; 0 .. activeChunks_.length)
				activeChunks_[i].chunk.activeChunksIndex_ = i;
		}

		// Chunks near to the player have special priority
		// We have to check activeChunks_.length each step because it can change during the step as chunks are loaded/unloaded
		for (size_t i = 0; i < activeChunks_.length; i++)
			activeChunks_[i].chunk.step(i < 10);
	}

	void loadNewChunks() {
		// Add newly loaded chunks reported by the loader
		while (application.hasFreeTime) {
			Chunk chunk = loader_.getLoadedChunk();
			if (!chunk)
				break;

			debug assert(chunk.pos !in chunks_, "Chunk %s is already in the world".format(chunk.pos));
			chunks_[chunk.pos] = processChunkLoad(chunk);
		}
	}

	void unloadChunk(Chunk chunk) {
		debug assert(chunk.world is this);

		version (debugWorld)
			writeLog("chunk unload ", chunk.pos);

		version (client) {
			if (chunk.isVisible)
				chunk.releaseVisible();

			resources.processChunkUnload(chunk);

			const size_t ix = chunk.activeChunksIndex_;
			activeChunks_[ix] = activeChunks_[$ - 1];
			activeChunks_[ix].chunk.activeChunksIndex_ = ix;
			activeChunks_.removeBack();
		}

		foreach (Chunk.Neighbour n; cast(Chunk.Neighbour) 0 .. Chunk.Neighbour.count) {
			if (auto ch = chunk.neighbours_[n])
				ch.neighbours_[Chunk.oppositeNeighbour(n)] = null;
		}

		chunks_.remove(chunk.pos);
		loader_.unloadChunk(chunk);
	}

	/// Releases all resources, unloads & saves all chunks
	void unloadWorld() {
		debug assert(!unloaded_);

		version (debugWorld)
			writeLog("world unload");

		// Must be .array here, because we're manipulating with the array
		foreach (Chunk chunk; chunks_.byValue.array)
			unloadChunk(chunk);

		if (loader_)
			loader_.release();

		version (client)
			resources_.release();

		saveDataToDB();
		debug unloaded_ = true;
	}

public:
	/// Cast a ray from pos in direction dir, up to maxDistance block
	static struct RayCastResult {

	public:
		alias ObjectID = uint;

	public:
		bool isHit;
		WorldVec pos;
		ObjectID objectId; /// Single block can have multiple casting objects (for different interactions when pointing at different parts of the block)
		Block.Face face; /// Direction where a block should be build

	public:
		bool opCast(T : bool)() {
			return isHit;
		}

	}

	static struct RayCastAssistant {

	public:
		RayCastResult box(Vec3F start = Vec3F(0, 0, 0), Vec3F end = Vec3F(1, 1, 1), RayCastResult.ObjectID objectId = 0) const {
			float hitpointDistance = float.max;
			Block.Face hitpointFace;

			static foreach (i; 0 .. 3) {
				{
					enum i2 = (i + 1) % 3;
					enum i3 = (i + 2) % 3;

					{
						const float dist = (start[i] - rayPos_[i]) / rayDir_[i];
						const Vec3F hitPoint = rayPos_ + rayDir_ * dist;

						if (dist >= 0 && dist < hitpointDistance && hitPoint[i2] >= start[i2] && hitPoint[i3] >= start[i3] && hitPoint.all!"a <= b"(end)) {
							hitpointDistance = dist;
							hitpointFace = cast(Block.Face)(i * 2);
						}
					}

					{
						const float dist = (end[i] - rayPos_[i]) / rayDir_[i];
						const Vec3F hitPoint = rayPos_ + rayDir_ * dist;

						if (dist >= 0 && dist < hitpointDistance && hitPoint[i2] <= end[i2] && hitPoint[i3] <= end[i3] && hitPoint.all!"a >= b"(start)) {
							hitpointDistance = dist;
							hitpointFace = cast(Block.Face)(i * 2 + 1);
						}
					}
				}
			}

			return RayCastResult(hitpointDistance != float.max, pos_, objectId, hitpointFace);
		}

	private:
		WorldVec pos_;
		Vec3F rayPos_, rayDir_;

	}

	auto castRay(Vec3F pos, Vec3F dir, float maxDistance = 32) {
		dir = dir.normalized;
		const Vec3F dirInv = 1 / dir;

		// First three (X/Y/Z) planes the mouse picking beam crosses
		Vec3F hitPlanes = pos.map!"a.floor" + dir.map!"a > 0 ? 1 : 0";
		Vec3F dists = (hitPlanes - pos) * dirInv;
		WorldVec testPos = pos.map!"a.floor"().to!WorldVec;

		scope MutableBlockContext ctx = new MutableBlockContext();
		RayCastAssistant astnt;
		astnt.rayDir_ = dir;

		while (true) {
			float dist = float.max;
			int plane = 0;
			static foreach (i; 0 .. 3) {
				if (dir[i] != 0 && dists[i] < dist) {
					dist = dists[i];
					plane = i;
				}
			}

			assert(dist != float.max);

			if (dists[plane] >= maxDistance)
				return RayCastResult();

			astnt.rayPos_ = pos + dir * (dists[plane] - 0.01);

			hitPlanes[plane] += sgn(dir[plane]);
			dists[plane] += abs(dirInv[plane]);
			testPos[plane] += cast(WorldVec.T) sgn(dir[plane]);

			astnt.rayPos_ -= testPos.to!Vec3F;

			if (!isValidBlockPosition(testPos))
				return RayCastResult();

			if (!ctx.maybeSetContext(this, testPos) || ctx.isAir)
				continue;

			astnt.pos_ = testPos;
			if (auto result = ctx.block.b_rayCast(ctx, astnt))
				return result;
		}
	}

public:
	// 0 - midnight, 0.25 - dusk, 0.5 - noon, 0.75 - dawn
	float dayTime = 0.75;

public:
	version (client) auto visibleChunks() {
		return visibleChunks_[];
	}

	version (client) package Set!Chunk visibleChunks_;

private:
	Chunk processChunkLoad(Chunk chunk) {
		auto _pgd = perfGuard("chunkLoad");
		WorldVec chunkPos = chunk.pos;

		version (debugWorld)
			writeLog("chunk enterWorld ", chunkPos);

		foreach (Chunk.Neighbour n; Chunk.Neighbour.first .. Chunk.Neighbour.count) {
			Chunk ch = maybeChunkAt(chunkPos + Chunk.neighbourOffset[n]);
			chunk.neighbours_[n] = ch;
			if (ch)
				ch.neighbours_[Chunk.oppositeNeighbour(n)] = chunk;
		}

		chunk.globalUpdate(Chunk.UpdateEvent.enterWorld);
		chunk.requestActive();
		issuedChunks_.remove(chunk.pos);

		version (client) {
			resources_.processChunkLoad(chunk);

			chunk.activeChunksIndex_ = activeChunks_.length;
			activeChunks_ ~= ActiveChunk(chunk, 0);

			gameRenderer.visualiseChunk(chunk.pos, 1);
		}

		return chunk;
	}

private:
	void loadDataFromDB() {
		JSONValue[string] json = game.db.execute("SELECT data FROM worlds WHERE id = ?", worldId).oneValue!string.parseJSON().object;

		seed_ = cast(uint) json["seed"].integer;

		time_ = json["time"].float_;
		dayTime = json["dayTime"].float_;
	}

	void saveDataToDB() {
		JSONValue[string] json;

		json["seed"] = seed_;

		json["time"] = time_;
		json["dayTime"] = dayTime;

		game.db.execute("INSERT OR REPLACE INTO worlds (id, data) VALUES (?, ?)", worldId_, JSONValue(json).toString);
	}

public:
	/// Position of the camera in the world
	/// Used only for general purposes like determining the loading priority for the chunks
	version (client) WorldVec cameraPos;

private:
	version (client) {
		static struct ActiveChunk {
			Chunk chunk;
			WorldVec.T distanceFromCamera;
		}

		WorldResources resources_;
		Array!ActiveChunk activeChunks_;
	}

private:
	uint seed_;
	Game game_;
	int worldId_;
	WorldLoader loader_;
	WorldEnvironment environment_;
	Chunk[WorldVec] chunks_;
	Set!WorldVec issuedChunks_; ///< Chunks that are issued for loading
	debug bool unloaded_;
	Time time_ = 0;

}
