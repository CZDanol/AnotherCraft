module ac.common.block.component.componentblock;

import ac.common.block.component.toolkit;

final class ComponentBlock : Block {

public:
	alias Targets = BlockComponent.Targets;
	alias Target = BlockComponent.Target;

public:
	this(string stringId) {
		super(stringId);
	}

public:
	void addComponent(BlockComponent component) {
		assert(!finishedRegistering_);

		Targets targets = component.targets;

		components_ ~= component;
		component.block = this;

		if (targets & Target.render) {
			enforce(!renderComponent_, "Block already has a render component (You have to nest them eventually)");
			renderComponent_ = component;
		}

		if (targets & Target.rayCasting) {
			enforce(!rayCastingComponent_, "Block already has a ray casting component");
			rayCastingComponent_ = component;
		}

		if (targets & Target.collision) {
			enforce(!collisionComponent_, "Block already has a collision component");
			collisionComponent_ = component;
		}
	}

	override void finishRegistering() {
		foreach (c; components_)
			c.finishRegistering_();

		version (client)
			renderProperties_ = renderComponent_.renderProperties;

		if (!rayCastingComponent_)
			rayCastingComponent_ = renderComponent_;

		if (!collisionComponent_)
			collisionComponent_ = renderComponent_;

		finishedRegistering_ = true;
	}

public:
	override void b_collision(BlockContext ctx, CollisionManager cmgr) {
		return collisionComponent_.b_collision(ctx, cmgr);
	}

public:
	override World.RayCastResult b_rayCast(BlockContext ctx, const ref World.RayCastAssistant astnt) {
		return rayCastingComponent_.b_rayCast(ctx, astnt);
	}

public:
	version (client) override void buildPreviewRender(BlockRenderer rr) {
		renderComponent_.buildPreviewRender(rr);
	}

	version (client) override void b_staticRender(BlockContext ctx, BlockRenderer rr) {
		renderComponent_.b_staticRender(ctx, rr);
	}

	version (client) override void b_dynamicRender(BlockContext ctx, BlockRenderer rr) {
		renderComponent_.b_dynamicRender(ctx, rr);
	}

private:
	bool finishedRegistering_;

private:
	BlockComponent[] components_;
	BlockComponent renderComponent_, rayCastingComponent_, collisionComponent_;

}
