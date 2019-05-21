module ac.common.block.component.bcmp_boxcollision;

import std.algorithm;

import ac.common.block.component.toolkit;

/// A collision component that is defined by a static collision box
final class BlockComponent_BoxCollision : BlockComponent {

public:
	this(Vec3F l = Vec3F(0, 0, 0), Vec3F h = Vec3F(1, 1, 1)) {
		l_ = l;
		h_ = h;
	}

public:
	override Targets targets() {
		return Target.collision;
	}

public:
	override void b_collision(BlockContext ctx, CollisionManager cmgr) {
		return cmgr.box(l_, h_);
	}

private:
	Vec3F l_, h_;

}
