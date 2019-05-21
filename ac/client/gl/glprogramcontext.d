module ac.client.gl.glprogramcontext;

import bindbc.opengl;
import std.format;
import std.conv;
import std.string;

import ac.client.gl.glprogram;
import ac.client.gl.gltexture;
import ac.client.gl.glbuffer;
import ac.client.gl.glbindingsvao;
import ac.client.gl.glstate;
import ac.client.gl.glresourcemanager;
import ac.common.math.matrix;
import ac.common.math.vector;
import ac.common.util.meta;

/// Program context - handles setting up everything: program, textures, buffers, uniforms, etc.
final class GLProgramContext {

public:
	this(GLProgram program = null, bool lazyUniforms = true) {
		bindingsVAO_ = new GLBindingsVAO();
		program_ = program;
		lazyUniforms_ = lazyUniforms;
	}

public:
	/// Binds the program and all the connected resources
	/// Functions like setUniform/bindXX/setProgram won't have any effect until bound again
	void bind(bool bindVao = true) {
		program_.bind();

		if (bindVao)
			bindingsVAO_.bind();

		// If the program was recompiled/changed, we need to rebind/reset all the stuff
		if (programSourceVersion_ != program.sourceVersion) {
			programSourceVersion_ = program.sourceVersion;

			foreach (setter; oneTimeSettersAll_)
				setter();
		}

		foreach (key, setter; oneTimeSetters_) {
			setter();
			oneTimeSettersAll_[key] = setter;
		}
		oneTimeSetters_.clear();

		foreach (setter; periodicalSetters_)
			setter();

		foreach (GLenum what, bool enable; enables_)
			glState.setEnabled(what, enable);
	}

	/// Release all GL resources allocated by the context
	void release() {
		bindingsVAO_.release();

		foreach (buf; uniformBlocks_.byValue)
			glResourceManager.release(GLResourceType.buffer, buf);
	}

public:
	void setProgram(GLProgram program) {
		program_ = program;
		programSourceVersion_ = -1;
	}

	pragma(inline) GLProgram program() {
		return program_;
	}

	void bindBuffer(Buf : GLBuffer!Bx, Bx...)(string attributeName, Buf buffer, int components, int stride = 0, int offset = 0, bool normalize = false) {
		GLint id = bufferBindingUnits_.require(attributeName, bufferBindingCounter_++);

		oneTimeSetters_[attributeName] = { //
			glEnableVertexAttribArray(id);

			GLint pos = program_.attributeLocation(attributeName);
			if (pos == -1)
				return;

			buffer.bind();

			if (buffer.uploadAsFloat)
				glVertexAttribPointer(id, components, buffer.GL_T, normalize, stride, cast(void*) offset);
			else
				glVertexAttribIPointer(id, components, buffer.GL_T, stride, cast(void*) offset);
		};
	}

	void bindTexture(string uniformName, GLTexture texture, bool reportError = true) {
		GLint id = textureUnits_.require(uniformName, usedTextureUnitCount_++);

		oneTimeSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName, reportError);
			if (pos == -1)
				return;

			glUniform1i(pos, id);
		};

		periodicalSetters_[uniformName] = { //
			texture.bind(id);
		};
	}

	void bindTexture(GLuint binding, GLTexture texture) {
		if (usedTextureUnitCount_ <= binding)
			usedTextureUnitCount_ = binding + 1;

		periodicalSetters_["texture%s".format(binding)] = { //
			texture.bind(binding);
		};
	}

public:
	void enable(GLenum what) {
		enables_[what] = true;
	}

	void disable(GLenum what) {
		enables_[what] = false;
	}

	void setEnabled(GLenum what, bool set) {
		enables_[what] = set;
	}

public:
	void setUniformBlock(T)(string uniformBlockName, const ref T value, bool reportError = true) {
		GLuint buffer = uniformBlocks_.require(uniformBlockName, { //
			GLuint bufferId = glResourceManager.create(GLResourceType.buffer);
			GLuint bindingPoint = uniformBlockBindingCounter_++;

			string label = "programContext_uniformBlock_%s".format(uniformBlockName);
			glObjectLabel(GL_BUFFER, bufferId, cast(GLint) label.length, label.toStringz);

			oneTimeSetters_[uniformBlockName] = { //
				GLint pos = program_.uniformBlockLocation(uniformBlockName, reportError);
				if (pos == -1)
					return;

				glUniformBlockBinding(program_.programId, pos, bindingPoint);
			};

			periodicalSetters_[uniformBlockName] = { //
				glBindBufferBase(GL_UNIFORM_BUFFER, bindingPoint, bufferId);
			};

			return bufferId;
		}());

		glNamedBufferData(buffer, T.sizeof, &value, GL_DYNAMIC_DRAW);
	}

	void setUniformBlock(T)(GLuint bindingPoint, const ref T value, bool reportError = true) {
		GLuint buffer = uniformBlocks_.require(bindingPoint.to!string, { //
			GLuint bufferId = glResourceManager.create(GLResourceType.buffer);

			periodicalSetters_["uniformBlock#%s".format(bindingPoint)] = { //
				glBindBufferBase(GL_UNIFORM_BUFFER, bindingPoint, bufferId);
			};

			return bufferId;
		}());

		glNamedBufferData(buffer, T.sizeof, &value, GL_DYNAMIC_DRAW);
	}

	void setUniform(string uniformName, GLint value, bool reportError = true) {
		oneTimeSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName, reportError);
			if (pos == -1)
				return;

			glUniform1i(pos, value);
		};
	}

	void setUniform(string uniformName, GLuint value, bool reportError = true) {
		oneTimeSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName, reportError);
			if (pos == -1)
				return;

			glUniform1ui(pos, value);
		};
	}

	void setUniform(string uniformName, GLfloat value, bool reportError = true) {
		oneTimeSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName, reportError);
			if (pos == -1)
				return;

			glUniform1f(pos, value);
		};
	}

	void setUniform(Vec : Vector!(T, D, cookie), T, uint D, string cookie)(string uniformName, Vec value, bool reportError = true) {
		enum string[string] typeString = ["float" : "f", "int" : "i"];
		enum typeStr = typeString[T.stringof];

		oneTimeSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName, reportError);
			if (pos == -1)
				return;

			mixin("glUniform%s%s".format(D, typeStr))(pos, staticArrayToTuple!(value));
		};
	}

	void setUniform(string uniformName, Matrix matrix, bool reportError = true) {
		oneTimeSetters_[uniformName] = { //
			GLint pos = program_.uniformLocation(uniformName, reportError);
			if (pos == -1)
				return;

			glUniformMatrix4fv(pos, 1, GL_FALSE, matrix.m.ptr);
		};
	}

private:
	struct UniformBlock {
		GLint bufferId;
		GLint bindingPoint;
	}

private:
	GLProgram program_;
	GLBindingsVAO bindingsVAO_;
	GLint usedTextureUnitCount_, uniformBlockBindingCounter_, bufferBindingCounter_;
	bool[GLenum] enables_;
	GLint[string] textureUnits_, bufferBindingUnits_, uniformBlocks_;
	bool lazyUniforms_; /// If true, uniforms are set only once when changed (does not work well when the program is used in multiple contexts)

	size_t programSourceVersion_;
	void delegate()[string] oneTimeSetters_, oneTimeSettersAll_, periodicalSetters_;

}
