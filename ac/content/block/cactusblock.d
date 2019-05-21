module ac.content.block.cactusblock;

import ac.content.toolkit;
import ac.common.block.toolkit;

final class Block_Cactus : Block {

public:
	this() {
		super("cactus");

		version (client) {
			BlockFaceSettings cfg;
			cfg.alphaChannel = BlockFaceSettings.AlphaChannel.alphaTest;
			cfg.betterTexturing = true;

			BlockFaceSettings sideCfg = cfg;
			sideCfg.cullFace = false;

			sideFace_ = new BlockFace("cactus_side", sideCfg);
			bottomFace_ = new BlockFace("cactus_bottom", cfg);
			topFace_ = new BlockFace("cactus_top", cfg);
		}

		lightProperties.opacity = 11;
		renderProperties = RenderProperty.fullTopBottomFaces | RenderProperty.transparentFaces | RenderProperty.nonUniform; // Make it so that top and bottom faces are not drawn when one cactus block is above the second one
	}

public:
	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		enum float l = 0.0625f;
		enum float h = 0.9375f;

		rr.drawFace(sideFace_, Vec3F(l, 1, 1), Vec3F(l, 0, 1), Vec3F(l, 1, 0), Vec3F(l, 0, 0), FaceNormalU8.left);
		rr.drawFace(sideFace_, Vec3F(h, 0, 1), Vec3F(h, 1, 1), Vec3F(h, 0, 0), Vec3F(h, 1, 0), FaceNormalU8.right);

		rr.drawFace(sideFace_, Vec3F(0, l, 1), Vec3F(1, l, 1), Vec3F(0, l, 0), Vec3F(1, l, 0), FaceNormalU8.front);
		rr.drawFace(sideFace_, Vec3F(1, h, 1), Vec3F(0, h, 1), Vec3F(1, h, 0), Vec3F(0, h, 0), FaceNormalU8.back);

		if (rr.visibleFaces & Block.FaceFlags.bottom)
			rr.drawFace(bottomFace_, Vec3F(0, 0, 0), Vec3F(1, 0, 0), Vec3F(0, 1, 0), Vec3F(1, 1, 0), FaceNormalU8.down);

		if (rr.visibleFaces & Block.FaceFlags.top)
			rr.drawFace(topFace_, Vec3F(0, 1, 1), Vec3F(1, 1, 1), Vec3F(0, 0, 1), Vec3F(1, 0, 1), FaceNormalU8.up);
	}

private:
	version (client) BlockFace sideFace_, topFace_, bottomFace_;

}

void registerContent() {
	content.block.cactus = new Block_Cactus();
}
