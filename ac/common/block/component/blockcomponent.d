module ac.common.block.component.blockcomponent;

import ac.common.block.component.toolkit;

abstract class BlockComponent {

public:
	alias Targets = uint;
	enum Target : Targets {
		render = 1 << 0,
		rayCasting = 1 << 1,
		collision = 1 << 2,
	}

	version (client) alias RenderProperties = Block.RenderProperties;
	version (client) alias RenderProperty = Block.RenderProperty;
	version (client) alias FaceFlags = Block.FaceFlags;

public:
	abstract Targets targets();

	pragma(inline) final Block block() {
		return block_;
	}

package:
	final void block(Block set) {
		assert(!block_);
		block_ = set;
	}

	final void finishRegistering_() {
		finishRegistering();
		finishedRegistering_ = true;
	}

protected:
	final pragma(inline) bool finishedRegistering() {
		return finishedRegistering_;
	}

	void finishRegistering() {

	}

public: // COLLISION TARGET
	void b_collision(BlockContext ctx, CollisionManager cmgr) {

	}

public: // RAY CASTING TARGET
	World.RayCastResult b_rayCast(BlockContext ctx, const ref World.RayCastAssistant astnt) {
		return astnt.box();
	}

public: // RENDER TARGET
	version (client) void buildPreviewRender(BlockRenderer rr) {
		b_staticRender(null, rr);
		b_dynamicRender(null, rr);
	}

	version (client) void b_staticRender(BlockContext ctx, BlockRenderer rr) {

	}

	version (client) void b_dynamicRender(BlockContext ctx, BlockRenderer rr) {

	}

	version (client) RenderProperties renderProperties() {
		return RenderProperty.none;
	}

private:
	bool finishedRegistering_;
	Block block_;

}
