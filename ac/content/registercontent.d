module ac.content.registercontent;

import std.format;

enum modules = [ //
	"block.groundblocks", "block.miscblocks", "block.woodblocks", //
	"block.cactusblock" //
	];

/// Registers content to the current game (instance stored in the TLS game variable)
void registerContent() {
	static foreach (m; modules)
		mixin("static import ac.content.%s; ac.content.%s.registerContent();".format(m, m));
}
