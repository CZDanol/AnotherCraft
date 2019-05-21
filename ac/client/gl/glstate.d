module ac.client.gl.glstate;

import bindbc.opengl;
import std.stdio;

import ac.client.gl.glbindingsvao;

// TODO BOUND PROGRAM

final class GLState {

public:
	this() {
		forget();
	}

public:
	/// Reset all relevant GL states to default values -> unbind buffers, programs, VAOs, ...
	void reset() {
		boundVAO = 0;
		activeProgram = 0;
		activeTexture = 0;

		foreach (GLenum target; boundBuffer_.byKey)
			bindBuffer(target, 0);
	}

	/// Forget current state; GLState keeps cache of the GL states. This function invalidates the cache
	void forget() {
		activeTexture_ = -1;
		boundVAO_ = -1;
		activeProgram_ = -1;

		enables_.clear();

		foreach (ref GLint val; boundBuffer_.byValue)
			val = -1;
	}

public:
	void setEnabled(GLenum what, bool enabled) {
		if (enabled)
			enable(what);
		else
			disable(what);
	}

	void enable(GLenum what) {
		if (enables_.require(what, EnableState.unknown) == EnableState.on)
			return;

		enables_[what] = EnableState.on;
		glEnable(what);
	}

	void disable(GLenum what) {
		if (enables_.require(what, EnableState.unknown) == EnableState.off)
			return;

		enables_[what] = EnableState.off;
		glDisable(what);
	}

public:
	pragma(inline) void activeTexture(int set) {
		GLint tex = GL_TEXTURE0 + set;

		if (activeTexture_ == tex)
			return;

		activeTexture_ = tex;
		glActiveTexture(tex);
	}

	pragma(inline) void activeProgram(GLint set) {
		if (activeProgram_ == set)
			return;

		activeProgram_ = set;
		glUseProgram(set);
	}

	pragma(inline) GLint boundVAO() {
		return boundVAO_;
	}

	pragma(inline) void boundVAO(GLint set) {
		if (boundVAO_ == set)
			return;

		boundVAO_ = set;
		glBindVertexArray(set);
	}

	void bindBuffer(GLenum target, GLint set) {
		if (boundBuffer_.require(target, -1) == set)
			return;

		boundBuffer_[target] = set;
		glBindBuffer(target, set);
	}

private:
	GLint activeTexture_, boundVAO_, activeProgram_;
	GLint[GLenum] boundBuffer_;
	EnableState[GLenum] enables_;

public:
	enum EnableState {
		off,
		on,
		unknown
	};

}

void testForGLErrors(string file = __FILE__, uint line = __LINE__)() {
	auto err = glGetError();
	if (err != GL_NO_ERROR)
		writeln(file, ":", line, " GLERROR ", err);
}

GLState glState;
