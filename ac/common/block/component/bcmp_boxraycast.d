module ac.common.block.component.bcmp_boxraycast;

import std.algorithm;

import ac.common.block.component.toolkit;

/// A ray casting component that casts a box
final class BlockComponent_BoxRayCast : BlockComponent {

public:
	this(Vec3F start, Vec3F end) {
		start_ = start;
		end_ = end;
	}

public:
	override Targets targets() {
		return Target.rayCasting;
	}

public:
	override World.RayCastResult b_rayCast(BlockContext ctx, const ref World.RayCastAssistant astnt) {
		return astnt.box(start_, end_);
	}

private:
	Vec3F start_, end_;

}
