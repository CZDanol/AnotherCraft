module ac.common.block.component.bcmp_2x2gridblock;

import ac.common.block.component.toolkit;

/**
	A render component that draws this grid pattern:
	  | | 
	 -----
	  | | 
	 -----
	  | |
	**/
final class BlockComponent_2x2GridBlock : BlockComponent {

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
		rr.drawFace(face_, Vec3F(0, 0.3, 1), Vec3F(1, 0.3, 1), Vec3F(0, 0.3, 0), Vec3F(1, 0.3, 0), Block.FaceNormalU8.fromVec3F!(0, -1, 0.3));
		rr.drawFace(face_, Vec3F(0, 0.6, 1), Vec3F(1, 0.6, 1), Vec3F(0, 0.6, 0), Vec3F(1, 0.6, 0), Block.FaceNormalU8.fromVec3F!(0, -1, 0.3));

		rr.drawFace(face_, Vec3F(0.3, 1, 1), Vec3F(0.3, 0, 1), Vec3F(0.3, 1, 0), Vec3F(0.3, 0, 0), Block.FaceNormalU8.fromVec3F!(-1, 0, 0.3));
		rr.drawFace(face_, Vec3F(0.6, 1, 1), Vec3F(0.6, 0, 1), Vec3F(0.6, 1, 0), Vec3F(0.6, 0, 0), Block.FaceNormalU8.fromVec3F!(-1, 0, 0.3));
	}

	version (client) override RenderProperties renderProperties() {
		return (face_.settings.renderProperties(FaceFlags.all) & ~RenderProperty.fullAllFaces) | RenderProperty.nonUniform;
	}

protected:
	override void finishRegistering() {
		enforce(face_);
	}

private:
	version (client) BlockFace face_;

}
