module ac.common.game.db;

import std.exception;
import std.format;
import d2sqlite3.database;

enum currentDbVersion = 1;

void checkDbMigration(ref Database db) {
	enforce(db.execute("SELECT value FROM settings WHERE key = 'dbVersion'").oneValue!int == currentDbVersion, "Unsupported save version");
}

/// Creates database structure
void initDb(ref Database db) {
	db.execute("CREATE TABLE settings (
		key STRING PRIMARY KEY NOT NULL,
		value STRING
	)");
	db.execute("INSERT INTO settings (key, value) VALUES ('dbVersion', %s)".format(currentDbVersion));

	db.execute("CREATE TABLE worlds (
		id INTEGER PRIMARY KEY,
		data STRING
	)");

	db.execute("CREATE TABLE chunks (
		world INTEGER NOT NULL,
		x INTEGER NOT NULL,
		y INTEGER NOT NULL,
		blocks BLOB NOT NULL
	)");
	db.execute("CREATE UNIQUE INDEX chunks_i_primary ON chunks (world, x, y)");
}
