module ac.content.block.miscblocks;

import std.conv;
import ac.content.toolkit;

void registerContent() {
	{
		auto block = new SimpleBlock("lampRed");
		block.lightProperties.emitColor.x = Block.maxLightValue;
		block.setFace(BlockFaceSettings.assemble!(["betterTexturing", "alphaChannel"])(true, BlockFaceSettings.AlphaChannel.glow), "lampRed");
		content.block.lampR = block;
	}

	{
		auto block = new SimpleBlock("lampGreen");
		block.lightProperties.emitColor.y = Block.maxLightValue;
		block.setFace(BlockFaceSettings.assemble!(["betterTexturing", "alphaChannel"])(true, BlockFaceSettings.AlphaChannel.glow), "lampGreen");
		content.block.lampG = block;
	}

	{
		auto block = new SimpleBlock("lampBlue");
		block.lightProperties.emitColor.z = Block.maxLightValue;
		block.setFace(BlockFaceSettings.assemble!(["betterTexturing", "alphaChannel"])(true, BlockFaceSettings.AlphaChannel.glow), "lampBlue");
		content.block.lampB = block;
	}

	{
		auto block = new SimpleBlock("lamp");
		block.lightProperties.emitColor = Vec3U8(15, 13, 13);
		block.setFace(BlockFaceSettings.assemble!(["betterTexturing", "alphaChannel"])(true, BlockFaceSettings.AlphaChannel.glow), "lamp");
		content.block.lamp = block;
	}

	{
		auto block = new ComponentBlock("glowShroom");
		block.lightProperties.opacity = 0;
		block.lightProperties.emitColor = (Vec3F(86, 172, 151) / 255 * 0.5 * Block.maxLightValue).to!Vec3U8;

		auto rcmp = new BlockComponent_CrossBlock();
		version (client)
			rcmp.setFace("glowShroom", BlockFaceSettings.assemble!(["alphaChannel"])(BlockFaceSettings.AlphaChannel.alphaTestGlow));
		block.addComponent(rcmp);

		block.addComponent(new BlockComponent_BoxRayCast(Vec3F(0.3, 0.3, 0), Vec3F(0.7, 0.7, 0.5)));
		content.block.glowShroom = block;
	}

	{
		auto block = new SimpleBlock("cyanGlass");
		block.lightProperties.opacity = 3;
		block.setFace(BlockFaceSettings.assemble!(["alphaChannel", "cullFace"])(BlockFaceSettings.AlphaChannel.transparency, false));
		content.block.cyanGlass = block;
	}

	{
		auto block = new ComponentBlock("water");
		block.lightProperties.opacity = 1;

		auto rcmp = new BlockComponent_LiquidBlock();
		version (client)
			rcmp.setFace("water", BlockFaceSettings.assemble!(["alphaChannel", "waving"])(BlockFaceSettings.AlphaChannel.transparency, BlockFaceSettings.Waving.liquidSurface));

		block.addComponent(rcmp);

		content.block.water = block;
	}

	{
		auto block = new SimpleBlock("glowingOre");
		block.lightProperties.emitColor = (Vec3F(173, 48, 41) / 255 * 16 * 0.2).to!Vec3U8;
		version (client)
			block.setFace(BlockFaceSettings.assemble!(["alphaChannel", "betterTexturing"])(BlockFaceSettings.AlphaChannel.glow, true));
		content.block.glowingOre = block;
	}

	{
		auto block = (string name) { //
			auto block = new ComponentBlock(name);
			block.lightProperties.opacity = 3;

			auto rcmp = new BlockComponent_CrossBlock();
			version (client)
				rcmp.setFace(name, BlockFaceSettings.assemble!(["waving", "wrap"])(BlockFaceSettings.Waving.windTop, false));
			block.addComponent(rcmp);

			block.addComponent(new BlockComponent_BoxRayCast(Vec3F(0.3, 0.3, 0), Vec3F(0.7, 0.7, 0.5)));
			return block;
		};

		content.block.grassTuft = block("grassTuft");
		content.block.blueOrchid = block("blueOrchid");
		content.block.poppy = block("poppy");
		content.block.oxyeyeDaisy = block("oxyeyeDaisy");
	}

	{
		auto block = new ComponentBlock("wheat");
		block.lightProperties.opacity = 4;

		auto rcmp = new BlockComponent_2x2GridBlock();
		version (client)
			rcmp.setFace("wheat", BlockFaceSettings.assemble!(["waving"])(BlockFaceSettings.Waving.windTop));
		block.addComponent(rcmp);

		content.block.wheat = block;
	}

	{
		auto block = (string name) { //
			auto block = new ComponentBlock(name);
			block.lightProperties.opacity = 2;

			auto rcmp = new BlockComponent_CrossBlock();
			version (client)
				rcmp.setFace(name, BlockFaceSettings.assemble!(["wrap"])(false));
			block.addComponent(rcmp);

			block.addComponent(new BlockComponent_BoxRayCast(Vec3F(0.3, 0.3, 0), Vec3F(0.7, 0.7, 0.5)));
			return block;
		};

		content.block.brownMushroom = block("brownMushroom");
		content.block.redMushroom = block("redMushroom");
	}

	/*{
		auto block = new SimpleBlock("lightTestBlock");
		block.lightProperties.opacity = 15;
		block.setFace(BlockFaceSettings.assemble!(["alphaChannel"])(BlockFaceSettings.AlphaChannel.alphaTest));
		content.block.lightTestBlock = block;
	}*/
}
