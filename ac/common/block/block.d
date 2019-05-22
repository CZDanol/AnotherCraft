module ac.common.block.block;

import std.conv;

import ac.common.math.vector;
import ac.common.world.blockcontext;
import ac.common.world.chunk;
import ac.common.world.collisionmanager;
import ac.common.world.world;
import ac.content.content;

version (client) {
	import ac.client.block.blockrenderer;
}

abstract class Block {

public:
	alias ID = ushort;
	alias SmallData = ushort;

public:
	enum Face {
		left, // X-
		right, // X+
		front, // Y-
		back, // Y+
		bottom, // Z-
		top // Z+
	}

	enum WorldVec[] faceDirVec = [WorldVec(-1, 0, 0), WorldVec(1, 0, 0), WorldVec(0, -1, 0), WorldVec(0, 1, 0), WorldVec(0, 0, -1), WorldVec(0, 0, 1)];

	enum FaceFlags : ubyte {
		none = 0,

		left = 1 << Face.left,
		right = 1 << Face.right,
		front = 1 << Face.front,
		back = 1 << Face.back,
		bottom = 1 << Face.bottom,
		top = 1 << Face.top,

		all = left | right | front | back | top | bottom,
		topBottom = top | bottom,
		sides = left | right | front | back,
	}

	static struct FaceNormalU8 {
	static:
		immutable array = [Vec3U8(0, 128, 128), Vec3U8(255, 128, 128), Vec3U8(128, 0, 128), Vec3U8(128, 255, 128), Vec3U8(128, 128, 0), Vec3U8(128, 128, 255)];

		immutable left = array[Block.Face.left];
		immutable right = array[Block.Face.right];
		immutable front = array[Block.Face.front];
		immutable back = array[Block.Face.back];
		immutable down = array[Block.Face.bottom];
		immutable up = array[Block.Face.top];

		template fromVec3F(float x, float y, float z) {
			enum fromVec3F = (Vec3F(x, y, z).normalized * 127 + 127.5f).to!Vec3U8;
		}
	}

	version (client) alias RenderProperties = uint;
	/// Used for optimizations (neighbouring faces of neighnouring full blocks are not rendered)
	version (client) enum RenderProperty : RenderProperties {
		none = 0,

		fullFacesOffset = 0,
		fullLeftFace = 1 << (fullFacesOffset + Face.left),
		fullRightFace = 1 << (fullFacesOffset + Face.right),
		fullFrontFace = 1 << (fullFacesOffset + Face.front),
		fullBackFace = 1 << (fullFacesOffset + Face.back),
		fullBottomFace = 1 << (fullFacesOffset + Face.bottom),
		fullTopFace = 1 << (fullFacesOffset + Face.top),

		fullAllFaces = fullLeftFace | fullRightFace | fullFrontFace | fullBackFace | fullBottomFace | fullTopFace,
		fullSideFaces = fullLeftFace | fullRightFace | fullFrontFace | fullBackFace,
		fullTopBottomFaces = fullBottomFace | fullTopFace,

		transparentFaces = 1 << 6, ///< Transparent faces: only neighbouring faces of the blocks with the same ID or of non-transparent block are not rendered
		nonUniform = 1 << 7, ///< Block is not fully uniform, so it still has to be drawn even when all the cube faces can be repeated
		openTop = 1 << 8, ///< Block's top face only joins to the same block type
	}

public: /// How many light values/states the game uses
	enum lightValues = 16;
	enum maxLightValue = lightValues - 1;
	alias LightValue = ubyte;

	static struct LightProperties {
		ubyte opacity = maxLightValue; ///< 0 - no light value decrease
		Vec3U8 emitColor; /// 0 - maxLightValue for each component

		pragma(inline) ushort packed() {
			return cast(ushort)(opacity | emitColor.x << 4 | emitColor.y << 8 | emitColor.z << 12);
		}
	}

public:
	this(string stringId) {
		stringId_ = stringId;
		content.blockList ~= this;
	}

	void finishRegistering() {

	}

public:
	pragma(inline) string stringId() {
		return stringId_;
	}

public:
	/// Constructs the block on the provided context.
	/// There can be more variants of constructing, this is just general plain construction creating a default block
	void b_construct(BlockContext ctx) {
		assert(ctx.isAir);

		ctx.chunk.blockId(ctx.blockIndex) = ctx.game.blockId(this);

		ctx.refresh();
		ctx.chunk.localUpdate(Chunk.UpdateEvent.blockChange, ctx);
		b_enterWorld(ctx);

		version (client) {
			if (ctx.chunk.isVisible)
				b_setVisible(ctx);
		}
	}

	/// General block destruction
	void b_destroy(BlockContext ctx) {
		assert(!ctx.isAir);

		version (client) {
			if (ctx.chunk.isVisible)
				b_releaseVisible(ctx);
		}

		b_exitWorld(ctx);
		ctx.chunk.blockId(ctx.blockIndex) = 0;
		ctx.refresh();
		ctx.chunk.localUpdate(Chunk.UpdateEvent.blockChange, ctx);
	}

public:
	/// This function is called just before the block enters the world (either is loaded or created), already in the world thread
	/// This is an opt event
	void b_enterWorld(BlockContext ctx) {

	}

	/// This function is called before the chunk gets unloaded
	/// This is an opt event
	void b_exitWorld(BlockContext ctx) {

	}

	World.RayCastResult b_rayCast(BlockContext ctx, const ref World.RayCastAssistant astnt) {
		return astnt.box();
	}

	void b_collision(BlockContext ctx, CollisionManager cmgr) {
		return cmgr.box(Vec3F(0, 0, 0), Vec3F(1, 1, 1));
	}

public:
	/// This is an opt event. It is called when the block enters the user visible area
	version (client) void b_setVisible(BlockContext ctx) {

	}

	/// This is an opt event. It is called when the block leaves the user visible area
	version (client) void b_releaseVisible(BlockContext ctx) {

	}

	/// This function should draw a preview when the block is held in hands
	/// By default, this function draws static & dynamic render with null context
	/// If the context is used in static or dynamic render, it is better to override this function
	/// rather than to check if the context is null in the render functions.
	version (client) void buildPreviewRender(BlockRenderer rr) {
		b_staticRender(null, rr);
		b_dynamicRender(null, rr);
	}

	/// This function is called for all block in the chunk when the chunk staticRender update is required
	version (client) void b_staticRender(BlockContext ctx, BlockRenderer rr) {

	}

	/// Dynamic rendering is called every draw frame
	/// This is an opt event
	version (client) void b_dynamicRender(BlockContext ctx, BlockRenderer rr) {

	}

public:
	version (client) pragma(inline) RenderProperties renderProperties() {
		return renderProperties__;
	}

	protected version (client) pragma(inline) void renderProperties_(RenderProperties set) {
		if (!renderPropertiesSet_)
			renderProperties__ = set;
	}

	version (client) pragma(inline) void renderProperties(RenderProperties set) {
		assert(!renderPropertiesSet_);
		renderProperties__ = set;
		renderPropertiesSet_ = true;
	}

public:
	LightProperties lightProperties;
	bool usesData;

private:
	string stringId_;

	version (client) {
		RenderProperties renderProperties__;
		bool renderPropertiesSet_;
	}

}
