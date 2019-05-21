module ac.client.game.postprocessingmanager;

import bindbc.opengl;
import std.conv;
import std.format;
import std.algorithm;

import ac.client.game.gamerenderer;
import ac.client.gl;
import ac.client.graphicsettings;
import ac.client.world.worldresources;
import ac.common.math.matrix;
import ac.common.math.vector;
import ac.common.util.aa;
import ac.common.util.perfwatch;
import ac.common.world.world;

final class PostprocessingManager {

public:
	enum maxBlendLayerCount = 3;
	enum colorPassCount = 1 + maxBlendLayerCount;
	enum shadowPassCount = 1;

	enum shaders2DWorkgroupSize = 8;
	enum blurShaders2DWorkgroupSize = 8;

public:
	this(GameRenderer gameRenderer) {
		gameRenderer_ = gameRenderer;

		foreach (i, ref pass; colorPasses_)
			pass = new ColorPass(i);

		foreach (i, ref pass; shadowPasses_)
			pass = new ShadowPass(i);

		dataSourcePass = colorPasses_[graphicSettings.blendLayerCount > 0 ? 1 : 0];

		ssaoBlur1Program_ = new GLProgram("postprocessing/blur", [GLProgramShader.compute], [ //
				"BLUR_DIRECTION" : "DIR_HORIZONTAL", //
				"BLUR_KERNEL" : "KERNEL_4G3", //
				"BLUR_COMPONENTS" : "1", //
				"WORKGROUP_SIZE" : blurShaders2DWorkgroupSize.to!string, //
				/*"BILATERAL" : "1", //
				"BILATERAL_COEF" : "10", //
				"BILATERAL_LAYOUT" : "r32f", //*/
				]);
		ssaoBlur2Program_ = new GLProgram("postprocessing/blur", [GLProgramShader.compute], [ //
				"BLUR_DIRECTION" : "DIR_VERTICAL", //
				"BLUR_KERNEL" : "KERNEL_4G3", //
				"BLUR_COMPONENTS" : "1", //
				"WORKGROUP_SIZE" : blurShaders2DWorkgroupSize.to!string, //
				/*"BILATERAL" : "1", //
				"BILATERAL_COEF" : "10", //
				"BILATERAL_LAYOUT" : "r32f", //*/
				]);

		dofBlur1Program_ = new GLProgram("postprocessing/blur", [GLProgramShader.compute], [ //
				"BLUR_DIRECTION" : "DIR_HORIZONTAL", //
				"BLUR_KERNEL" : "KERNEL_4G2", //
				"BLUR_COMPONENTS" : "4", //
				"ALPHA_PREMULTIPLY" : "1", //
				"WORKGROUP_SIZE" : blurShaders2DWorkgroupSize.to!string, //
				"BILATERAL" : "1", //
				"BILATERAL_COEF" : "100", //
				"BILATERAL_LAYOUT" : "r32f", //
				"BILATERAL_LEVEL" : "0", //
				]);
		dofBlur2Program_ = new GLProgram("postprocessing/blur", [GLProgramShader.compute], [ //
				"BLUR_DIRECTION" : "DIR_VERTICAL", //
				"BLUR_KERNEL" : "KERNEL_4G2", //
				"BLUR_COMPONENTS" : "4", //
				"ALPHA_PREMULTIPLY" : "1", //
				"WORKGROUP_SIZE" : blurShaders2DWorkgroupSize.to!string, //
				"BILATERAL" : "1", //
				"BILATERAL_COEF" : "100", //
				"BILATERAL_LAYOUT" : "r32f", //
				"BILATERAL_LEVEL" : "0", //
				]);

		auto defines = contextDefines;

		globalPass1Context_ = new GLProgramContext(new GLProgram("postprocessing/globalPass1", [GLProgramShader.compute], [ //
				"MAX_BLEND_LAYER_COUNT" : maxBlendLayerCount.to!string, //
				"WORKGROUP_SIZE" : shaders2DWorkgroupSize.to!string, //
				].merge(defines)));

		globalPass2Context_ = new GLProgramContext(new GLProgram("postprocessing/globalPass2", [GLProgramShader.compute], [ //
				"WORKGROUP_SIZE" : shaders2DWorkgroupSize.to!string, //
				].merge(defines)));

		resultTex = new GLScreenTexture(GL_RGBA8);

		ssaoTex = new GLScreenTexture(GL_R8);
		ssaoBlurSuppTex = new GLScreenTexture(GL_R8);

		dofTex = new GLScreenTexture(GL_RGBA8);
		dofSuppTex = new GLScreenTexture(GL_RGBA8);

		dataDepthTex = new GLScreenTexture(GL_R32F, false, 3);
		/*dataDepthTex.onSetup = { //
			glTextureParameteri(dataDepthTex.textureId, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
		};*/

		dataNormalTex = new GLScreenTexture(GL_RGBA8);

		godRaysTex = new GLScreenTexture(GL_R8);
		godRaysTex.onSetup = { //
			glTextureParameteri(godRaysTex.textureId, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		};

		setup();

		graphicSettings[this] = (GraphicSettings.Changes changes) { //
			dataSourcePass = colorPasses_[graphicSettings.blendLayerCount > 0 ? 1 : 0];

			auto defines = contextDefines;
			globalPass1Context_.program.define(defines);
			globalPass2Context_.program.define(defines);

			setup();
		};
	}

	void process(ref GameRenderer.RenderConfig cfg) {
		version (perfWatch) {
			glFinish();
			scope (exit)
				glFinish();
			auto _pgd2 = perfGuard("postProcessing");
		}

		const Vec2I workGroupCount = (cfg.windowSize + shaders2DWorkgroupSize - 1) / shaders2DWorkgroupSize;
		const Vec2I blurWorkGroupCount = (cfg.windowSize + blurShaders2DWorkgroupSize - 1) / blurShaders2DWorkgroupSize;

		// Local pass 1 : shading + SSAO output
		{
			static struct UniformData_Pass1 {

			public:
				GLuint64[WorldResources.VisibleArea.areasArrayWidth * WorldResources.VisibleArea.areasArrayWidth] lightMaps;
				align(16) Vec2I mapsOrigin;

			public:
				align(16) Vec3F cameraPos;
				align(16) Matrix viewMatrix, invertedViewMatrix, shadowSamplingMatrix;

			public:
				align(16) Vec3F daylightDirection, directionalDaylightColor, ambientDaylightColor, ambientLightColor;

			public:
				// Artificial light effect is reduced under sunlight
				float artificialLightEffectReduction;

			}

			UniformData_Pass1 uniformData;
			uniformData.mapsOrigin = cfg.cameraPos.xy.to!Vec2I - GameRenderer.maxViewDistanceInBlocks;
			uniformData.mapsOrigin -= (uniformData.mapsOrigin.to!Vec2U % WorldResources.VisibleArea.areaSizeU.xy.to!Vec2U).to!Vec2I; // Round to the area grid

			uniformData.cameraPos = cfg.cameraPos + cfg.coordinatesOffset.to!Vec3F;
			uniformData.viewMatrix = cfg.cameraViewMatrix;
			uniformData.invertedViewMatrix = cfg.invertedCameraViewMatrix;
			uniformData.shadowSamplingMatrix = cfg.shadowSamplingMatrix;

			uniformData.daylightDirection = cfg.lightSettings.daylightDirection;
			uniformData.directionalDaylightColor = cfg.lightSettings.directionalDaylightColor;
			uniformData.ambientDaylightColor = cfg.lightSettings.ambientDaylightColor;
			uniformData.ambientLightColor = cfg.lightSettings.ambientLightColor;

			uniformData.artificialLightEffectReduction = cfg.lightSettings.artificialLightEffectReduction;

			WorldResources worldResources = cfg.world.resources;

			foreach (y; 0 .. WorldResources.VisibleArea.areasArrayWidth) {
				foreach (x; 0 .. WorldResources.VisibleArea.areasArrayWidth) {
					auto area = worldResources.maybeVisibleAreaFor(WorldVec( //
							uniformData.mapsOrigin.x + x * WorldResources.VisibleArea.areaWidth, //
							uniformData.mapsOrigin.y + y * WorldResources.VisibleArea.areaWidth, 0));

					uniformData.lightMaps[y * WorldResources.VisibleArea.areasArrayWidth + x] = area.lightMapHandle;
				}
			}
			uniformData.mapsOrigin += cfg.coordinatesOffset.xy.to!Vec2I;

			foreach (i; 0 .. graphicSettings.blendLayerCount + 1) {
				version (perfWatch) {
					glFinish();
					scope (exit)
						glFinish();
					auto _pgd = perfGuard("localPass%s".format(i));
				}

				auto pass = colorPasses_[i];

				pass.localPass1Context_.setUniformBlock(0, uniformData);
				pass.localPass1Context_.bind();

				// Bind color, normal and depth textures
				glBindTextures(0, 3 + (graphicSettings.shadowMapping != GraphicSettings.ShadowMapping.off ? shadowPassCount : 0), pass.bindTextureIds_.ptr);

				glBindImageTexture(0, pass.resultTex.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_RGBA8);

				if (pass is dataSourcePass) {
					glBindImageTexture(1, dataDepthTex.textureId, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R32F);
					glBindImageTexture(2, dataNormalTex.textureId, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA8);
				}

				glDispatchCompute(workGroupCount.x, workGroupCount.y, 1);
			}
		}

		if (usesMipmappedDepth_) {
			glGenerateTextureMipmap(dataDepthTex.textureId);
		}

		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_TEXTURE_FETCH_BARRIER_BIT);

		// Global pass 1 - combine blending layers, compute SSAO
		{
			version (perfWatch) {
				glFinish();
				scope (exit)
					glFinish();
				auto _pgd = perfGuard("globalPass1");
			}

			static struct UniformData_GlobalPass1 {

			public:
				Matrix viewMatrix, invertedViewMatrix;
				align(16) Vec3F cameraPos;

			public:
				align(16) Vec3F daylightDirection;
				align(16) Vec3F skyColor, sunColor, horizonHaloColor, sunHorizonHaloColor;

			public:
				align(4) float viewDistance;

			}

			UniformData_GlobalPass1 uniformData;
			uniformData.viewMatrix = cfg.cameraViewMatrix;
			uniformData.invertedViewMatrix = cfg.invertedCameraViewMatrix;
			uniformData.cameraPos = cfg.cameraPos + cfg.coordinatesOffset.to!Vec3F;

			uniformData.daylightDirection = cfg.lightSettings.daylightDirection.normalized;
			uniformData.skyColor = cfg.lightSettings.skyColor;
			uniformData.sunColor = cfg.lightSettings.sunColor;
			uniformData.horizonHaloColor = cfg.lightSettings.horizonHaloColor;
			uniformData.sunHorizonHaloColor = cfg.lightSettings.sunHorizonHaloColor;

			uniformData.viewDistance = graphicSettings.viewDistance;

			globalPass1Context_.setUniformBlock(0, uniformData);
			globalPass1Context_.bind();

			glBindImageTexture(0, colorPasses_[0].resultTex.textureId, 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA8);

			if (graphicSettings.ssao != GraphicSettings.SSAO.off)
				glBindImageTexture(1, ssaoTex.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_R8);

			if (graphicSettings.godRays)
				glBindImageTexture(2, godRaysTex.textureId, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_R8);

			glBindTextures(0, 2 + maxBlendLayerCount, globalPass1BindTextures_.ptr);

			glDispatchCompute(workGroupCount.x, workGroupCount.y, 1);
		}

		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_TEXTURE_FETCH_BARRIER_BIT);

		// SSAO blur (horizontal pass)
		if (graphicSettings.ssao == GraphicSettings.SSAO.blurred) {
			ssaoBlur1Program_.bind();
			ssaoTex.bind(0);
			dataDepthTex.bind(1);
			glBindImageTexture(0, ssaoBlurSuppTex.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_R8);

			glDispatchCompute(blurWorkGroupCount.x, blurWorkGroupCount.y, 1);
		}

		// DOF blur (horizontal pass)
		if (graphicSettings.depthOfField) {
			dofBlur1Program_.bind();
			colorPasses_[0].resultTex.bind(0);
			dataDepthTex.bind(1);
			glBindImageTexture(0, dofSuppTex.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_RGBA8);

			glDispatchCompute(blurWorkGroupCount.x, blurWorkGroupCount.y, 1);
		}

		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_TEXTURE_FETCH_BARRIER_BIT);

		// SSAO blur (vertical pass)
		if (graphicSettings.ssao == GraphicSettings.SSAO.blurred) {
			ssaoBlur2Program_.bind();
			ssaoBlurSuppTex.bind(0);
			glBindImageTexture(0, ssaoTex.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_R8);

			glDispatchCompute(blurWorkGroupCount.x, blurWorkGroupCount.y, 1);
		}

		// DOF blur (vertical pass)
		if (graphicSettings.depthOfField) {
			dofBlur2Program_.bind();
			dofSuppTex.bind(0);
			glBindImageTexture(0, dofTex.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_RGBA8);

			glDispatchCompute(blurWorkGroupCount.x, blurWorkGroupCount.y, 1);
		}

		glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_TEXTURE_FETCH_BARRIER_BIT);

		// Global pass 2 - apply DOF, sky, god rays, apply blurred SSAO
		{
			version (perfWatch) {
				glFinish();
				scope (exit)
					glFinish();
				auto _pgd = perfGuard("globalPass2");
			}

			static struct UniformData_GlobalPass2 {

			public:
				align(16) Matrix invertedViewMatrix;
				align(16) Vec3F cameraPos;
				align(4) float viewDistance;

			public:
				align(16) Vec3F daylightDirection;
				align(16) Vec3F skyColor, sunColor, horizonHaloColor, sunHorizonHaloColor;

				align(4) float sunSize, sunHaloPow;

				align(16) Vec3F sunPosPx;

			}

			UniformData_GlobalPass2 uniformData;
			uniformData.cameraPos = cfg.cameraPos + cfg.coordinatesOffset.to!Vec3F;
			uniformData.invertedViewMatrix = cfg.invertedCameraViewMatrix;
			uniformData.viewDistance = graphicSettings.viewDistance;

			uniformData.daylightDirection = cfg.lightSettings.daylightDirection.normalized;
			uniformData.skyColor = cfg.lightSettings.skyColor;
			uniformData.sunColor = cfg.lightSettings.sunColor;
			uniformData.horizonHaloColor = cfg.lightSettings.horizonHaloColor;
			uniformData.sunHorizonHaloColor = cfg.lightSettings.sunHorizonHaloColor;

			uniformData.sunSize = cfg.lightSettings.sunSize * GameRenderer.cameraViewFovy * cfg.windowSize.y;
			uniformData.sunHaloPow = cfg.lightSettings.sunHaloPow;

			Vec4F sunPosPxW = (cfg.cameraViewMatrix * (uniformData.cameraPos + cfg.lightSettings.daylightDirection));
			uniformData.sunPosPx = Vec3F((sunPosPxW.perspectiveNormalized.xy * 0.5 + 0.5) * cfg.windowSize.to!Vec2F, sunPosPxW.w);

			globalPass2Context_.setUniformBlock(0, uniformData);
			globalPass2Context_.bind();

			glBindImageTexture(0, resultTex.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_RGBA8);

			GLuint[5] bindTextures = [colorPasses_[0].resultTex.textureId, dataDepthTex.textureId, dofTex.textureId, godRaysTex.textureId, ssaoTex.textureId];
			glBindTextures(0, 5, bindTextures.ptr);

			glDispatchCompute(workGroupCount.x, workGroupCount.y, 1);
		}

		glMemoryBarrier(GL_TEXTURE_FETCH_BARRIER_BIT);
		gl2DDraw.draw(resultTex);
	}

public:
	ColorPass colorPass(size_t i) {
		return colorPasses_[i];
	}

	auto boundShadowFBO(size_t i) {
		return shadowPasses_[i].fbo.boundGuard;
	}

private:
	string[string] contextDefines() {
		return [ //
		"MSAA_SAMPLES" : graphicSettings.antiAliasing.to!string(), //
			"DEPTH_OF_FIELD" : graphicSettings.depthOfField.to!int().to!string, //
			"ATMOSPHERE" : graphicSettings.atmosphere.to!int().to!string, //
			"GOD_RAYS" : graphicSettings.godRays.to!int().to!string, //
			"AMBIENT_OCCLUSION" : graphicSettings.ssao.to!int().to!string, //
			"T_JUNCTION_HIDING" : graphicSettings.tJunctionHiding.to!int().to!string, //

			"CAMERA_VIEW_NEAR" : GameRenderer.cameraViewNear.to!string, //
			"CAMERA_VIEW_FAR" : GameRenderer.cameraViewFar.to!string, //

			"BLEND_LAYER_COUNT" : graphicSettings.blendLayerCount.to!string, //
			"SHOW_SINGLE_BLEND_LAYER" : graphicSettings.showSingleBlendLayer.to!string, //
			];
	}

	void setup() {
		usesMipmappedDepth_ = graphicSettings.depthOfField || graphicSettings.atmosphere || graphicSettings.ssao != GraphicSettings.SSAO.off;

		globalPass1BindTextures_[0] = dataNormalTex.textureId;
		globalPass1BindTextures_[1] = dataDepthTex.textureId;
		foreach (i; 1 .. maxBlendLayerCount + 1)
			globalPass1BindTextures_[i + 1] = colorPasses_[i].resultTex.textureId;

		foreach (ref pass; colorPasses_)
			pass.setup();

		foreach (ref pass; shadowPasses_)
			pass.setup();
	}

private:
	GameRenderer gameRenderer_;
	bool usesMipmappedDepth_;

private:
	GLScreenTexture dataDepthTex, dataNormalTex, godRaysTex, resultTex;
	GLScreenTexture ssaoTex, ssaoBlurSuppTex;
	GLScreenTexture dofTex, dofSuppTex;

private:
	GLProgram ssaoBlur1Program_, ssaoBlur2Program_;
	GLProgram dofBlur1Program_, dofBlur2Program_;
	GLProgramContext globalPass1Context_, globalPass2Context_;

private:
	GLuint[2 + maxBlendLayerCount] globalPass1BindTextures_;

public:
	class ColorPass {

	public:
		this(size_t index) {
			// Create FBOs and textures
			{
				fbo = new GLFramebuffer();

				colorTex = new GLScreenTexture(GL_RGBA8, true);
				depthTex = new GLScreenTexture(GL_DEPTH_COMPONENT32F, true);
				normalTex = new GLScreenTexture(GL_RGBA8, true);

				resultTex = new GLScreenTexture(GL_RGBA8);
			}

			with (fbo.boundGuard) {
				fbo.attach(GL_COLOR_ATTACHMENT0, colorTex);
				fbo.attach(GL_COLOR_ATTACHMENT1, normalTex);
				fbo.attach(GL_DEPTH_ATTACHMENT, depthTex);

				assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
			}

			// Create postprocessing pass programs
			{
				auto defines = contextDefines();

				localPass1Context_ = new GLProgramContext(new GLProgram("postprocessing/localPass1", [GLProgramShader.compute], [ //
						"AREAS_ARRAY_WIDTH" : WorldResources.VisibleArea.areasArrayWidth.to!string, //
						"AREA_WIDTH" : WorldResources.VisibleArea.areaWidth.to!string, //
						"AREA_HEIGHT" : WorldResources.VisibleArea.areaHeight.to!string, //
						"SHADOW_MAPPING_FAR" : GameRenderer.shadowMapViewFar.to!string, //
						"WORKGROUP_SIZE" : shaders2DWorkgroupSize.to!string, //
						].merge(defines)));
			}
		}

		void setup() {
			auto defines = contextDefines();

			localPass1Context_.program.define(defines);

			// Rebind because there could have been changes in resolution (and so the textures are recreated)
			bindTextureIds_[0] = colorTex.textureId;
			bindTextureIds_[1] = normalTex.textureId;
			bindTextureIds_[2] = depthTex.textureId;
		}

	private:
		string[string] contextDefines() {
			return [ //
			"MSAA_SAMPLES" : graphicSettings.antiAliasing.to!string, //
				"SURFACE_DATA" : graphicSettings.surfaceData.to!int().to!string, //
				"SHADING" : graphicSettings.shading.to!int().to!string, //
				"SHADOW_MAPPING" : graphicSettings.shadowMapping.to!int().to!string, //

				"CAMERA_VIEW_NEAR" : GameRenderer.cameraViewNear.to!string, // 
				"CAMERA_VIEW_FAR" : GameRenderer.cameraViewFar.to!string, //

				"DATA_EXPORT" : (this is dataSourcePass && usesMipmappedDepth_).to!int().to!string, //
				];
		}

	public:
		GLFramebuffer fbo;

		GLScreenTexture colorTex, depthTex, normalTex;
		GLScreenTexture resultTex;

	private:
		GLProgramContext localPass1Context_; ///< Shading, compute SSAO
		GLuint[3 + shadowPassCount] bindTextureIds_; ///< Used for glBindTextures

	private:
		size_t passIndex_;

	}

	class ShadowPass {

	public:
		GLFramebuffer fbo;
		GLTexture depthTex;

	public:
		this(size_t index) {
			fbo = new GLFramebuffer();
			depthTex = new GLTexture(GL_TEXTURE_2D);
			passIndex_ = index;

			setup();

			with (fbo.boundGuard) {
				fbo.attach(GL_DEPTH_ATTACHMENT, depthTex);

				assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
			}
		}

		void setup() {
			if (graphicSettings.shadowMapping == GraphicSettings.ShadowMapping.off)
				return;

			depthTex.recreate();

			int resolution = GraphicSettings.shadowMapResolution[graphicSettings.shadowMapping];
			glTextureStorage2D(depthTex.textureId, 1, GL_DEPTH_COMPONENT32F, resolution, resolution);

			glTextureParameteri(depthTex.textureId, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTextureParameteri(depthTex.textureId, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

			glTextureParameteri(depthTex.textureId, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTextureParameteri(depthTex.textureId, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

			glTextureParameteri(depthTex.textureId, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL);
			glTextureParameteri(depthTex.textureId, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);

			foreach (i; 0 .. colorPassCount)
				colorPasses_[i].bindTextureIds_[3 + passIndex_] = depthTex.textureId;
		}

	private:
		size_t passIndex_;

	}

private:
	/// Pass from which the depth data is taken for effect processing (like SSAO and DOF)
	ColorPass dataSourcePass;

	/// Frist pass is opaque, other passes are for depth peeling
	ColorPass[colorPassCount] colorPasses_;
	ShadowPass[shadowPassCount] shadowPasses_;

}
