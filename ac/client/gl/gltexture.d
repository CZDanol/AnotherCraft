module ac.client.gl.gltexture;

import ac.client.gl.glresourcemanager;
import ac.client.gl.glstate;
import ac.common.math.vector;
import bindbc.opengl;

class GLTexture {

protected:
	static immutable GLResourceType[GLenum] typeAA_;
	shared static this() {
		typeAA_ = [ //
	GL_TEXTURE_2D : GLResourceType.texture2D, //
	GL_TEXTURE_2D_MULTISAMPLE : GLResourceType.texture2DMS, //
	GL_TEXTURE_2D_ARRAY : GLResourceType.texture2DArray, //
	GL_TEXTURE_3D : GLResourceType.texture3D, //
	];
	}

public:
	this(GLenum type) {
		type_ = type;
		textureId_ = glResourceManager.create(typeAA_[type]);
	}

	/// Destroys the underlying opengl texture
	void release() {
		glResourceManager.release(typeAA_[type_], textureId_);
	}

	/// Releases the texture and then creates it again
	void recreate() {
		versionId_++;

		glResourceManager.release(typeAA_[type_], textureId_);
		textureId_ = glResourceManager.create(typeAA_[type_]);
	}

public:
	final void bind(int activeTexture = 0) {
		glState.activeTexture = activeTexture;
		glBindTexture(type_, textureId_);
	}

	final void unbind(int activeTexture = 0) {
		glState.activeTexture = activeTexture;
		glBindTexture(type_, 0);
	}

public:
	/// Returns OpenGL id of the texture
	pragma(inline) final GLuint textureId() const {
		return textureId_;
	}

	/// Returns OpenGL type of the texture (GL_TEXTURE_2D, GL_TEXTURE_3D, ...)
	pragma(inline) final GLenum textureType() const {
		return type_;
	}

	pragma(inline) final size_t versionId() const {
		return versionId_;
	}

protected:
	/// Each increment signalizes that different textureId_ has been set/rebound
	/// When this number changes, it is a signal for framebuffers that the texture needs to be reattached
	size_t versionId_;
	GLuint textureId_;
	GLenum type_;

}
