module ac.client.gl.glbindingsvao;

import ac.client.gl.glresourcemanager;
import ac.client.gl.glprogram;
import ac.client.gl.glbuffer;
import ac.client.gl.glstate;
import ac.common.math.vector;
import bindbc.opengl;

final class GLBindingsVAO {

public:
	this() {
		vaoId_ = glResourceManager.create(GLResourceType.vao);
	}

public:
	void bind() {
		glState.boundVAO = vaoId_;
	}

	static void unbind() {
		glState.boundVAO = 0;
	}

	GLuint vaoID() {
		return vaoId_;
	}

	/// Binds provided buffer to attribute attributeName (which is expected to be a vector of dimensions dimensions) of program program
	/// Assumes the current vao is bound
	/// Binds the buffer internally to GL_ARRAY_BUFFER (and then unbinds it)
	void bindBuffer(Buf : GLBuffer!Bx, Bx...)(GLuint attribArray, Buf buffer, int components, int stride = 0, int offset = 0, bool normalize = false) {
		debug assert(glState.boundVAO == vaoId_);

		buffer.bind(GL_ARRAY_BUFFER);

		glEnableVertexAttribArray(attribArray);

		if (buffer.uploadAsFloat)
			glVertexAttribPointer(attribArray, components, buffer.GL_T, normalize, stride, cast(void*) offset);
		else
			glVertexAttribIPointer(attribArray, components, buffer.GL_T, stride, cast(void*) offset);

		buffer.unbind(GL_ARRAY_BUFFER);
	}

	/// Destroys the underlying opengl object
	void release() {
		glResourceManager.release(GLResourceType.vao, vaoId_);
	}

private:
	GLuint vaoId_;

}
