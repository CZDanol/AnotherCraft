module ac.client.gl.glframebuffer;

import std.algorithm;

import ac.client.gl.glresourcemanager;
import ac.client.gl.glscreentexture;
import ac.client.gl.glstate;
import ac.client.gl.gltexture;
import ac.common.math.vector;
import bindbc.opengl;

final class GLFramebuffer {

public:
	this() {
		fboId_ = glResourceManager.create(GLResourceType.framebuffer);
	}

	/// Destroys the underlying opengl texture
	void release() {
		glResourceManager.release(GLResourceType.framebuffer, fboId_);
	}

public:
	void bind(GLenum target = GL_FRAMEBUFFER) {
		glBindFramebuffer(target, fboId_);

		// Eventually reattach textures when needed
		foreach (GLenum attachment, ref Attachment rec; attachments_) {
			if (rec.texture.versionId != rec.versionId) {
				rec.versionId = rec.texture.versionId;
				attach(attachment, rec.texture, false, target);
			}
		}

		if (needsUpdateDrawBuffers_) {
			glDrawBuffers(maxColorAttachment_ + 1, drawBuffers.ptr);
			needsUpdateDrawBuffers_ = false;
		}
	}

	static void unbind(GLenum boundTarget = GL_FRAMEBUFFER) {
		glBindFramebuffer(boundTarget, 0);
	}

	auto boundGuard(GLenum target = GL_FRAMEBUFFER) {
		static struct Result {
			~this() {
				unbind(target_);
			}

			GLenum target_;
		}

		bind(target);
		return Result(target);
	}

public:
	/// Attaches the provided texture to the framebuffer
	/// If doBind is true, automatically binds & unbinds the framebuffer, otherwise you have to do it manually
	void attach(GLenum attachment, GLTexture texture, bool doBind = true, GLenum bindTarget = GL_FRAMEBUFFER) {
		if (doBind)
			bind(bindTarget);

		if (attachment >= GL_COLOR_ATTACHMENT0 && attachment <= GL_COLOR_ATTACHMENT5) {
			maxColorAttachment_ = max(maxColorAttachment_, attachment - GL_COLOR_ATTACHMENT0);
			needsUpdateDrawBuffers_ = true;
		}

		glFramebufferTexture2D(bindTarget, attachment, texture.textureType, texture.textureId, 0);

		attachments_[attachment] = Attachment(texture, texture.versionId);

		if (doBind)
			unbind(bindTarget);
	}

private:
	static struct Attachment {
		GLTexture texture;
		size_t versionId;
	}

private:
	GLuint fboId_;
	GLint maxColorAttachment_;
	Attachment[GLenum] attachments_;
	static const GLenum[] drawBuffers = [GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT3, GL_COLOR_ATTACHMENT4, GL_COLOR_ATTACHMENT5];
	bool needsUpdateDrawBuffers_ = true;

}
