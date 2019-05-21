module ac.client.block.blockface;

import derelict.sfml2;
import std.format;
import std.string;
import std.algorithm;
import std.conv;

import ac.client.block.blockfaceatlas;
import ac.client.block.blockfacerenderingcontext;
import ac.common.math.vector;
import ac.common.block.block;
import ac.client.resources;
import ac.client.gl.gltexture;

final class BlockFace {

public:
	alias UVIData = Vector!(ubyte, 6);

public:
	this(string basename, BlockFaceSettings settings = BlockFaceSettings()) {
		sfImage* img = sfImage_createFromFile("../res/block/%s.png".format(basename).toStringz);
		scope (exit)
			sfImage_destroy(img);

		settings.resolution = sfImage_getSize(img).x;

		context_ = resources.blockFaceRenderingContext(settings);
		contextId_ = context_.id;

		id_ = context_.atlas.addItem(img, settings.wrap);
		uvIData_ = UVIData((id_ & 0xff).to!ubyte, ((id_ >> 8) & 0xff).to!ubyte, 0, (id_ & 0xff).to!ubyte, ((id_ >> 8) & 0xff).to!ubyte, 0);

		isUniformFace_ = settings.isUniformFace;
	}

public:
	pragma(inline) UVIData uvIData() {
		return uvIData_;
	}

	pragma(inline) size_t contextId() {
		return contextId_;
	}

	pragma(inline) bool isUniformFace() {
		import ac.client.graphicsettings;

		return isUniformFace_ || !graphicSettings.waving;
	}

	BlockFaceSettings settings() {
		return context_.settings;
	}

private:
	BlockFaceRenderingContext context_;
	size_t contextId_;
	uint id_;
	UVIData uvIData_;
	bool isUniformFace_;

}

struct BlockFaceSettings {

public:
	alias RenderProperties = Block.RenderProperties;
	alias RenderProperty = Block.RenderProperty;

public:
	enum Waving : ubyte {
		none,
		windTop,
		windWhole,
		liquidSurface,
		liquidTop
	}

	enum AlphaChannel : ubyte {
		unused,
		alphaTest,
		transparency,
		glow
	}

public:
	int resolution;
	bool cullFace = true;
	bool wrap = true;
	bool betterTexturing = false;
	bool nonUniform = false;

public:
	Waving waving;
	AlphaChannel alphaChannel;

public:
	static BlockFaceSettings assemble(string[] fields, Args...)(auto ref Args args) {
		BlockFaceSettings result;

		static foreach (i, field; fields)
			__traits(getMember, result, field) = args[i];

		return result;
	}

public:
	bool isUniformFace() {
		return !nonUniform && wrap; // Non-uniform faces cannot be aggregated
	}

	bool isFullFace() {
		return (waving == Waving.none) && alphaChannel.among(AlphaChannel.unused, AlphaChannel.glow);
	}

	bool isTransparentFace() {
		return (waving == Waving.none) && alphaChannel.among(AlphaChannel.transparency, AlphaChannel.alphaTest) > 0;
	}

	RenderProperties renderProperties(Block.FaceFlags faces) {
		RenderProperties result;
		result |= ((faces << RenderProperty.fullFacesOffset) * (isFullFace || isTransparentFace)).to!RenderProperties;
		result |= (RenderProperty.transparentFaces * isTransparentFace).to!RenderProperties;
		result |= (RenderProperty.nonUniform * (waving != Waving.none)).to!RenderProperties;
		return result;
	}

}
