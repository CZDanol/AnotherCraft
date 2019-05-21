module ac.common.world.collisionmanager;

import std.algorithm;

import ac.common.math.vector;

final class CollisionManager {

public:
	/// Collides with a AABB box defined by l and h corners
	void box(Vec3F l_, Vec3F h_) {
		const Vec3F l = l_ + offset;
		const Vec3F h = h_ + offset;

		Vec3F tpos = colliderPos;

		foreach (i; 0 .. 3) {
			tpos[i] = targetColliderPos[i];

			const bool isCollision = h.all!"a > b"(tpos - colliderBoxRadius) && l.all!"a < b"(tpos + colliderBoxRadius);
			if (!isCollision)
				continue;

			if (tpos[i] < colliderPos[i])
				targetColliderPos[i] = min(max(h[i] + colliderBoxRadius[i], targetColliderPos[i]), colliderPos[i]);
			else if (tpos[i] > colliderPos[i])
				targetColliderPos[i] = max(min(l[i] - colliderBoxRadius[i], targetColliderPos[i]), colliderPos[i]);

			colliderVelocity[i] = 0;
			isColliderOnGround |= (i == 2) && (tpos[i] < colliderPos[i]);

			break;
		}
	}

public:
	Vec3F offset;

public:
	Vec3F colliderPos, targetColliderPos; //< Where the player is and where he wants to move
	Vec3F colliderBoxRadius; //< Half the size of the actual box
	Vec3F colliderVelocity; //< Does not alter the collisions in any way, only reduces the velocity on collisions
	bool isColliderOnGround;

}
