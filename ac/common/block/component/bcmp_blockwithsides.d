module ac.common.block.component.bcmp_blockwithsides;

import std.algorithm;

import ac.common.block.component.toolkit;

/// A render component that draws a block where top and bottom have the same face and sides have the same face
class BlockComponent_BlockWithSides : BlockComponent {

public:
	override Targets targets() {
		return Target.render;
	}

public:
	version (client) void setTopBottomFace(string filename, BlockFaceSettings cfg = BlockFaceSettings()) {
		enforce(!topBottomFace_);
		topBottomFace_ = new BlockFace(filename, cfg);
	}

	version (client) void setSidesFace(string filename, BlockFaceSettings cfg = BlockFaceSettings()) {
		enforce(!sidesFace_);
		sidesFace_ = new BlockFace(filename, cfg);
	}

public:
	override void b_collision(BlockContext ctx, CollisionManager cmgr) {
		return cmgr.box(Vec3F(0, 0, 0), Vec3F(1, 1, 1));
	}

	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		rr.drawBlock(topBottomFace_, sidesFace_);
	}

	version (client) override RenderProperties renderProperties() {
		return topBottomFace_.settings.renderProperties(FaceFlags.topBottom) | sidesFace_.settings.renderProperties(FaceFlags.sides);
	}

protected:
	override void finishRegistering() {
		enforce(topBottomFace_);
		enforce(sidesFace_);
	}

private:
	version (client) BlockFace topBottomFace_, sidesFace_;

}
