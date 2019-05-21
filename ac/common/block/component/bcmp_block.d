module ac.common.block.component.bcmp_block;

import std.algorithm;
import std.conv;

import ac.common.block.component.toolkit;

/// A render component that draws a block where all sides have the same face
class BlockComponent_Block : BlockComponent {

public:
	override Targets targets() {
		return Target.render;
	}

public:
	version (client) void setFace(string filename, BlockFaceSettings cfg = BlockFaceSettings()) {
		enforce(!face_);
		face_ = new BlockFace(filename, cfg);
	}

public:
	override void b_collision(BlockContext ctx, CollisionManager cmgr) {
		return cmgr.box(Vec3F(0, 0, 0), Vec3F(1, 1, 1));
	}

	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		rr.drawBlock(face_);
	}

	version (client) override RenderProperties renderProperties() {
		return face_.settings.renderProperties(Block.FaceFlags.all);
	}

protected:
	override void finishRegistering() {
		enforce(face_);
	}

protected:
	version (client) BlockFace face_;

}
