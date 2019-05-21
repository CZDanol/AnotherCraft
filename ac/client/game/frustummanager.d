module ac.client.game.frustummanager;

import core.bitop;
import bindbc.opengl;
import std.container.array;
import std.conv;
import std.format;
import std.string;

import ac.client.game.gamerenderer;
import ac.client.gl.glbindingsvao;
import ac.client.gl.glprogram;
import ac.client.gl.glprogramcontext;
import ac.client.gl.glresourcemanager;
import ac.client.gl.glstate;
import ac.client.resources;
import ac.client.world.chunkrenderbuffers;
import ac.client.world.chunkrenderer;
import ac.client.world.chunkrenderregion;
import ac.common.math.matrix;
import ac.common.math.vector;
import ac.common.util.perfwatch;
import ac.common.world.chunk;
import ac.common.world.world;

/// This class handles calculating which chunks are in frustum and which are not
/// Also it prepares render records for further rendering
final class FrustumManager {

public:
	enum matrixCount = 2;

public:
	this() {
		cullingContext_ = new GLProgramContext(new GLProgram("frustumCulling", [GLProgramShader.compute], [ //
				"CHUNK_WIDTH" : Chunk.width.to!string, //
				"CHUNK_HEIGHT" : Chunk.height.to!string, //
				"REGION_HEIGHT" : ChunkRenderRegion.height.to!string, //
				"MATRIX_COUNT" : matrixCount.to!string //
				]));

		{
			enum cullingResultsBufferSize = CullingResult.sizeof * GameRenderer.maxViewAreaWidthInChunks * GameRenderer.maxViewAreaWidthInChunks;
			cullingsResultsBuffer_ = glResourceManager.create(GLResourceType.buffer);
			glNamedBufferStorage(cullingsResultsBuffer_, cullingResultsBufferSize, null, GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT);
			cullingResults_ = cast(CullingResult*) glMapNamedBufferRange(cullingsResultsBuffer_, 0, cullingResultsBufferSize, GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT);
			assert(cullingResults_);

			string label = "cullingResultsBuffer";
			glObjectLabel(GL_BUFFER, cullingsResultsBuffer_, cast(GLint) label.length, label.toStringz);

			calculatedVRAMUsage += cullingResultsBufferSize;
		}

		{
			cullingResultsCounter_ = glResourceManager.create(GLResourceType.buffer);
			GLuint counterVal = 0;
			glNamedBufferStorage(cullingResultsCounter_, GLuint.sizeof, &counterVal, GL_MAP_READ_BIT | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);
			cullingResultsCount_ = cast(GLuint*) glMapNamedBufferRange(cullingResultsCounter_, 0, GLuint.sizeof, GL_MAP_READ_BIT | GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT);
			assert(cullingResultsCount_);

			string label = "cullingResultsCounter";
			glObjectLabel(GL_BUFFER, cullingResultsCounter_, cast(GLint) label.length, label.toStringz);
		}

		renderLists_.length = resources.blockFaceRenderingContextCount;

		foreach (ref arr; renderLists_) {
			foreach (ref arr2; arr) {
				foreach (ref it; arr2)
					it.initialize();
			}
		}
	}

	~this() {
		glUnmapNamedBuffer(cullingsResultsBuffer_);
	}

	void issueGPUComputation(World world, Vec3F cameraPos, int viewDistance, WorldVec coordinatesOffset, const ref Matrix[matrixCount] matrices) {
		matrices_[0] = matrices[0];

		static struct FrustumCullingData {
			Matrix[matrixCount] matrices;
			align(16) WorldVec firstChunkPos, lastChunkPos;
		}

		coordinatesOffset_ = coordinatesOffset;

		FrustumCullingData uniformData;
		uniformData.matrices = matrices;
		uniformData.firstChunkPos = -WorldVec(viewDistance, viewDistance, 0) * Chunk.width;
		uniformData.lastChunkPos = uniformData.firstChunkPos + WorldVec(viewDistance * 2 + 1, viewDistance * 2 + 1, 0) * Chunk.width;

		cullingContext_.setUniformBlock("uniformData", uniformData);

		enum workgroupSize = 16;
		const uint workgroupCount = (viewDistance * 2 + 1 + workgroupSize - 1) / workgroupSize;

		cullingContext_.bind();
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, cullingsResultsBuffer_);
		glBindBufferBase(GL_ATOMIC_COUNTER_BUFFER, 0, cullingResultsCounter_);
		glDispatchCompute(workgroupCount, workgroupCount, 1);

		foreach (ref arr; renderLists_) {
			foreach (ref arr2; arr) {
				foreach (ref it; arr2)
					it.clear();
			}
		}
	}

	/// issueProcessing has to be called before and GL_SHADER_STORAGE_BARRIER_BIT | GL_ATOMIC_COUNTER_BARRIER_BIT | GL_CLIENT_MAPPED_BUFFER_BARRIER_BIT must be synced
	void processGPUComputation(World world) {
		auto _pgd = perfGuard("frustumProcess");

		GLuint recordCount = *cullingResultsCount_;
		*cullingResultsCount_ = 0;

		foreach (i; 0 .. recordCount) {
			CullingResult rec = cullingResults_[i];
			Chunk ch = world.maybeChunkAt(rec.chunkPos - coordinatesOffset_);

			if (!ch || !ch.isVisible)
				continue;

			ChunkRenderer rr = ch.renderer;
			if (!rr.isRenderReady)
				continue;

			foreach (matIx; 0 .. matrixCount) {
				uint flags = rec.regionBits[matIx];
				while (flags) {
					const uint regionIx = bsf(flags);
					flags ^= 1 << regionIx;
					ChunkRenderRegion region = rr.region(regionIx);
					WorldVec offset = rec.chunkPos + WorldVec(0, 0, region.zStart);

					pragma(inline) static void iterFunc(size_t contextId, size_t buffersIx, ChunkRenderSubBufferT buf, FrustumManager mgr, WorldVec offset, size_t matIx) {
						mgr.renderLists_[contextId][matIx][buffersIx].add(buf, offset);
					}

					region.staticDrawBuffers.iterateBuffers!iterFunc(this, offset, matIx);
				}
			}
		}

		foreach (ref arr; renderLists_) {
			foreach (ref arr2; arr) {
				foreach (ref it; arr2)
					it.upload();
			}
		}
	}

public:
	RenderList* renderList(size_t matrixIx, size_t contextId, size_t buffersIx) {
		return &(renderLists_[contextId][matrixIx][buffersIx]);
	}

public:
	static struct RenderList {

	public:
		Array!GLint firsts;
		Array!GLsizei counts;

	public:
		Array!Vec4F offsets;
		GLuint offsetsBuffer;
		size_t triangleCount;

	public:
		void initialize() {
			offsetsBuffer = glResourceManager.create(GLResourceType.buffer);
		}

		void upload() {
			if (offsets.length)
				glNamedBufferData(offsetsBuffer, offsets.length * Vec4F.sizeof, &offsets[0], GL_DYNAMIC_DRAW);
		}

		void add(ChunkRenderSubBufferT buf, WorldVec offset) {
			assert(buf.size > 2);

			firsts ~= buf.offset;
			counts ~= buf.size - 2; // Because of the normal striding
			offsets ~= Vec4F(offset.to!Vec3F, 0);

			triangleCount += cast(size_t)((buf.size - 2) / 3);
		}

		void clear() {
			firsts.length = 0;
			counts.length = 0;
			offsets.length = 0;

			triangleCount = 0;
		}

		pragma(inline) bool isEmpty() {
			return firsts.length == 0;
		}
	}

private:
	RenderList[chunkRenderBufferAtlasCount][matrixCount][] renderLists_;

private:
	static struct CullingResult {
		align(16) WorldVec chunkPos;
		align(4) GLuint[matrixCount] regionBits;
	}

	CullingResult* cullingResults_;
	GLuint* cullingResultsCount_;

	GLProgramContext cullingContext_;
	GLuint cullingsResultsBuffer_;
	GLuint cullingResultsCounter_;

	Matrix[matrixCount] matrices_;
	WorldVec coordinatesOffset_;

}
