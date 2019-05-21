module ac.common.block.component.bcmp_nocollision;

import std.algorithm;

import ac.common.block.component.toolkit;

/// A collision component with no collisions
final class BlockComponent_NoCollision : BlockComponent {

public:
	override Targets targets() {
		return Target.collision;
	}

public:
	override void b_collision(BlockContext ctx, CollisionManager cmgr) {

	}

}
