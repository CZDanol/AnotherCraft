module ac.client.gl.glbuffer;

import bindbc.opengl;
import std.container.array;
import std.meta;
import std.range;

import ac.client.gl.glresourcemanager;
import ac.client.gl.gltypes;
import ac.client.gl.glstate;
import ac.common.math.vector;

final class GLBuffer(T_) {

public:
	alias T = T_;
	alias GL_T = GLType!T;

public:
	this(bool uploadAsFloat = true) {
		uploadAsFloat_ = uploadAsFloat;
		bufferId_ = glResourceManager.create(GLResourceType.buffer);
	}

public:
	pragma(inline) bool uploadAsFloat() {
		return uploadAsFloat_;
	}

public:
	void bind(GLenum target = GL_ARRAY_BUFFER) {
		glState.bindBuffer(target, bufferId_);
	}

	static void unbind(GLenum boundTarget = GL_ARRAY_BUFFER) {
		glState.bindBuffer(boundTarget, 0);
	}

	/// Destroys the underlying OpenGL buffer
	void release() {
		glResourceManager.release(GLResourceType.buffer, bufferId_);
	}

public:
	void clear() {
		data_.length = 0;
	}

	/// Clears the local (CPU) buffer and the memory for the buffer
	void clearMore() {
		data_.clear();
	}

	/// Resets uploaded length (so that the buffer does not report that it has items)
	void clearUploaded() {
		uploadedLength_ = 0;
	}

	/// Returns length of the uploaded buffer (number of vectors * vector dimension)
	/// Does not show length of the current buffer
	size_t length() {
		return uploadedLength_;
	}

	/// Uploads the locally bulit data to the buffer, the data is uploaded using glNameBufferData
	/// The local data is not cleared, you have to clear it manually using GLBuffer.clear
	void upload(GLenum usage) {
		if (data_.length)
			glNamedBufferData(bufferId_, T.sizeof * data_.length, &data_[0], usage);
		else
			glNamedBufferData(bufferId_, 0, null, usage);

		uploadedLength_ = data_.length;
	}

public:
	pragma(inline) void opOpAssign(string op : "~")(T val) {
		data_ ~= val;
	}

	pragma(inline) void opOpAssign(string op : "~", Vec : Vector!(T, D, C), uint D, string C)(Vec vec) {
		data_ ~= vec.val[];
	}

	pragma(inline) void opOpAssign(string op : "~", Range)(Range range) //
	if (isInputRange!Range && is(ElementType!Range == T)) //
	{
		data_ ~= range;
	}

	pragma(inline) void add(size_t D)(Repeat!(D, T) vals) {
		data_ ~= vals;
	}

	/// Adds quad represented as two triangles
	pragma(inline) void addTrianglesQuad(Vec : Vector!(T, D, C), uint D, string C)(Vec lt, Vec rt, Vec lb, Vec rb) {
		this ~= lb;
		this ~= rb;
		this ~= lt;

		this ~= rb;
		this ~= rt;
		this ~= lt;
	}

	pragma(inline) void addTrianglesQuad(Vec : Vector!(T, D, C), uint D, string C)(Vec offset, Vec lt, Vec rt, Vec lb, Vec rb) {
		addTrianglesQuad(offset + lt, offset + rt, offset + lb, offset + rb);
	}

private:
	GLint bufferId_;
	size_t uploadedLength_;
	bool uploadAsFloat_;
	Array!T data_;

}
