module ac.client.resources;

import bindbc.opengl;
import std.algorithm;
import std.container.array;
import std.conv;
import std.format;
import std.string;

import ac.client.block.blockface;
import ac.client.block.blockfacerenderingcontext;
import ac.client.gl.glprogram;
import ac.client.gl.glprogramcontext;
import ac.client.gl.glresourcemanager;
import ac.client.gl.glstate;
import ac.client.gl.gltexture;
import ac.client.gl.gltypes;
import ac.client.graphicsettings;
import ac.client.world.chunkrenderbuffers;
import ac.client.world.chunkrenderer;
import ac.client.world.chunkrenderregion;
import ac.client.world.worldresources;
import ac.common.block.block;
import ac.common.math.vector;
import ac.common.world.chunk;
import ac.common.util.log;

Resources resources;
size_t calculatedVRAMUsage;

final class Resources {

public:

public:
	this() {
		lighting_preparationProgram = new GLProgram("lighting/lightPreparation", [GLProgramShader.compute], [ //
				"CHUNK_HEIGHT" : Chunk.height.to!string, //
				"MAX_LIGHT_VALUE" : Block.maxLightValue.to!string, //
				"ACTIVE_AREA_WIDTH" : WorldResources.ActiveArea.areaWidth.to!string, //
				]);

		lighting_propagationProgram = new GLProgram("lighting/lightPropagation", [GLProgramShader.compute], [ //
				"CHUNK_HEIGHT" : Chunk.height.to!string, //
				"CHUNK_WIDTH" : Chunk.width.to!string, //
				"MAX_LIGHT_VALUE" : Block.maxLightValue.to!string, //
				"ACTIVE_AREA_WIDTH" : WorldResources.ActiveArea.areaWidth.to!string, //
				]);

		lighting_exportProgram = new GLProgram("lighting/lightExport", [GLProgramShader.compute], [ //
				"CHUNK_WIDTH" : Chunk.width.to!string //
				]);

		blockRenderList_program = new GLProgram("render/blockRenderList", [GLProgramShader.compute], [ //
				"ACTIVE_AREA_WIDTH" : WorldResources.ActiveArea.areaWidth.to!string, //
				"CHUNK_HEIGHT" : Chunk.height.to!string, //
				"AGGREGATION" : graphicSettings.aggregationStrategy.to!int().to!string, //
				]);

		graphicSettings[this] = (GraphicSettings.Changes changes) { //
			if (changes & GraphicSettings.Change.aggregationStrategy)
				blockRenderList_program.define("AGGREGATION", graphicSettings.aggregationStrategy.to!int().to!string);
		};

		static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount) {
			{
				alias T = ChunkRenderBufferAtlases[buffersIx];
				chunkRenderBufferAtlases[buffersIx] = new T(chunkRenderBufferAtlasBaseSizes[buffersIx]);

				chunkRenderBufferVAOs[buffersIx] = glResourceManager.create(GLResourceType.vao);
				chunkRenderBufferVAOs_init!buffersIx();

				string label = "buffersVAO_%s".format(buffersIx);
				glObjectLabel(GL_VERTEX_ARRAY, chunkRenderBufferVAOs[buffersIx], cast(GLint) label.length, label.toStringz);

				chunkRenderBufferAtlases[buffersIx].afterResizeEvent[cast(void*) this] = &chunkRenderBufferVAOs_init!buffersIx;
			}
		}

		{
			buildPreview_offsetsBuffer = glResourceManager.create(GLResourceType.buffer);
			GLfloat[4] data = 0;
			glNamedBufferStorage(buildPreview_offsetsBuffer, GLfloat.sizeof * 4, &data, 0);
		}

		{
			premultiplyAlpha_program = new GLProgram("util/premultiplyAlpha", [GLProgramShader.compute]);
		}
	}

public:
	void finish() {
		assert(!finished_);
		finished_ = true;

		foreach (ctx; contexts_)
			ctx.upload();
	}

public:
	BlockFaceRenderingContext blockFaceRenderingContext(BlockFaceSettings settings) {
		assert(!finished_);

		// Don't care
		settings.nonUniform = false;

		if (!settings.alphaChannel.among(BlockFaceSettings.AlphaChannel.alphaTest, BlockFaceSettings.AlphaChannel.alphaTestGlow, BlockFaceSettings.AlphaChannel.transparency))
			settings.backFacingNormal = BlockFaceSettings.BackFacingNormal.same;

		if (auto it = settings in contextsAssoc_)
			return *it;

		assert(contexts_.length < 64, "Does not fit to ulong -> core.bitop fail");

		BlockFaceRenderingContext ctx = new BlockFaceRenderingContext(contexts_.length, settings);
		const size_t ctxId = contexts_.length;

		contexts_ ~= ctx;
		contextsAssoc_[settings] = ctx;

		assert(contexts_.length <= ulong.sizeof * 64, "Contexts bitfield does not fit in the ulong bitfield");
		if (settings.alphaChannel == BlockFaceSettings.AlphaChannel.transparency)
			transparencyContextsBitfield_ |= 1 << ctxId;

		return ctx;
	}

	pragma(inline) BlockFaceRenderingContext blockFaceRenderingContext(size_t id) {
		return contexts_[id];
	}

	pragma(inline) size_t blockFaceRenderingContextCount() {
		debug assert(finished_);
		return contexts_.length;
	}

	pragma(inline) ulong transparencyContextsBitfield() {
		debug assert(finished_);
		return transparencyContextsBitfield_;
	}

public:
	ChunkRenderBufferAtlases chunkRenderBufferAtlases;
	GLuint[chunkRenderBufferAtlasCount] chunkRenderBufferVAOs;

	private void chunkRenderBufferVAOs_init(size_t buffersIx)() {
		enum BufferBinding : GLuint {
			pos,
			uvOffset,
			layerI1,
			layerI2,
			normalX,
			normalY,
			normalZ,
			_count
		}

		glState.boundVAO = chunkRenderBufferVAOs[buffersIx];

		foreach (i; 0 .. cast(int) BufferBinding._count)
			glEnableVertexAttribArray(i);

		glState.bindBuffer(GL_ARRAY_BUFFER, chunkRenderBufferAtlases[buffersIx].buffer(0));
		glVertexAttribPointer(BufferBinding.pos, 3, GLType!(chunkRenderBufferAtlases[buffersIx].ComponentTypes[0]), false, 0, cast(void*) 0);

		glState.bindBuffer(GL_ARRAY_BUFFER, chunkRenderBufferAtlases[buffersIx].buffer(1));
		glVertexAttribIPointer(BufferBinding.uvOffset, 1, GL_UNSIGNED_BYTE, 0, cast(void*) 0);

		glState.bindBuffer(GL_ARRAY_BUFFER, chunkRenderBufferAtlases[buffersIx].buffer(2));
		glVertexAttribIPointer(BufferBinding.layerI1, 1, GL_UNSIGNED_BYTE, 1, cast(void*) 0);
		glVertexAttribIPointer(BufferBinding.layerI2, 1, GL_UNSIGNED_BYTE, 1, cast(void*) 1);

		glState.bindBuffer(GL_ARRAY_BUFFER, chunkRenderBufferAtlases[buffersIx].buffer(3));
		glVertexAttribPointer(BufferBinding.normalX, 1, GL_UNSIGNED_BYTE, true, 1, cast(void*) 0);
		glVertexAttribPointer(BufferBinding.normalY, 1, GL_UNSIGNED_BYTE, true, 1, cast(void*) 1);
		glVertexAttribPointer(BufferBinding.normalZ, 1, GL_UNSIGNED_BYTE, true, 1, cast(void*) 2);
	}

public:
	static struct LightMapCalcResources {

	public:
		GLuint texture;
		size_t index;

	private:
		void initialize(size_t index) {
			this.index = index;

			texture = glResourceManager.create(GLResourceType.texture3D);
			glTextureStorage3D(texture, 1, GL_RGBA8, Chunk.width * 3, Chunk.width * 3, Chunk.height);

			calculatedVRAMUsage += 4 * Chunk.width * 3 * Chunk.width * 3 * Chunk.height;
		}

	}

	GLProgram lighting_preparationProgram, lighting_propagationProgram, lighting_exportProgram;
	ResourceManager!LightMapCalcResources lightMapCalcResources;

public:
	static struct BlockRenderListCalcResources {

	public:
		GLuint recordBuffer, counterBuffer;
		GLuint[4]* recordBufferData;
		GLuint* counterBufferData;
		size_t index;

	private:
		void initialize(size_t index) {
			this.index = index;

			enum recordBufferSize = GLuint.sizeof * 4 * ChunkRenderRegion.volume;
			recordBuffer = glResourceManager.create(GLResourceType.buffer);
			glNamedBufferStorage(recordBuffer, recordBufferSize, null, GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT);
			recordBufferData = cast(GLuint[4]*) glMapNamedBufferRange(recordBuffer, 0, recordBufferSize, GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT);
			assert(recordBufferData);

			counterBuffer = glResourceManager.create(GLResourceType.buffer);
			GLuint counterVal = 0;
			glNamedBufferStorage(counterBuffer, GLuint.sizeof, &counterVal, GL_MAP_READ_BIT | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);
			counterBufferData = cast(GLuint*) glMapNamedBufferRange(counterBuffer, 0, GLuint.sizeof, GL_MAP_READ_BIT | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);
			assert(counterBufferData);

			calculatedVRAMUsage += recordBufferSize;
		}

	}

	GLProgram blockRenderList_program;
	ResourceManager!BlockRenderListCalcResources blockRenderListCalcResources;

public:
	GLuint buildPreview_offsetsBuffer;

public:
	GLProgram premultiplyAlpha_program;
	enum premultiplyAlpha_workgroupSize = Vec2I(8, 8);

private:
	BlockFaceRenderingContext[BlockFaceSettings] contextsAssoc_;
	BlockFaceRenderingContext[] contexts_;
	ulong transparencyContextsBitfield_; /// Each bit corresponds to one context, bit is set if the context has transparency on

private:
	bool finished_;

private: /// Resource manager handles reusing GPU resources (like textures and buffers) for GPU async computations
	static struct ResourceManager(T) {

	public:
		T obtain() {
			if (!freeResList_.empty) {
				size_t ix = freeResList_.back;
				freeResList_.removeBack();
				return resList_[ix];
			}

			resList_ ~= T();
			resList_[$ - 1].initialize(resList_.length - 1);
			return resList_[$ - 1];
		}

		T get(size_t ix) {
			return resList_[ix];
		}

		void release(size_t i) {
			freeResList_ ~= i;
		}

	private:
		Array!T resList_;
		Array!size_t freeResList_;

	}

}
