module ac.common.block.simpleblock;

import std.format;

import ac.common.block.block;
import ac.common.world.blockcontext;
import ac.common.math.vector;
import ac.content.content;

version (client) {
	import ac.client.block.blockface;
	import ac.client.block.blockrenderer;
}

/// Simple block is a cube block where block data do not affect the block visuals (can affect dynamic render)
final class SimpleBlock : Block {

public:
	this(string stringId) {
		super(stringId);
	}

	override void finishRegistering() {
		version (client) {
			if (!face_)
				setFace();
		}
	}

public:
	version (client) void setFace(BlockFaceSettings cfg = BlockFaceSettings(), string filename = null) {
		assert(!face_);

		face_ = new BlockFace(filename ? filename : stringId, cfg);
		renderProperties_ = face_.settings.renderProperties(FaceFlags.all);
	}

public:
	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		rr.drawBlock(face_);
	}

private:
	version (client) BlockFace face_;

}
