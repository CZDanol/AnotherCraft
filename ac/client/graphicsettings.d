module ac.client.graphicsettings;

import ac.common.math.vector;

GraphicSettings graphicSettings;

final class GraphicSettings {

public:
	alias Changes = uint;

	enum Change : Changes {
		resolution = 1 << 0,
		antiAliasing = 1 << 1,
		ssao = 1 << 2,
		shading = 1 << 3,
		surfaceData = 1 << 4,
		shadowMapping = 1 << 5,
		depthOfField = 1 << 6,
		blendLayerCount = 1 << 7,
		showSingleBlendLayer = 1 << 8,
		gui = 1 << 9,
		godRays = 1 << 10,
		shadingArtifactCompensation = 1 << 11,
		betterTexturing = 1 << 12,
		msaaAlphaTest = 1 << 13,
		aggregationStrategy = 1 << 14,
		waving = 1 << 15,
		tJunctionHiding = 1 << 16,
		atmosphere = 1 << 17,
	}

	alias ChangeCallback = void delegate(Changes changes);

	enum Shading {
		off,
		deferredMSAA,
		deferred
	}

	enum SurfaceData {
		color,
		normal,
		depth,
	}

	enum ShadowMapping {
		off,
		x1024,
		x2048,
		x4096,
		_count
	}

	enum GUI {
		none,
		game,
		full,
		_count
	}

	static immutable int[ShadowMapping._count] shadowMapResolution = [ShadowMapping.off : 1, ShadowMapping.x1024 : 1024, ShadowMapping.x2048 : 2048, ShadowMapping.x4096 : 4096];

	enum SSAO {
		off,
		blurred,
		sharp
	}

	enum AggregationStrategy {
		none,
		lines,
		squares,
		squaresExt
	}

public:
	Vec2I resolution = Vec2I(1280, 720);
	int antiAliasing = 2; ///< 1 = off
	SSAO ssao = SSAO.off;
	bool depthOfField = true;
	bool atmosphere = true;
	bool godRays = true;
	int showSingleBlendLayer = -1;
	int blendLayerCount = 3;
	bool betterTexturing = true;
	bool msaaAlphaTest = true;
	bool waving = true;
	bool tJunctionHiding = true;

public:
	Shading shading = Shading.deferredMSAA;
	SurfaceData surfaceData = SurfaceData.color;
	ShadowMapping shadowMapping = ShadowMapping.x2048;
	AggregationStrategy aggregationStrategy = AggregationStrategy.squaresExt;

public:
	GUI gui = GUI.full;
	float advanceDaytimeSpeed = 1;
	bool fullScreen = false;
	int viewDistance = 16;

public:
	void addChangeListener(Object o, ChangeCallback callback) {
		void* key = cast(void*) o;

		if (auto it = key in onChangeAA_) {
			onChange_[*it] = callback;
			return;
		}

		size_t ix = onChange_.length;
		onChangeAA_[key] = ix;
		onChange_ ~= callback;
	}

	void emitChange(Changes changes) {
		foreach (ChangeCallback c; onChange_)
			c(changes);
	}

	void opIndexAssign(ChangeCallback callback, Object o) {
		addChangeListener(o, callback);
	}

private: /// All delegates should be called when any graphic settings change
	size_t[void* ] onChangeAA_;
	ChangeCallback[] onChange_;

}
