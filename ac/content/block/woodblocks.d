module ac.content.block.woodblocks;

import ac.content.toolkit;
import ac.common.block.component.toolkit;

final class BlockComponent_LeavesRender : BlockComponent_Block {

public:
	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		rr.drawBlock(face_);

		enum h = 1.2;
		enum l = -0.2;

		if (rr.visibleFaces != Block.FaceFlags.none) {
			rr.drawFace(face_, Vec3F(l, l, h), Vec3F(h, h, h), Vec3F(l, l, l), Vec3F(h, h, l), Block.FaceNormalU8.up);
			rr.drawFace(face_, Vec3F(l, h, h), Vec3F(h, l, h), Vec3F(l, h, l), Vec3F(h, l, l), Block.FaceNormalU8.up);
		}
	}

}

void registerContent() {
	{
		auto block = new ComponentBlock("oakLog");
		auto rcompo = new BlockComponent_BlockWithSides();
		rcompo.setTopBottomFace("oakLogTop");
		rcompo.setSidesFace("oakLog", BlockFaceSettings.assemble!(["betterTexturing"])(true));
		block.addComponent(rcompo);

		content.block.oakLog = block;
	}

	{
		auto block = new SimpleBlock("oakLeaves");
		block.lightProperties.opacity = 3;
		block.setFace(BlockFaceSettings.assemble!(["alphaChannel", "waving", "cullFace"])(BlockFaceSettings.AlphaChannel.alphaTest, BlockFaceSettings.Waving.windWhole, true));

		/*auto block = new ComponentBlock("oakLeaves");

		auto rcmp = new BlockComponent_LeavesRender();
		block.lightProperties.opacity = 5;

		version (client)
			rcmp.setFace("oakLeaves", BlockFaceSettings.assemble!(["alphaChannel", "waving", "cullFace"])(BlockFaceSettings.AlphaChannel.alphaTest, BlockFaceSettings.Waving.wholeBlock, true));

		block.addComponent(rcmp);*/

		content.block.oakLeaves = block;
	}
}
