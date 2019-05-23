module ac.common.block.component.bcmp_crossblock;

import ac.common.block.component.toolkit;

/// A render component that draws two crossed faces
final class BlockComponent_CrossBlock : BlockComponent {

public:
	override Targets targets() {
		return Target.render;
	}

public:
	version (client) void setFace(string filename, BlockFaceSettings cfg = BlockFaceSettings()) {
		enforce(!face_);

		if (cfg.alphaChannel != BlockFaceSettings.AlphaChannel.alphaTestGlow)
			cfg.alphaChannel = BlockFaceSettings.AlphaChannel.alphaTest;

		cfg.cullFace = false;
		cfg.wrap = false;
		cfg.backFacingNormal = BlockFaceSettings.BackFacingNormal.invertXY;

		face_ = new BlockFace(filename, cfg);
	}

public:
	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		rr.drawFace(face_, Vec3U8(0, 0, 1), Vec3U8(1, 1, 1), Vec3U8(0, 0, 0), Vec3U8(1, 1, 0), Block.FaceNormalU8.fromVec3F!(1, -1, 2));
		rr.drawFace(face_, Vec3U8(0, 1, 1), Vec3U8(1, 0, 1), Vec3U8(0, 1, 0), Vec3U8(1, 0, 0), Block.FaceNormalU8.fromVec3F!(-1, -1, 2));
	}

	version (client) override RenderProperties renderProperties() {
		return (face_.settings.renderProperties(Block.FaceFlags.all) & ~RenderProperty.fullAllFaces) | RenderProperty.nonUniform;
	}

protected:
	override void finishRegistering() {
		enforce(face_);
	}

private:
	version (client) BlockFace face_;

}
