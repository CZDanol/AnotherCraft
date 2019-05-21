module ac.client.world.chunkrenderbuffers;

import bindbc.opengl;
import core.bitop;
import std.algorithm;
import std.container.array;
import std.meta;
import std.typecons;

import ac.client.block.blockfacerenderingcontext;
import ac.client.gl.glbindingsvao;
import ac.client.gl.glbuffer;
import ac.client.gl.glprogram;
import ac.client.gl.glbufferatlas;
import ac.client.resources;
import ac.common.math.vector;

// Coords, uvOffset, uvBase, normal
enum chunkRenderBufferAtlasCount = 2;
alias ChunkRenderBufferAtlases = AliasSeq!(GLBufferAtlas!([3, 1, 1, 1], ubyte, ubyte, ubyte, ubyte), GLBufferAtlas!([3, 1, 1, 1], float, ubyte, ubyte, ubyte));
static immutable chunkRenderBufferAtlasBaseSizes = [64_000_000, 1_000_000];

alias ChunkRenderBufferBuildersT = staticMap!(ChunkRenderBufferBuilders_, ChunkRenderBufferAtlases);
alias ChunkRenderSubBufferT = GLBufferAtlasSubBuffer;

alias ChunkRenderBufferBuilders = Tuple!(ChunkRenderBufferBuildersT);

private template ChunkRenderBufferBuilders_(T) {
	alias ChunkRenderBufferBuilders_ = T.RegionBuilder;
}

struct ChunkRenderBuffers {

public:
	@disable this();
	this(int _) {
		buffers_.length = resources.blockFaceRenderingContextCount;
		assert(buffers_.length < 64); // It has to fit in the ulong bitfield
	}

public:
	void upload(ref ChunkRenderBuffersBuilder builder, bool doClear) {
		builder.finalize();

		nonemptyBuffers_[] = 0;

		static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount) {
			for (size_t i = 0; i < buffers_.length; i++) {
				auto bfs = &(buffers_[i][buffersIx]);
				resources.chunkRenderBufferAtlases[buffersIx].free(*bfs);

				if (builder[i][buffersIx].length > 2) {
					*bfs = resources.chunkRenderBufferAtlases[buffersIx].upload(builder[i][buffersIx]);
					nonemptyBuffers_[buffersIx] |= ulong(1) << i;
				}
				else {
					*bfs = GLBufferAtlasSubBuffer();
					builder[i][buffersIx].clear();
				}
			}
		}

		if (doClear)
			builder.clear();
	}

	void clear() {
		nonemptyBuffers_[] = 0;

		foreach (ref buf; buffers_) {
			static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount) {
				resources.chunkRenderBufferAtlases[buffersIx].free(buf[buffersIx]);
				buf[buffersIx] = GLBufferAtlasSubBuffer();
			}
		}
	}

	void iterateBuffers(alias f, Args...)(auto ref Args args) {
		static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount) {
			{
				ulong flags = nonemptyBuffers_[buffersIx];
				while (flags) {
					const size_t contextId = bsf(flags);
					flags ^= 1UL << contextId;

					GLBufferAtlasSubBuffer buf = buffers_[contextId][buffersIx];
					f(contextId, buffersIx, buf, args);
				}
			}
		}
	}

	pragma(inline) bool isEmpty(size_t contextId, size_t buffersIx) {
		return buffers_[contextId][buffersIx].size == 0;
	}

	pragma(inline) auto opIndex(size_t contextId, size_t buffersIx) {
		return buffers_[contextId][buffersIx];
	}

private:
	Array!(GLBufferAtlasSubBuffer[chunkRenderBufferAtlasCount]) buffers_;
	ulong[chunkRenderBufferAtlasCount] nonemptyBuffers_;

}

struct ChunkRenderBuffersBuilder {

public:
	@disable this();
	this(int _) {
		builders_.length = resources.blockFaceRenderingContextCount;

		foreach (ref b; builders_) {
			static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount)
				b[buffersIx] = ChunkRenderBufferBuilders[buffersIx].obtain();
		}

		initialize();
	}

	~this() {
		foreach (ref b; builders_) {
			static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount)
				b[buffersIx].release();
		}
	}

	void clear() {
		foreach (b; builders_) {
			static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount)
				b[buffersIx].clear();
		}

		initialize();
	}

	void initialize() {
		// Because of the striding
		foreach (b; builders_) {
			static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount) {
				b[buffersIx][2] ~= Vec2U8(0, 0);
				b[buffersIx][3] ~= Vec2U8(0, 0);
			}
		}
	}

	void finalize() {
		// Because of the striding
		foreach (b; builders_) {
			static foreach (buffersIx; 0 .. chunkRenderBufferAtlasCount) {
				b[buffersIx][0] ~= Vector!(ChunkRenderBufferAtlases[buffersIx].ComponentTypes[0], 6)(0);
				b[buffersIx][1] ~= Vector!(ubyte, 2)(0);
			}
		}
	}

public:
	pragma(inline) ChunkRenderBufferBuilders opIndex(size_t buffersIx) {
		return builders_[buffersIx];
	}

private:
	Array!ChunkRenderBufferBuilders builders_;

}
