module ac.client.block.blockfacerenderingcontext;

import bindbc.opengl;
import std.conv;
import std.algorithm;

import ac.client.block.blockface;
import ac.client.block.blockfaceatlas;
import ac.client.game.gamerenderer;
import ac.client.gl.glprogram;
import ac.client.gl.glprogramcontext;
import ac.client.graphicsettings;
import ac.client.resources;
import ac.common.block.block;
import ac.common.math.vector;
import ac.common.util.aa;
import ac.common.world.world;

final class BlockFaceRenderingContext {

public:
	enum ContextType : int {
		standard,
		depthOnly,
		nearDepthTest,
		_count
	}

public:
	this(size_t id, const ref BlockFaceSettings settings) {
		settings_ = settings;
		atlas_ = new BlockFaceAtlas( //
				settings.resolution, id, //
				!settings.alphaChannel.among(BlockFaceSettings.AlphaChannel.alphaTest, BlockFaceSettings.AlphaChannel.alphaTestGlow), //
				settings.alphaChannel.among(BlockFaceSettings.AlphaChannel.alphaTest, BlockFaceSettings.AlphaChannel.transparency, BlockFaceSettings.AlphaChannel.alphaTestGlow) > 0, //
				settings.wrap, //
				settings.betterTexturing //
				);

		id_ = id;

		pragma(inline) static string de(T)(T x) {
			return x.to!int().to!string();
		}

		string[string] defs = [ //
		"ALPHA_CHANNEL" : de(settings.alphaChannel), //
			"BACK_FACING_NORMAL" : de(settings.backFacingNormal), //
			"WRAP" : de(settings.wrap), //

			"CAMERA_VIEW_NEAR" : de(GameRenderer.cameraViewNear), //
			"CAMERA_VIEW_FAR" : de(GameRenderer.cameraViewFar), //
			"MSAA_SAMPLES" : de(graphicSettings.antiAliasing), //
			].merge(contextDefines);

		foreach (i; 0 .. cast(int) ContextType._count) {
			// Near depth test context is not utilited for non-transparency contexts
			if (i == ContextType.nearDepthTest && settings_.alphaChannel != BlockFaceSettings.AlphaChannel.transparency)
				continue;

			GLProgram program = new GLProgram("render/blockRender", [GLProgramShader.vertex, GLProgramShader.fragment], [ //
					"DEPTH_ONLY" : de(i == ContextType.depthOnly), //
					"NEAR_DEPTH_TEST" : de(i == ContextType.nearDepthTest), //
					].merge(defs));

			GLProgramContext context = new GLProgramContext(program);

			context_[i] = context;

			if (i != ContextType.depthOnly || settings_.alphaChannel.among(BlockFaceSettings.AlphaChannel.alphaTest, BlockFaceSettings.AlphaChannel.alphaTestGlow))
				context.bindTexture(1, atlas_.texture);

			context.enable(GL_DEPTH_TEST);
			context.disable(GL_BLEND);
			context.disable(GL_POLYGON_SMOOTH);
			context.setEnabled(GL_CULL_FACE, settings.cullFace && i != ContextType.depthOnly);
		}

		graphicSettings[this] = (GraphicSettings.Changes changes) { //
			if (settings_.alphaChannel == BlockFaceSettings.AlphaChannel.transparency && (changes & GraphicSettings.Change.antiAliasing))
				context_[ContextType.nearDepthTest].program.define("MSAA_SAMPLES", de(graphicSettings.antiAliasing));

			if (changes & (GraphicSettings.Change.betterTexturing | GraphicSettings.Change.msaaAlphaTest | GraphicSettings.Change.surfaceData | GraphicSettings.Change.waving)) {
				foreach (i; 0 .. cast(int) ContextType._count) {
					if (context_[i])
						context_[i].program.define(contextDefines);
				}
			}
		};
	}

	void upload() {
		atlas_.upload();
	}

public:
	pragma(inline) size_t id() {
		return id_;
	}

	pragma(inline) BlockFaceAtlas atlas() {
		return atlas_;
	}

	pragma(inline) GLProgramContext context(ContextType type) {
		return context_[type];
	}

	pragma(inline) ref const(BlockFaceSettings) settings() {
		return settings_;
	}

private:
	string[string] contextDefines() {
		pragma(inline) static string de(T)(T x) {
			return x.to!int().to!string();
		}

		return [ //
		"BETTER_TEXTURING" : de(graphicSettings.betterTexturing && settings_.betterTexturing), //
			"MSAA_ALPHA_TEST" : de(graphicSettings.msaaAlphaTest), //
			"SURFACE_DATA" : de(graphicSettings.surfaceData), //
			"WAVING" : de(graphicSettings.waving ? settings.waving : 0), //
			];
	}

private:
	size_t id_;
	BlockFaceAtlas atlas_;
	BlockFaceSettings settings_;

private:
	GLProgramContext[ContextType._count] context_;
	GLuint vao_;

}
