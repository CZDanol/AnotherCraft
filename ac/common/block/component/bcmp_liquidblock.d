module ac.common.block.component.bcmp_liquidblock;

import std.algorithm;

import ac.common.block.component.toolkit;

/// A block with top side slightly lowered, the top surface can be waving
class BlockComponent_LiquidBlock : BlockComponent {

public:
	override Targets targets() {
		return Target.render;
	}

public:
	version (client) void setFace(string filename, BlockFaceSettings cfg = BlockFaceSettings()) {
		enforce(!topFace_);

		topFace_ = new BlockFace(filename, cfg);
		if (cfg.waving == BlockFaceSettings.Waving.liquidSurface) {
			cfg.nonUniform = true;
			cfg.waving = BlockFaceSettings.Waving.none;
			bottomFace_ = new BlockFace(filename, cfg);

			cfg.nonUniform = true;
			cfg.waving = BlockFaceSettings.Waving.liquidTop;
			sideFace_ = new BlockFace(filename, cfg);
		}
		else {
			sideFace_ = topFace_;
			bottomFace_ = topFace_;
		}
	}

public:
	override void b_collision(BlockContext ctx, CollisionManager cmgr) {
		return cmgr.box(Vec3F(0, 0, 0), Vec3F(1, 1, 1));
	}

	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		const bool fullBlock = !(rr.visibleFaces & Block.FaceFlags.top);
		rr.drawBlock(fullBlock ? bottomFace_ : topFace_, bottomFace_, fullBlock ? bottomFace_ : sideFace_);
	}

	version (client) override RenderProperties renderProperties() {
		return RenderProperty.fullAllFaces | RenderProperty.transparentFaces | RenderProperty.nonUniform | RenderProperty.openTop;
	}

protected:
	override void finishRegistering() {
		enforce(topFace_);
	}

protected:
	version (client) BlockFace bottomFace_, sideFace_, topFace_;

}
