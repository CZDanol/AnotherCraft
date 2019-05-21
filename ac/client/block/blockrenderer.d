module ac.client.block.blockrenderer;

import ac.common.world.chunk;
import ac.common.block.block;
import ac.client.block.blockface;
import ac.common.math.vector;

/// Block renderer can be used for standard block rendering, click detection etc
abstract class BlockRenderer {

public:
	/// Draws a full block
	abstract void drawBlock(BlockFace face);
	abstract void drawBlock(BlockFace topBottomFace, BlockFace sideFace);
	abstract void drawBlock(BlockFace topFace, BlockFace bottomFace, BlockFace sideFace);

	abstract void drawFace(BlockFace face, Vec3U8 lt, Vec3U8 rt, Vec3U8 lb, Vec3U8 rb, Vec3U8 normal);
	abstract void drawFace(BlockFace face, Vec3F lt, Vec3F rt, Vec3F lb, Vec3F rb, Vec3U8 normal);

public:
	Block.FaceFlags visibleFaces = Block.FaceFlags.all;

}
