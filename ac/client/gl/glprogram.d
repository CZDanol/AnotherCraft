module ac.client.gl.glprogram;

import ac.client.gl.glresourcemanager;
import ac.client.gl.glbuffer;
import ac.client.gl.glstate;
import ac.common.math.matrix;
import ac.common.math.vector;
import bindbc.opengl;
import std.array;
import std.format;
import std.path;
import std.file;
import std.regex;
import std.string;
import std.exception;
import std.stdio;
import std.format;
import std.conv;

final class GLProgram {

public:
	this(string name = "(unnamed)", string[string] defines = null) {
		name_ = name;
		programId_ = glResourceManager.create(GLResourceType.program);
		glObjectLabel(GL_PROGRAM, programId_, cast(GLint) name_.length, name_.toStringz);

		foreach (string key, string val; defines)
			define(key, val);
	}

	/// Create a program and add shaders from files "$fileBaseName.$shSuffix.glsl", link the program
	// (for each item in shaders $shSuffix = [fragment => fs, geometry => gs, vertex => vs, compute => cs])
	this(string fileBaseName, GLProgramShader shader1, GLProgramShader[] shaders...) {
		this(fileBaseName);

		addShaderFromFile(shader1, fileBaseName ~ glProgramShader_fileBaseNameSuffix[shader1] ~ ".glsl");

		foreach (sh; shaders)
			addShaderFromFile(sh, fileBaseName ~ glProgramShader_fileBaseNameSuffix[sh] ~ ".glsl");

		link();
	}

	/// Create a program and add shaders from files "$fileBaseName.$shSuffix.glsl", link the program
	// (for each item in shaders $shSuffix = [fragment => fs, geometry => gs, vertex => vs, compute => cs])
	this(string fileBaseName, GLProgramShader[] shaders, string[string] defines = null) {
		this(fileBaseName);

		foreach (string key, string val; defines)
			define(key, val);

		foreach (sh; shaders)
			addShaderFromFile(sh, fileBaseName ~ glProgramShader_fileBaseNameSuffix[sh] ~ ".glsl");

		link();
	}

public:
	/// OpenGL id of the program
	GLuint programId() {
		return programId_;
	}

public:
	void bind() {
		if (recompileRequired_)
			recompile();

		glState.activeProgram = programId_;
	}

	static void unbind() {
		glState.activeProgram = 0;
	}

	/// Destroys the underlying OpenGL program & releases resources
	void release() {
		glResourceManager.release(GLResourceType.program, programId_);
		glResourceManager.release(shaders_.values);
	}

	size_t sourceVersion() {
		return sourceVersion_;
	}

public:
	void addShaderFromString(GLProgramShader shaderType, string baseCode) {
		bool shaderAttached = (shaderType in shaders_) !is null;
		GLuint shaderId;
		if (shaderAttached) {
			shaderId = shaders_[shaderType].id;
		}
		else {
			GLResourceRecord rec = glResourceManager.createRecord(glProgramShader_glResourceType[shaderType]);
			shaders_[shaderType] = rec;
			string name = "%s_%s".format(name_, shaderType);
			glObjectLabel(GL_SHADER, rec.id, cast(GLint) name.length, name.toStringz);
			shaderId = rec.id;
		}

		string code = baseCode;

		string defines;
		foreach (string name, string value; defines_)
			defines ~= "#define %s %s\n".format(name, value);

		if (defines) {
			string replFunc(Captures!string m) { //
				return "%s\n%s\n#line %s 0\n".format(m[1], defines, m[1].count('\n'));
			}

			code = code.replaceAll!replFunc(ctRegex!"^(\\s*(?:#version[^\n]*\n))?");
		}

		string replaceFunction(Captures!string m) {
			const string filePath = m[1];

			string absoluteFilePath = absolutePath(filePath, "../res/shader".absolutePath);
			enforce(absoluteFilePath.exists, "Shader file '%s' does not exist.".format(absoluteFilePath));

			int insertionLine = cast(int) m.pre.count('\n') + 1;
			int sourceId;

			if (auto it = absoluteFilePath in sourceIds_)
				sourceId = *it;
			else {
				sourceId = shaderFileCounter_++;
				sourceNames_[sourceId] = filePath;
				sourceIds_[absoluteFilePath] = sourceId;
			}

			const string code = "#line %s %s\n%s\n#line %s %s\n".format( //
					0, sourceId, //
					includes_.require(absoluteFilePath, readText(absoluteFilePath)), //
					insertionLine, 0);

			return code;
		}

		//code = code.replaceAll!(replaceFunction)(ctRegex!("^\\s*#include \"([^\"]+)\"\\s*$", "m"));
		code = code.replaceAll!(replaceFunction)(ctRegex!"#include \"([^\"]+)\"");

		const(char)* ptr = code.ptr;
		GLint len = cast(GLint) code.length;
		glShaderSource(shaderId, 1, &ptr, &len);
		glCompileShader(shaderId);

		GLint compileStatus = 0;
		glGetShaderiv(shaderId, GL_COMPILE_STATUS, &compileStatus);

		if (compileStatus == GL_FALSE)
			throw new Exception("Error compiling shader '%s': %s".format(name_, shaderLogString(shaderId, code)));

		shaderCodes_[shaderType] = baseCode;
		if (!shaderAttached)
			glAttachShader(programId_, shaderId);
	}

	void addShaderFromFile(GLProgramShader shaderType, string filePath) {
		const string absoluteFilePath = absolutePath(filePath, "../res/shader".absolutePath);
		enforce(absoluteFilePath.exists, "Shader file '%s' does not exist.".format(absoluteFilePath));

		const string code = readText(absoluteFilePath);
		addShaderFromString(shaderType, code);
	}

	void link() {
		glLinkProgram(programId_);

		GLint linkStatus;
		glGetProgramiv(programId_, GL_LINK_STATUS, &linkStatus);

		if (linkStatus == GL_FALSE) {
			GLint errorLength = 0;
			glGetProgramiv(programId_, GL_INFO_LOG_LENGTH, &errorLength);

			char[] errorStr;
			errorStr.length = errorLength;
			glGetProgramInfoLog(programId_, errorLength, &errorLength, errorStr.ptr);

			throw new Exception("Error linking program %s: %s".format(name_, errorStr));
		}

		attributeLocations_ = null;
		uniformLocations_ = null;
		uniformBlockLocations_ = null;
		sourceVersion_++;
	}

	void recompile() {
		foreach (GLProgramShader shaderType, string code; shaderCodes_)
			addShaderFromString(shaderType, code);

		link();
		recompileRequired_ = false;
	}

public:
	/// Adds define to the shader
	/// The shader is automatically recompiled on first use
	void define(string name, string value) {
		if (name in defines_ && defines_[name] == value)
			return;

		defines_[name] = value;
		recompileRequired_ = true;
	}

	void define(string name, int value) {
		define(name, value.to!string);
	}

	void define(string[string] values) {
		foreach (string key, string value; values)
			define(key, value);
	}

	void resetDefines() {
		defines_ = null;
		recompileRequired_ = true;
	}

public:
	GLint attributeLocation(string name, bool reportError = true) {
		GLint result = attributeLocations_.require(name, glGetAttribLocation(programId_, name.toStringz));
		if (reportError && result == -1)
			writeln("Attribute '%s' doesn't exist in the shader '%s'".format(name, name_));

		return result;
	}

	GLint uniformLocation(string name, bool reportError = true) {
		GLint result = uniformLocations_.require(name, glGetUniformLocation(programId_, name.toStringz));
		if (reportError && result == -1)
			writeln("Uniform '%s' doesn't exist in the shader '%s'".format(name, name_));

		return result;
	}

	GLint uniformBlockLocation(string name, bool reportError = true) {
		GLint result = uniformBlockLocations_.require(name, glGetUniformBlockIndex(programId_, name.toStringz));
		if (reportError && result == -1)
			writeln("Uniform block '%s' doesn't exist in the shader '%s'".format(name, name_));

		return result;
	}

public:
	void debugPrintUniformBlock(string blockName) {
		import std.stdio;
		import std.string;

		const GLint blockIx = glGetUniformBlockIndex(programId_, blockName.toStringz);
		writefln("Block %s index %s", blockName, blockIx);

		GLint uniformCount;
		glGetActiveUniformBlockiv(programId_, blockIx, GL_UNIFORM_BLOCK_ACTIVE_UNIFORMS, &uniformCount);

		GLuint[] indices;
		indices.length = uniformCount;
		glGetActiveUniformBlockiv(programId_, blockIx, GL_UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES, cast(int*) indices.ptr);

		foreach (id; indices) {
			GLchar[256] nameBuf;
			GLint nameLen;
			glGetActiveUniformName(programId_, id, nameBuf.sizeof, &nameLen, nameBuf.ptr);

			GLint offset;
			glGetActiveUniformsiv(programId_, 1, &id, GL_UNIFORM_OFFSET, &offset);

			writefln("  %s: %s", nameBuf[0 .. nameLen], offset);
		}
	}

private:
	string shaderLogString(GLuint shaderId, string code) {
		GLint errorLength = 0;
		glGetShaderiv(shaderId, GL_INFO_LOG_LENGTH, &errorLength);

		char[] errorChars;
		errorChars.length = errorLength;
		glGetShaderInfoLog(shaderId, errorLength, &errorLength, errorChars.ptr);

		string errorStr = errorChars.to!string;
		int lineNum;

		auto replFunc = (Captures!string m) { //
			return "%s(%s) :".format(sourceNames_.get(m[1].to!int, "root"), m[2]);
		};
		errorStr = errorStr.replaceAll!(replFunc)(ctRegex!"\\b([0-9]+)\\(([0-9]+)\\) :");

		return "%s".format(errorStr);
	}

private:
	string name_;
	GLuint programId_;
	GLResourceRecord[GLProgramShader] shaders_;
	string[int] sourceNames_; // Shader file mapping for error reporintg
	int[string] sourceIds_;

	string[GLProgramShader] shaderCodes_;
	string[string] defines_;
	string[string] includes_; ///< Cached include files
	GLint[string] attributeLocations_, uniformLocations_, uniformBlockLocations_;
	bool recompileRequired_;
	int shaderFileCounter_;
	size_t sourceVersion_; ///< Increased with each recompile

}

enum GLProgramShader {
	geometry,
	vertex,
	fragment,
	compute
}

immutable GLResourceType[GLProgramShader] glProgramShader_glResourceType;
immutable string[GLProgramShader] glProgramShader_fileBaseNameSuffix;

shared static this() {
	glProgramShader_glResourceType = [ //
	GLProgramShader.geometry : GLResourceType.geometryShader, //
		GLProgramShader.vertex : GLResourceType.vertexShader, //
		GLProgramShader.fragment : GLResourceType.fragmentShader, //
		GLProgramShader.compute : GLResourceType.computeShader, //
		];

	glProgramShader_fileBaseNameSuffix = [ //
	GLProgramShader.geometry : ".gs", //
		GLProgramShader.vertex : ".vs", //
		GLProgramShader.fragment : ".fs", //
		GLProgramShader.compute : ".cs" //
		];
}
