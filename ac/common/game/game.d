module ac.common.game.game;

import std.format;
import std.algorithm;
import std.file;
import std.exception;
import std.container.array;
import d2sqlite3.database;

import ac.content.content;
import ac.common.block.block;
import ac.common.world.world;
import ac.common.game.db;
import ac.common.util.log;

static import d2sqlite3.library;

version (client) {
	import bindbc.opengl;

	import ac.client.gl.glresourcemanager;
}

final class Game {
	static assert(Block.ID.sizeof >= 2);

public:
	this(string saveName = "default") {
		saveName_ = saveName;
		blockList_ = [null];

		foreach (Block block; content.blockList) {
			blockIds_[block] = cast(Block.ID)(blockList_.length);
			blockList_ ~= block;
		}

		enforce(d2sqlite3.library.threadSafe, "A thread-safe version of sqlite3 is required");

		bool memoryDb = false;

		try {
			if (!exists("../save"))
				mkdir("../save");
		}
		catch (FileException e) {
			writeLog("Failed to create 'save' folder. Switching to memory mapped database.");
			memoryDb = true;
		}

		if (memoryDb) {
			db_ = Database(":memory:");
			initDb(db_);
		}
		else {
			const string dbFilename = "../save/%s.sqlite".format(saveName);
			const bool dbExists = dbFilename.exists;
			db_ = Database(dbFilename);
			db_.execute("PRAGMA journal_mode = PERSIST");
			db_.execute("PRAGMA synchronous = OFF");

			if (dbExists)
				checkDbMigration(db_);
			else
				initDb(db_);
		}

		version (client) {
			blockListBuffer_ = glResourceManager.create(GLResourceType.buffer);

			Array!uint data;
			data.length = blockList_.length;

			foreach (i, block; blockList_)
				data[i] = (i == 0 ? 0 : block.lightProperties.packed | block.renderProperties << 16);

			glNamedBufferStorage(blockListBuffer_, data.length * uint.sizeof, &data[0], 0);
		}
	}

	void end() {
		//db_.close();
	}

public:
	pragma(inline) Block block(Block.ID id) {
		if (id == 0)
			return null;

		debug assert(id < blockList_.length, "Block id %s not in the game".format(id));
		return blockList_[id];
	}

	pragma(inline) Block.ID blockId(Block block) {
		return blockIds_[block];
	}

	version (client) pragma(inline) GLuint blockListBuffer() {
		return blockListBuffer_;
	}

public:
	pragma(inline) ref Database db() {
		return db_;
	}

private:
	string saveName_;
	Database db_;

private:
	size_t simpleBlockRangeEnd_;
	Block[] blockList_;
	Block.ID[Block] blockIds_;

private:
	version (client) GLuint blockListBuffer_;

}

Game game;
