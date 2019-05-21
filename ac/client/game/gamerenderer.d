module ac.client.game.gamerenderer;

version = topDownView;

import bindbc.opengl;
import core.bitop;
import core.memory;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.math;
import std.stdio;

import ac.client.application;
import ac.client.block.blockfacerenderingcontext;
import ac.client.block.renderer.standardblockrenderer;
import ac.client.game.frustummanager;
import ac.client.game.postprocessingmanager;
import ac.client.gl;
import ac.client.gl.gldebugrenderer;
import ac.client.graphicsettings;
import ac.client.resources;
import ac.client.world.chunkrenderbuffers;
import ac.client.world.chunkrenderregion;
import ac.client.world.worldresources;
import ac.common.block.block;
import ac.common.math.matrix;
import ac.common.math.vector;
import ac.common.util.aa;
import ac.common.util.ringbuffer;
import ac.common.util.perfwatch;
import ac.common.world.chunk;
import ac.common.world.env.worldenvironment;
import ac.common.world.world;

__gshared GameRenderer gameRenderer;

final class GameRenderer {

public:
	enum maxViewDistanceInChunks = 64;
	enum maxViewDistanceInBlocks = maxViewDistanceInChunks * Chunk.width;

	/// Max render area in blocks
	enum maxViewAreaWidthInChunks = (maxViewDistanceInChunks * 2 + 1);
	enum maxViewAreaWidthInBlocks = maxViewAreaWidthInChunks * Chunk.width;

	enum cameraViewNear = 0.2;
	enum cameraViewFar = 1024;
	enum cameraViewFovy = 0.4; // % of 180°

	enum shadowMapViewFar = 1024;

	/// How high the shadow map 'camera' is
	enum shadowMapViewHeight = 512;

public:
	static struct RenderConfig {

	public:
		World world;
		WorldEnvironment.LightSettings lightSettings;

	public:
		Matrix cameraViewMatrix, invertedCameraViewMatrix, cameraFrustumMatrix, invertedCameraFrustumMatrix;
		Matrix shadowRenderMatrix, shadowSamplingMatrix;
		Matrix buildPreviewMatrix;

	public:
		Vec3F cameraPos;
		Vec2F cameraRot;
		WorldVec coordinatesOffset;

	public:
		Vec2I windowSize;

	}

public:
	this() {
		frustumManager_ = new FrustumManager();
		postprocessingManager_ = new PostprocessingManager(this);

		auto defines = contextDefines;

		// Build preview stuff
		{
			buildPreviewBuffers_ = ChunkRenderBuffers(0);
			buildPreviewRenderer_ = new StandardBlockRenderer();
		}

		graphicSettings[this] = (GraphicSettings.Changes changes) { //
			updateSettings();
		};

		// Debugging
		static extern (System) void debugFunc(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length, const GLchar* message, const void* userParam) nothrow {
			try {
				import core.runtime, std.stdio;

				// Some buffer memory info
				if (id == 131185 || graphicSettings.gui != GraphicSettings.GUI.full)
					return;

				writeln(id, " ", message.to!string);
				writeln(defaultTraceHandler());
			}
			catch (Throwable t) {

			}
		}

		if (application.debugGL) {
			glState.setEnabled(bindbc.opengl.bind.gl43.GL_DEBUG_OUTPUT_SYNCHRONOUS, true);
			bindbc.opengl.bind.gl43.glDebugMessageCallback(&debugFunc, null);
		}
	}

	~this() {
		foreach (ref jobs; glJobs_) {
			while (!jobs.isEmpty) {
				GLJobRec rec = jobs.takeFront();
				glDeleteSync(rec.sync);
				rec.onReleaseResources(rec.resourcesId);
			}
		}
	}

public:
	void cameraPos(Vec3F set) {
		cfg_.cameraPos = set;
	}

	void cameraRot(Vec2F set) {
		cfg_.cameraRot = set;
	}

	void world(World set) {
		cfg_.world = set;
	}

	ref const(RenderConfig) renderConfig() {
		return cfg_;
	}

	ref float animationTime() {
		return animTime_;
	}

public:
	void updateSettings() {

	}

	void issueGPUComputation() {
		calculateViewMatrices();

		// Let the frustum manager calculate which areas are in frustum
		const Matrix[2] matrices = [cfg_.cameraFrustumMatrix, cfg_.shadowRenderMatrix];

		frustumManager_.issueGPUComputation(cfg_.world, cfg_.cameraPos, graphicSettings.viewDistance, cfg_.coordinatesOffset, matrices);

		glMemoryBarrier(GL_ATOMIC_COUNTER_BARRIER_BIT | GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT);
		sync_ = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);

		prepareBuildPreview();
	}

	void render() {
		cfg_.lightSettings = cfg_.world.environment.lightSettings;
		animTime_ += deltaTime;
		drawnTriangleCount = 0;

		auto syncResult = glClientWaitSync(sync_, GL_SYNC_FLUSH_COMMANDS_BIT, GLuint64.max);
		glDeleteSync(sync_);
		assert(syncResult == GL_CONDITION_SATISFIED || syncResult == GL_ALREADY_SIGNALED, "Wrong sync result: %s".format(syncResult));

		frustumManager_.processGPUComputation(cfg_.world);

		glClearColor(0, 0, 0, 0);

		// Draw the world to the framebuffer
		with (postprocessingManager_.colorPass(0).fbo.boundGuard) {
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
			renderWorld(cfg_.cameraViewMatrix, 0, BlockFaceRenderingContext.ContextType.standard, false, "worldRender", true);
		}

		// Copy the depth texture from the first (opaque) color pass to other (transparent) passes; we don't want transparent stuff behind the opaque stuff to be rendered
		{
			GLTexture sourceTex = postprocessingManager_.colorPass(0).depthTex;
			foreach (i; 1 .. graphicSettings.blendLayerCount + 1) {
				GLTexture targetTex = postprocessingManager_.colorPass(i).depthTex;
				glCopyImageSubData( //
						sourceTex.textureId, sourceTex.textureType, 0, 0, 0, 0, //
						targetTex.textureId, targetTex.textureType, 0, 0, 0, 0, //
						cfg_.windowSize.x, cfg_.windowSize.y, 1 //
						);
			}
		}

		// Also copy the normal texture from the opaque layer to the first transparent pass because of SSAO
		if (graphicSettings.blendLayerCount > 0) {
			GLTexture sourceTex = postprocessingManager_.colorPass(0).normalTex;
			GLTexture targetTex = postprocessingManager_.colorPass(1).normalTex;
			glCopyImageSubData( //
					sourceTex.textureId, sourceTex.textureType, 0, 0, 0, 0, //
					targetTex.textureId, targetTex.textureType, 0, 0, 0, 0, //
					cfg_.windowSize.x, cfg_.windowSize.y, 1 //
					);
		}

		// Draw the first transparent layer
		if (graphicSettings.blendLayerCount > 0) {
			with (postprocessingManager_.colorPass(1).fbo.boundGuard) {
				//glClear(GL_COLOR_BUFFER_BIT);
				// Clear only color buffer (not normal), because normal is copied from the pass 0 because of SSAO
				GLint[4] cl = [0, 0, 0, 0];
				glClearBufferiv(GL_COLOR, 0, cl.ptr);
				renderWorld(cfg_.cameraViewMatrix, 0, BlockFaceRenderingContext.ContextType.standard, true, "worldRender_transparent0", true);
			}
		}

		foreach (i; 2 .. graphicSettings.blendLayerCount + 1) {
			// Each subsequent depth peeling transparency layer only draws object behind the previous layer -> there is a near depth test based on previous layer depth texture
			postprocessingManager_.colorPass(i - 1).depthTex.bind(0);

			with (postprocessingManager_.colorPass(i).fbo.boundGuard) {
				glClear(GL_COLOR_BUFFER_BIT);
				renderWorld(cfg_.cameraViewMatrix, 0, BlockFaceRenderingContext.ContextType.nearDepthTest, true, "worldRender_transparent%s".format(i - 1), true);
			}
		}

		// Draw the shadow map
		if (graphicSettings.shadowMapping != GraphicSettings.ShadowMapping.off) {
			with (postprocessingManager_.boundShadowFBO(0)) {

				int shadowMapResolution = graphicSettings.shadowMapResolution[graphicSettings.shadowMapping];
				glViewport(0, 0, shadowMapResolution, shadowMapResolution);
				glClear(GL_DEPTH_BUFFER_BIT);

				renderWorld(cfg_.shadowRenderMatrix, 1, BlockFaceRenderingContext.ContextType.depthOnly, false, "shadowMapRender", false);
			}

			glViewport(0, 0, cfg_.windowSize.x, cfg_.windowSize.y);
		}

		doMousePicking();
		postprocessingManager_.process(cfg_);
	}

	// Visualise chunk for debugging purposes
	void visualiseChunk(WorldVec pos, ubyte color) {
		if (!visualiseLoadedChunks)
			return;

		auto mat = renderConfig.cameraViewMatrix;
		auto posF = (pos + cfg_.coordinatesOffset).to!Vec3F;
		auto sz = Vec3F(Chunk.width, Chunk.width, Chunk.height);
		glDebugRenderer.drawBox(mat, posF, posF + sz, color);
		glDebugRenderer.drawLine(Vec4F(0, 0, 0, 1), mat * (posF + sz / 2), color);
	}

private:
	void calculateViewMatrices() {
		cfg_.windowSize = application.windowSize;

		// Camera pos is offsetted to lower numbers to improve precision
		cfg_.coordinatesOffset = -Chunk.chunkPos(WorldVec(cfg_.cameraPos.to!WorldVec.xy, 0));

		// Calculate camera view matrix
		{
			cfg_.cameraViewMatrix = Matrix.perspective(cfg_.windowSize.to!Vec2F, cameraViewFovy * PI, cameraViewNear, cameraViewFar) * Matrix.rotationX270() /* Z upwards */ ;
			cfg_.cameraViewMatrix *= Matrix.rotationX(cfg_.cameraRot.y) * Matrix.rotationZ(cfg_.cameraRot.x);
			cfg_.cameraViewMatrix.translate(-(cfg_.cameraPos + cfg_.coordinatesOffset.to!Vec3F));

			cfg_.cameraFrustumMatrix = cfg_.cameraViewMatrix;
			cfg_.invertedCameraFrustumMatrix = cfg_.cameraViewMatrix.inverted();
			cfg_.invertedCameraViewMatrix = cfg_.invertedCameraFrustumMatrix;
		}

		if (topDownView) {
			const float viewHeight = (graphicSettings.viewDistance * 2 + 1) * Chunk.width;
			Vec2F windowSizeF = application.windowSize.to!Vec2F;
			cfg_.cameraViewMatrix = Matrix.orthogonalCentered(Vec2F(viewHeight / windowSizeF.y * windowSizeF.x, viewHeight), 0, 512) * Matrix.scaling(1, -1, -1);
			cfg_.cameraViewMatrix.translate(Vec3F(-cfg_.cameraPos.xy, -Chunk.height) - cfg_.coordinatesOffset.to!Vec3F);

			// Visualize the camera view frustum
			const Matrix tmat = cfg_.cameraViewMatrix * cfg_.invertedCameraViewMatrix;
			foreach (i; 0 .. 4) {
				const Vec3F cameraSpacePt = Vec3F(i & 1, (i >> 1) & 1, 0) * Vec3F(2, 2, 1) - 1;
				glDebugRenderer.drawLine(tmat * cameraSpacePt, tmat * Vec3F(cameraSpacePt.xy, 1));
			}
			glDebugRenderer.drawLine(tmat * Vec3F(0, 0, 0), tmat * Vec3F(0, 0, 1));
			cfg_.invertedCameraViewMatrix = cfg_.cameraViewMatrix.inverted();
		}

		// Calculate shadow map view matrix
		if (graphicSettings.shadowMapping != GraphicSettings.ShadowMapping.off) {
			const Matrix shadowMapOrthoMat = Matrix.orthogonalCentered(Vec2F(1, 1), 0, shadowMapViewFar);

			Matrix shadowMapMainMat = Matrix.scaling(1, -1, -1); // Z downwards
			shadowMapMainMat.translateZ(-shadowMapViewHeight);
			shadowMapMainMat *= Matrix.rotationYSin(cfg_.lightSettings.daylightDirection.x) * Matrix.rotationXSin(cfg_.lightSettings.daylightDirection.y);
			shadowMapMainMat.translate(-(cfg_.cameraPos + cfg_.coordinatesOffset.to!Vec3F));

			cfg_.shadowRenderMatrix = shadowMapOrthoMat * shadowMapMainMat;

			// We transform the shadow map view matrix so it covers exactly only the 8 points of the camera view frustum (arbitrary value instead of the inifinite far plane though)
			Vec3F minV = Vec3F(1000, 1000, 1000), maxV = Vec3F(-1000, -1000, -1000);
			foreach (i; 0 .. 8) {
				enum shadowMapDepth = 32;
				const Vec3F cameraSpacePt = Vec3F(i & 1, (i >> 1) & 1, (i >> 2) & 1) * Vec3F(2, 2, /*Le magic constant*/ 1.99) - 1;
				const Vec3F worldSpacePt = (cfg_.invertedCameraFrustumMatrix * cameraSpacePt).perspectiveNormalized;
				const Vec3F shadowSpacePt = (cfg_.shadowRenderMatrix * worldSpacePt).xyz; // No need to perspective normalization - ortho projection

				minV = minV.combine!"min(a,b)"(shadowSpacePt);
				maxV = maxV.combine!"max(a,b)"(shadowSpacePt);

				if (topDownView)
					glDebugRenderer.drawPoint(cfg_.cameraViewMatrix * worldSpacePt, 1);
			}

			Matrix optimizationMat = Matrix.translation(-1, -1) * Matrix.scaling(2 / (maxV.x - minV.x), 2 / (maxV.y - minV.y)).translated(Vec2F(-minV.x, -minV.y));

			cfg_.shadowRenderMatrix = optimizationMat * cfg_.shadowRenderMatrix;

			// We translate the sampling matrix so that the shadow mapping comparison has a slight bias (so that the shadows are not displayed in the inner corners)
			cfg_.shadowSamplingMatrix = Matrix.scaling(0.5, 0.5, 0.5).translated(Vec3F(1, 1, 1)) * optimizationMat * shadowMapOrthoMat * Matrix.translation(Vec3F(0, 0, -0.03)) * shadowMapMainMat;

			if (topDownView) {
				auto mat = cfg_.cameraViewMatrix * cfg_.shadowRenderMatrix.inverted();
				const float depth = (cfg_.shadowRenderMatrix * (cfg_.cameraPos + cfg_.coordinatesOffset.to!Vec3F)).z;

				glDebugRenderer.drawQuad( //
						mat * Vec3F(-1, -1, depth), mat * Vec3F(-1, 1, depth), //
						mat * Vec3F(1, 1, depth), mat * Vec3F(1, -1, depth), //
						1);
			}
		}
	}

	void prepareBuildPreview() {
		if (buildPreviewBlock) {
			Vec2F windowSizeF = cfg_.windowSize.to!Vec2F;

			buildPreviewBlock.buildPreviewRender(buildPreviewRenderer_);
			buildPreviewBuffers_.upload(buildPreviewRenderer_.buffersBuilder, true);

			enum blockPreviewSize = 64;
			cfg_.buildPreviewMatrix = Matrix.orthogonal(windowSizeF).translated(Vec2F(blockPreviewSize, windowSizeF.y - blockPreviewSize)) * Matrix.scaling(blockPreviewSize, blockPreviewSize, 1);
			cfg_.buildPreviewMatrix.translate(Vec3F(0, 0, 5));
			cfg_.buildPreviewMatrix *= Matrix.rotationX(0.6 * PI);
			cfg_.buildPreviewMatrix *= Matrix.rotationZ(appTime * 2 * PI * 0.1);
			cfg_.buildPreviewMatrix.translate(Vec3F(-0.5, -0.5, -0.5));
		}
	}

	void renderWorld(const ref Matrix viewMatrix, size_t matrixIx, BlockFaceRenderingContext.ContextType ctxType, bool transparentContexts, string perfGuardName, bool renderBuildPreview) {
		version (perfWatch) {
			glFinish();
			scope (exit)
				glFinish();
			auto _pgd = perfGuard(perfGuardName);
		}

		const ulong contextFields = resources.transparencyContextsBitfield ^ (transparentContexts ? 0 : ((ulong(1) << resources.blockFaceRenderingContextCount) - 1));
		const bool buildPreview = renderBuildPreview && buildPreviewBlock;

		foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount) {
			glState.boundVAO = resources.chunkRenderBufferVAOs[buffersIx];

			ulong cfs = contextFields;
			while (cfs) {
				auto contextId = bsf(cfs);
				cfs ^= 1 << contextId;

				FrustumManager.RenderList* renderList = frustumManager_.renderList(matrixIx, contextId, buffersIx);
				if (renderList.isEmpty && (!buildPreview || buildPreviewBuffers_.isEmpty(contextId, buffersIx)))
					continue;

				version (perfWatch) {
					glFinish();
					scope (exit)
						glFinish();
					auto _pgd2 = perfGuard("%s_%s".format(contextId, perfGuardName));
				}

				auto bfctx = resources.blockFaceRenderingContext(contextId);
				auto glctx = bfctx.context(ctxType);

				glctx.bind(false);

				auto loc = glctx.program.uniformLocation("coordinatesOffset", false);
				if (loc != -1)
					glUniform3f(loc, cfg_.coordinatesOffset.x, cfg_.coordinatesOffset.y, cfg_.coordinatesOffset.z);

				glUniform1f(1, animTime_);
				glUniformMatrix4fv(0, 1, GL_FALSE, viewMatrix.m.ptr);

				if (!renderList.isEmpty) {
					glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, renderList.offsetsBuffer);
					glMultiDrawArrays(GL_TRIANGLES, &renderList.firsts[0], &renderList.counts[0], cast(GLsizei) renderList.firsts.length);
					drawnTriangleCount += renderList.triangleCount;
				}

				if (buildPreview && graphicSettings.gui != GraphicSettings.GUI.none && !buildPreviewBuffers_.isEmpty(contextId, buffersIx)) {
					auto buf = buildPreviewBuffers_[contextId, buffersIx];
					if (loc != -1)
						glUniform3f(loc, 0, 0, 0);

					glUniformMatrix4fv(0, 1, GL_FALSE, cfg_.buildPreviewMatrix.m.ptr);
					glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, resources.buildPreview_offsetsBuffer);
					glDrawArrays(GL_TRIANGLES, buf.offset, buf.size - 2); // 2 extra triangles are created because of the normal striding
					drawnTriangleCount += (buf.size - 2) / 3;
				}
			}
		}

		glState.activeProgram = 0;
	}

	void doMousePicking() {
		const Vec2F screenSpacePos = (application.mousePos.to!Vec2F / application.windowSize.to!Vec2F * 2 - 1) * Vec2F(1, -1);
		const Vec3F p1 = (cfg_.invertedCameraViewMatrix * Vec3F(screenSpacePos, -1)).perspectiveNormalized;
		const Vec3F p2 = (cfg_.invertedCameraViewMatrix * Vec3F(screenSpacePos, 1)).perspectiveNormalized;

		World.RayCastResult result = cfg_.world.castRay(p1 - cfg_.coordinatesOffset.to!Vec3F, p2 - p1);
		mousePosInWorldIsValid = result.isHit;
		if (!result)
			return;

		static immutable Vec3F[4][6] rectCoords = [ //
		[Vec3F(0, 0, 0), Vec3F(0, 1, 0), Vec3F(0, 1, 1), Vec3F(0, 0, 1)], //
			[Vec3F(1, 0, 0), Vec3F(1, 1, 0), Vec3F(1, 1, 1), Vec3F(1, 0, 1)], //
			[Vec3F(0, 0, 0), Vec3F(1, 0, 0), Vec3F(1, 0, 1), Vec3F(0, 0, 1)], //
			[Vec3F(0, 1, 0), Vec3F(1, 1, 0), Vec3F(1, 1, 1), Vec3F(0, 1, 1)], //
			[Vec3F(0, 0, 0), Vec3F(1, 0, 0), Vec3F(1, 1, 0), Vec3F(0, 1, 0)], //
			[Vec3F(0, 0, 1), Vec3F(1, 0, 1), Vec3F(1, 1, 1), Vec3F(0, 1, 1)], //
			];

		mousePosInWorld = result.pos;
		mouseBuildPosInWorld = result.pos + Block.faceDirVec[result.face];

		const Vec3F mp = (result.pos + cfg_.coordinatesOffset).to!Vec3F;

		// Draw a quad visualising which block and which face the mouse is pointing at
		if (graphicSettings.gui != GraphicSettings.GUI.none)
			glDebugRenderer.drawQuad(cfg_.cameraViewMatrix, mp + rectCoords[result.face][0], mp + rectCoords[result.face][1], mp + rectCoords[result.face][2], mp + rectCoords[result.face][3]);
	}

private:
	string[string] contextDefines() {
		return [ //
		"MSAA_SAMPLES" : graphicSettings.antiAliasing.to!string, //
			"CAMERA_VIEW_NEAR" : GameRenderer.cameraViewNear.to!string, //
			"CAMERA_VIEW_FAR" : GameRenderer.cameraViewFar.to!string, //
			];
	}

public:
	Block buildPreviewBlock;
	bool topDownView;
	size_t drawnTriangleCount;

public:
	private static struct GLJobRec {

	public:
		alias OnFinished = void delegate(size_t, size_t);
		alias OnReleaseResources = void function(size_t);

	public:
		OnFinished onFinished;
		OnReleaseResources onReleaseResources;
		size_t eventId;
		size_t resourcesId;
		GLsync sync;
		string guardName;

	}

	// Priority and non priority
	private RingBuffer!(GLJobRec, 16)[2] glJobs_;

	pragma(inline) bool isGLJobQueueFull(bool isPriority) {
		return glJobs_[isPriority ? 0 : 1].isFull;
	}

	// Inserts a glFenceSync and calls onFinished after the sync is triggered (also calls onReleaseResources)
	void addGlJob(string guardName, GLJobRec.OnFinished onFinished, size_t eventId, GLJobRec.OnReleaseResources onReleaseResources, size_t resourcesId, bool isPriority) {
		assert(!isGLJobQueueFull(isPriority));

		GLJobRec rec;
		rec.sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
		rec.guardName = guardName;

		rec.onFinished = onFinished;
		rec.eventId = eventId;

		rec.onReleaseResources = onReleaseResources;
		rec.resourcesId = resourcesId;

		glJobs_[isPriority ? 0 : 1].insertBack(rec);
		glFlush(); // To make sure that the fence gets to the queue
	}

	void processGLJobs() {
		foreach (ref jobs; glJobs_) {
			while (!jobs.isEmpty) {
				if (glClientWaitSync(jobs.front.sync, 0, 0) == GL_TIMEOUT_EXPIRED)
					break;

				auto _ftgd = application.freeTimeGuard(jobs.front.guardName);
				if (!_ftgd)
					break;

				GLJobRec rec = jobs.takeFront();
				rec.onFinished(rec.eventId, rec.resourcesId);
				rec.onReleaseResources(rec.resourcesId);
				glDeleteSync(rec.sync);
			}
		}
	}

private:
	RenderConfig cfg_;
	float animTime_ = 0; ///< Time used for block animations
	GLsync sync_;

public:
	WorldVec mousePosInWorld, mouseBuildPosInWorld;
	bool mousePosInWorldIsValid;
	bool visualiseLoadedChunks = false;

private:
	FrustumManager frustumManager_;
	PostprocessingManager postprocessingManager_;

private:
	ChunkRenderBuffers buildPreviewBuffers_;
	StandardBlockRenderer buildPreviewRenderer_;

}
