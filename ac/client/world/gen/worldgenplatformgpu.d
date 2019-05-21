module ac.client.world.gen.worldgenplatformgpu;

import bindbc.opengl;
import derelict.sfml2;
import core.thread;

import ac.client.application;
import ac.client.gl.glresourcemanager;
import ac.client.gl.glstate;
import ac.client.gl.gltexture;
import ac.client.world.gen.worldgencodebuildergpu;
import ac.common.world.gen.worldgen;
import ac.common.world.gen.worldgencodebuilder;
import ac.common.world.gen.worldgenplatform;
import ac.common.block.block;
import ac.common.world.world;
import ac.common.world.chunk;
import ac.client.resources;

final class WorldGenPlatform_GPU : WorldGenPlatform {

public:
	override void initialize(WorldGen worldGen) {
		super.initialize(worldGen);

		sfContext_ = sfContext_create();
		glResourceManager = new GLResourceManager();
		glState = new GLState();

		// Allocate the output texture
		chunkTex_ = new GLTexture(GL_TEXTURE_3D);
		chunkTex_.bind(0);

		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAX_LEVEL, 0);

		glTexStorage3D(GL_TEXTURE_3D, 1, GL_R16UI, Chunk.width * 3, Chunk.width * 3, Chunk.height);

		calculatedVRAMUsage += Chunk.width * 3 * Chunk.width * 3 * Chunk.height * 2;

		glAtomicCounterBuffer_ = glResourceManager.create(GLResourceType.buffer);
	}

	~this() {
		if (sfContext_)
			sfContext_destroy(sfContext_);
	}

	override void release() {
		glResourceManager.releaseAll();
		glResourceManager.release(GLResourceType.buffer, glAtomicCounterBuffer_);
	}

	override Chunk generateChunk(WorldVec pos) {
		assert(isFinished_);
		Chunk result = Chunk.obtain(worldGen.world, pos);

		foreach (pass; passes_)
			pass.process(pos, chunkTex_);

		glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);
		glGetTextureSubImage( //
				chunkTex_.textureId, 0, //
				Chunk.width, Chunk.width, 0, //
				Chunk.width, Chunk.width, Chunk.height, //
				GL_RED_INTEGER, GL_UNSIGNED_SHORT, Chunk.volume * Block.ID.sizeof, result.blockIdArray);

		// Prevent using too much GPU (proper sync between contexts would be compilcated, currently no time for that)
		Thread.sleep(dur!"msecs"(1));

		return result;
	}

public:
	override WorldGenCodeBuilder add2DPass() {
		assert(!isFinished_);

		auto result = new WorldGenCodeBuilder_GPU(passIdCounter_++, WorldGenCodeBuilder_GPU.PassType.pass2D, this);
		passes_ ~= result;
		return result;
	}

	override WorldGenCodeBuilder add3DPass() {
		assert(!isFinished_);

		auto result = new WorldGenCodeBuilder_GPU(passIdCounter_++, WorldGenCodeBuilder_GPU.PassType.pass3D, this);
		passes_ ~= result;
		return result;
	}

	/*override WorldGenCodeBuilder addIterativePass() {
		assert(!isFinished_);

		auto result = WorldGenCodeBuilder_GPU.newIterativePass(passIdCounter_++, this);
		passes_ ~= result;
		return result;
	}*/

	override void finish() {
		assert(!isFinished_);
		isFinished_ = true;

		glNamedBufferData(glAtomicCounterBuffer_, GLuint.sizeof * iterativePassCounter_, null, GL_DYNAMIC_DRAW);
	}

package:
	GLint iterativePassCounter_;
	GLint glAtomicCounterBuffer_; ///< Used for iterative passes

private:
	sfContext* sfContext_;
	GLTexture chunkTex_;

private:
	bool isFinished_;
	WorldGenCodeBuilder_GPU[] passes_;
	GLint passIdCounter_;

}
