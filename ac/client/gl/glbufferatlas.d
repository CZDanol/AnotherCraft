module ac.client.gl.glbufferatlas;

import bindbc.opengl;
import std.container.array;
import std.container.rbtree;
import std.meta;
import std.format;
import std.range;
import std.string;
import std.traits;

import ac.client.gl.gltypes;
import ac.client.gl.glstate;
import ac.client.gl.glresourcemanager;
import ac.client.resources;
import ac.common.math.vector;

alias GLBufferAtlasSize = GLsizei;

/// GLBufferAtlas is pratically a memory manager for OpenGL. it manages "subbuffers" in a single big buffer (or multiple, based on component count)
final class GLBufferAtlas(size_t[] componentsPerVertex, ComponentTypes_...) {
	static assert(componentsPerVertex.length == ComponentTypes.length);

public:
	enum baseSize = 100_000;
	enum componentCount = ComponentTypes.length;

	alias ComponentTypes = ComponentTypes_;
	alias RegionBuilder = GLBufferAtlasRegionBuilder!(componentsPerVertex, ComponentTypes);
	alias SubBuffer = GLBufferAtlasSubBuffer;
	alias Size = GLBufferAtlasSize;

public:
	/// Allocates buffers for $size elements
	this(Size size = baseSize) {
		freeRegionsBySize_ = new FreeRegionsBySize();
		freeRegionsByOffset_ = new FreeRegionsByOffset();

		size_ = size;
		insertFreeRegion(SubBuffer(0, size_));

		static foreach (i; 0 .. componentCount) {
			{

				buffers_[i] = glResourceManager.create(GLResourceType.buffer);
				auto targetSize = size_ * ComponentTypes[i].sizeof * componentsPerVertex[i];

				string label = "%s_%s".format(typeof(this).stringof, i);
				glObjectLabel(GL_BUFFER, buffers_[i], cast(GLint) label.length, label.toStringz);

				glState.bindBuffer(GL_ARRAY_BUFFER, buffers_[i]);
				glBufferStorage(GL_ARRAY_BUFFER, targetSize, null, GL_DYNAMIC_STORAGE_BIT);

				calculatedVRAMUsage += targetSize;
			}
		}
	}

	void release() {
		foreach (buf; buffers_)
			glResourceManager.release(GLResourceType.buffer, buf);
	}

public:
	pragma(inline) GLuint buffer(size_t i) {
		return buffers_[i];
	}

	pragma(inline) size_t itemsAllocated() {
		return size_;
	}

	pragma(inline) size_t itemsUsed() {
		return size_ - freeSize_;
	}

public:
	SubBuffer upload(RegionBuilder rb) {
		const Size elementCount = cast(Size)(rb[0].length / componentsPerVertex[0]);
		static foreach (i; 0 .. componentCount) {
			assert(rb[i].length / componentsPerVertex[i] == elementCount, "elemCount for %s: %s / %s".format(i, rb[i].length / componentsPerVertex[i], elementCount));
			assert(rb[i].length % componentsPerVertex[i] == 0, "length % elementCount = %s for %s".format(rb[i].length % componentsPerVertex[i], i));
		}

		if (elementCount == 0)
			return SubBuffer(0, 0);

		if (freeRegionsBySize_.empty)
			reserveMoreSpace();

		// Find a smallest region that fits the data; if there is no such region, allocate more space
		SubBuffer reg;
		while (true) {
			auto range = freeRegionsBySize_.upperBound(SubBuffer(0, elementCount - 1));
			if (!range.empty) {
				reg = range.front;
				break;
			}

			reserveMoreSpace();
		}

		// Remove the region as it is no longer free. If the region is bigger than what we need, insert a record for the remaining free space
		removeFreeRegion(reg);
		if (reg.size > elementCount) {
			SubBuffer nreg;
			nreg.offset = reg.offset + elementCount;
			nreg.size = reg.size - elementCount;
			insertFreeRegion(nreg);
		}

		static foreach (i; 0 .. componentCount) {
			{
				const auto componentSize = ComponentTypes[i].sizeof * componentsPerVertex[i];
				glNamedBufferSubData(buffers_[i], reg.offset * componentSize, elementCount * componentSize, &(rb[i].data_[0]));
			}
		}

		/*import std.stdio;

		writeln();
		writeln("Upload ", SubBuffer(reg.offset, elementCount));
		writeln(freeRegionsByOffset_);
		writeln(freeRegionsBySize_);*/

		debug assert(reg.offset >= 0 && elementCount > 0);
		return SubBuffer(reg.offset, elementCount);
	}

	void free(SubBuffer reg) {
		debug assert(reg.offset >= 0 && reg.size >= 0);

		if (reg.size == 0)
			return;

		// If there is a free region following, join them
		{
			auto range = freeRegionsByOffset_.upperBound(SubBuffer(reg.offset));
			debug assert(range.empty || range.front.offset >= reg.offset + reg.size, "Freed region %s overlapping with %s".format(reg, range.front));
			if (!range.empty && range.front.offset == reg.offset + reg.size) {
				reg.size += range.front.size;
				removeFreeRegion(range.front);
			}
		}

		// If there is a free region preceding, join them
		{
			auto range = freeRegionsByOffset_.lowerBound(SubBuffer(reg.offset));
			debug assert(range.empty || range.back.offset + range.back.size <= reg.offset, "Freed region %s overlapping with %s".format(reg, range.back));
			if (!range.empty && range.back.offset + range.back.size == reg.offset) {
				reg.size += range.back.size;
				reg.offset = range.back.offset;
				removeFreeRegion(range.back);
			}
		}

		insertFreeRegion(reg);

		/*import std.stdio;

		writeln();
		writeln("Free ", reg);
		writeln(freeRegionsByOffset_);
		writeln(freeRegionsBySize_);*/
	}

public:
	void delegate()[void* ] afterResizeEvent;

private:
	void reserveMoreSpace() {
		const Size oldSize = size_;
		size_ *= 2;

		import ac.common.util.log;

		writeLog(typeof(this).stringof, " resized to ", size_, " elements; free size ", freeSize_, "/", oldSize, " (", float(freeSize_) / oldSize * 100, " %)");

		static foreach (i; 0 .. componentCount) {
			{
				enum componentSize = ComponentTypes[i].sizeof * componentsPerVertex[i];
				GLuint oldBuf = buffers_[i];

				GLuint newBuf = glResourceManager.create(GLResourceType.buffer);
				glNamedBufferStorage(newBuf, size_ * componentSize, null, GL_DYNAMIC_STORAGE_BIT);

				string label = "%s_%s".format(typeof(this).stringof, i);
				glObjectLabel(GL_BUFFER, newBuf, cast(GLint) label.length, label.toStringz);

				// Copy old buffer data to the new one
				glCopyNamedBufferSubData(oldBuf, newBuf, 0, 0, oldSize * componentSize);

				glResourceManager.release(GLResourceType.buffer, oldBuf);
				buffers_[i] = newBuf;

				calculatedVRAMUsage += oldSize * componentSize;
			}
		}

		// Insert a new free region for the newly allocated memory
		SubBuffer nbuf = SubBuffer(oldSize, size_ - oldSize);
		if (!freeRegionsByOffset_.empty) {
			SubBuffer buf = freeRegionsByOffset_.back;
			if (buf.offset + buf.size == oldSize) {
				removeFreeRegion(buf);
				nbuf.offset = buf.offset;
				nbuf.size += buf.size;
			}
		}
		insertFreeRegion(nbuf);

		foreach (ev; afterResizeEvent)
			ev();
	}

private:
	pragma(inline) void insertFreeRegion(SubBuffer rec) {
		freeRegionsBySize_.insert(rec);
		freeRegionsByOffset_.insert(rec);
		freeSize_ += rec.size;
	}

	pragma(inline) void removeFreeRegion(SubBuffer rec) {
		freeRegionsBySize_.removeKey(rec);
		freeRegionsByOffset_.removeKey(rec);
		freeSize_ -= rec.size;
	}

private:
	alias FreeRegionsBySize = RedBlackTree!(SubBuffer, "a.size < b.size");
	alias FreeRegionsByOffset = RedBlackTree!(SubBuffer, "a.offset < b.offset");

	FreeRegionsBySize freeRegionsBySize_;
	FreeRegionsByOffset freeRegionsByOffset_;

private:
	Size size_, freeSize_;
	GLuint[componentCount] buffers_;

}

static struct GLBufferAtlasSubBuffer {
	GLBufferAtlasSize offset = 0;
	GLBufferAtlasSize size = 0;
}

final class GLBufferAtlasRegionBuilder(size_t[] componentsPerVertex, ComponentTypes...) {

public:
	private static typeof(this) firstReleased_;
	private typeof(this) nextReleased_;
	private this() {

	}

	static typeof(this) obtain() {
		if (!firstReleased_)
			return new typeof(this);

		auto result = firstReleased_;
		firstReleased_ = result.nextReleased_;
		return result;
	}

	void release() {
		foreach (ref c; components)
			c.clear();

		nextReleased_ = firstReleased_;
		firstReleased_ = this;
	}

	void clear() {
		foreach (ref c; components)
			c.clear();
	}

	size_t length() {
		return components[0].data_.length / componentsPerVertex[0];
	}

public:
	staticMap!(tmap, ComponentTypes) components;
	alias components this;

private:
	template tmap(T) {
		alias tmap = GLBufferAtlasRegionBuilderComponent!T;
	}

}

struct GLBufferAtlasRegionBuilderComponent(T) {

public:
	void clear() {
		data_.length = 0;
	}

public:
	pragma(inline) void opOpAssign(string op : "~")(T val) {
		data_ ~= val;
	}

	pragma(inline) void opOpAssign(string op : "~", Vec : Vector!(T, D, C), uint D, string C)(Vec vec) {
		data_ ~= vec.val[];
	}

	pragma(inline) void opOpAssign(string op : "~", Range)(Range range) //
	if (isInputRange!Range && isImplicitlyConvertible!(ElementType!Range, T)) //
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

public:
	pragma(inline) size_t length() {
		return data_.length;
	}

private:
	Array!T data_;

}
