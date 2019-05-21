module ac.client.gl.glresourcemanager;

import bindbc.opengl;
import std.container.rbtree;
import std.meta;
import std.traits;

import ac.client.gl.glstate;

enum GLResourceType {
	@Ctor((ref id) => glCreateBuffers(1, &id))  //
	@Dtor((ref id) => glDeleteBuffers(1, &id))  //
	buffer,

	@Ctor((ref id) { id = glCreateProgram(); })  //
	@Dtor((ref id) => glDeleteProgram(id))  //
	program,

	@Ctor((ref id) { id = glCreateShader(GL_GEOMETRY_SHADER); })  //
	@Dtor((ref id) => glDeleteShader(id))  //
	geometryShader,

	@Ctor((ref id) { id = glCreateShader(GL_VERTEX_SHADER); })  //
	@Dtor((ref id) => glDeleteShader(id))  //
	vertexShader,

	@Ctor((ref id) { id = glCreateShader(GL_FRAGMENT_SHADER); })  //
	@Dtor((ref id) => glDeleteShader(id))  //
	fragmentShader,

	@Ctor((ref id) { id = glCreateShader(GL_COMPUTE_SHADER); })  //
	@Dtor((ref id) => glDeleteShader(id))  //
	computeShader,

	@Ctor((ref id) => glGenVertexArrays(1, &id))  //
	@Dtor((ref id) => glDeleteVertexArrays(1, &id))  //
	vao,

	@Ctor((ref id) => glCreateTextures(GL_TEXTURE_2D, 1, &id))  //
	@Dtor((ref id) => glDeleteTextures(1, &id))  //
	texture2D,

	@Ctor((ref id) => glCreateTextures(GL_TEXTURE_2D_MULTISAMPLE, 1, &id))  //
	@Dtor((ref id) => glDeleteTextures(1, &id))  //
	texture2DMS,

	@Ctor((ref id) => glCreateTextures(GL_TEXTURE_2D_ARRAY, 1, &id))  //
	@Dtor((ref id) => glDeleteTextures(1, &id))  //
	texture2DArray,

	@Ctor((ref id) => glCreateTextures(GL_TEXTURE_3D, 1, &id))  //
	@Dtor((ref id) => glDeleteTextures(1, &id))  //
	texture3D,

	@Ctor((ref id) => glCreateFramebuffers(1, &id))  //
	@Dtor((ref id) => glDeleteFramebuffers(1, &id))  //
	framebuffer,

	_length
}

/// GLResrouceManager keeps track of all GL resources (textures, buffers, ...) and ensures proper cleaning up
final class GLResourceManager {

public:
	this() {
		resources_ = redBlackTree!(resourceCmpLess, GLResourceRecord)();

		foreach (string memberName; __traits(derivedMembers, GLResourceType)) {
			alias resourceType = Alias!(__traits(getMember, GLResourceType, memberName));

			static if (resourceType != GLResourceType._length) {
				ctors_[resourceType] = __traits(getAttributes, resourceType)[0];
				dtors_[resourceType] = __traits(getAttributes, resourceType)[1];
			}
		}
	}

public:
	/// Creates a resource and returns its identifier
	GLuint create(GLResourceType resourceType) {
		GLuint result;
		ctors_[resourceType].func(result);
		resources_.insert(GLResourceRecord(resourceType, result));
		return result;
	}

	/// Creates a resource and returns its identifier
	GLResourceRecord createRecord(GLResourceType resourceType) {
		GLResourceRecord result;
		result.resourceType = resourceType;
		ctors_[resourceType].func(result.id);
		resources_.insert(result);
		return result;
	}

	/// Issues the provided resource for cleanup
	/// This function can be called from any thread (so the GC doesn't screw it up)
	void release(GLResourceType resourceType, GLuint id) {
		synchronized (this)
			resourcesToBeReleased_ ~= GLResourceRecord(resourceType, id);
	}

	/// Issues provided resources for cleanup
	/// This function can be called from any thread (so the GC doesn't screw it up)
	void release(GLResourceRecord[] records) {
		synchronized (this)
			resourcesToBeReleased_ ~= records;
	}

	/// Releases all resources planned for cleanup
	void cleanup() {
		synchronized (this) {
			auto tmp = resourcesToBeReleasedSwap_;
			resourcesToBeReleasedSwap_ = resourcesToBeReleased_;
			resourcesToBeReleased_ = tmp;
			resourcesToBeReleased_.length = 0;
		}

		foreach (GLResourceRecord rec; resourcesToBeReleasedSwap_) {
			releaseImpl(rec.resourceType, rec.id);
			resources_.removeKey(rec);
		}
	}

	/// Releases all resources
	void releaseAll() {
		synchronized (this)
			resourcesToBeReleased_.length = 0;

		foreach (GLResourceRecord rec; resources_)
			releaseImpl(rec.resourceType, rec.id);

		resources_.clear();
	}

private:
	void releaseImpl(GLResourceType resourceType, GLuint id) {
		dtors_[resourceType].func(id);
	}

private:
	enum resourceCmpLess = "a.resourceType < b.resourceType || (a.resourceType == b.resourceType && a.id < b.id)";
	RedBlackTree!(GLResourceRecord, resourceCmpLess) resources_;
	GLResourceRecord[] resourcesToBeReleased_, resourcesToBeReleasedSwap_;

private:
	Ctor[GLResourceType._length] ctors_;
	Dtor[GLResourceType._length] dtors_;

}

struct GLResourceRecord {
	GLResourceType resourceType;
	GLuint id;
}

private struct Ctor {
	void function(ref GLuint) func;
}

private struct Dtor {
	void function(ref GLuint) func;
}

GLResourceManager glResourceManager;
