module ac.client.world.gen.worldgencodebuildergpu;

import bindbc.opengl;
import core.bitop;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.range;

import ac.client.gl.glprogram;
import ac.client.gl.glprogramcontext;
import ac.client.gl.glstate;
import ac.client.gl.gltexture;
import ac.client.gl.glresourcemanager;
import ac.client.world.gen.worldgenplatformgpu;
import ac.common.block.block;
import ac.common.game.game;
import ac.common.math.vector;
import ac.common.world.chunk;
import ac.common.world.gen.worldgencodebuilder;
import ac.common.world.gen.worldgenplatform;
import ac.common.world.world;
import ac.client.resources;

final class WorldGenCodeBuilder_GPU : WorldGenCodeBuilder {

public:
	enum PassType {
		pass2D,
		pass3D,
		passIterative
	}

	enum workgroupSize2D = 8;
	enum workgroupSize3D = 8;

	enum GLuint iterativePassSSBOItemCount = Chunk.surface * 16;

package:
	this(size_t passId, PassType passType, WorldGenPlatform_GPU platform) {
		platform_ = platform;
		game_ = platform.worldGen.world.game;
		passId_ = passId;
		passType_ = passType;

		glProgram_ = new GLProgram("worldGen.%s".format(passType == PassType.pass2D ? "2DPass" : "3DPass"), ["CHUNK_WIDTH" : Chunk.width.to!string]);
		glContext_ = new GLProgramContext(glProgram_);

		glContext_.setUniform("globalSeed", platform.worldGen.seed, false);

		glSSBO_ = glResourceManager.create(GLResourceType.buffer);
	}

	/// This constructor is only for passType == 2D
	/*static WorldGenCodeBuilder_GPU newIterativePass(size_t passId, WorldGenPlatform_GPU platform) {
		auto result = new WorldGenCodeBuilder_GPU(passId, platform);
		with (result) {
			passType_ = PassType.passIterative;
			atomicCounterOffset_ = (platform.iterativePassCounter_++) * cast(GLuint) GLuint.sizeof;

			glProgram_ = new GLProgram("worldGen.iterativePass", ["CHUNK_WIDTH" : Chunk.width.to!string]);
			glContext_ = new GLProgramContext(glProgram_);

			glSSBO_ = glResourceManager.create(GLResourceType.buffer);

			ssboFieldsDef_ ~= "ivec3 BUFPOS%s[%s];\n".format(passId_, iterativePassSSBOItemCount);
			ssboSize_ += 12 * iterativePassSSBOItemCount;

			code_ ~= "
				const ivec3 localPos = BUFPOS%s[ix];
				const ivec3 globalPos = chunkPos + localPos;
			".format(passId_);

			glContext_.setUniform("globalSeed", platform.worldGen.seed, false);
		}
		return result;
	}*/

public:
	void process(WorldVec chunkPos, GLTexture texture) {
		debug assert(finished_);

		glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_ATOMIC_COUNTER_BARRIER_BIT | GL_TEXTURE_UPDATE_BARRIER_BIT);

		glContext_.setUniform("chunkPos", chunkPos.to!Vec3I, false);
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, glSSBO_);

		if (passType_ == PassType.pass3D) {
			glBindImageTexture(0, texture.textureId, 0, GL_TRUE, 0, GL_WRITE_ONLY, GL_R16UI);
		}

		glContext_.bind();

		glBindBufferBase(GL_ATOMIC_COUNTER_BUFFER, 0, platform_.glAtomicCounterBuffer_);

		foreach (WorldGenCodeBuilder_GPU cb, GLint binding; input2DDataPasses_)
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, cb.glSSBO_);

		foreach (WorldGenCodeBuilder_GPU cb, GLint binding; connectedIterativePasses_)
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, cb.glSSBO_);

		if (passType_ == PassType.pass2D) {
			enum cnt = Chunk.width * 3 / workgroupSize2D;
			glDispatchCompute(cnt, cnt, 1);
		}
		else if (passType_ == PassType.pass3D) {
			enum cnt = Chunk.width * 3 / workgroupSize3D;
			glDispatchCompute(cnt, cnt, Chunk.height * 3 / workgroupSize3D);
		}

	}

	/*
	void processIterative(WorldVec chunkPos) {
		debug assert(finished_);
		debug assert(passType_ == PassType.passIterative);

		glMemoryBarrier(GL_ATOMIC_COUNTER_BARRIER_BIT);
		glState.bindBuffer(GL_ATOMIC_COUNTER_BUFFER, platform_.glAtomicCounterBuffer_);
		GLuint* itemCountPtr = cast(GLuint*) glMapBufferRange(GL_ATOMIC_COUNTER_BUFFER, atomicCounterOffset_, GLuint.sizeof, GL_MAP_READ_BIT | GL_MAP_WRITE_BIT);
		GLuint itemCount = *itemCountPtr;
		*itemCountPtr = 0;
		glUnmapBuffer(GL_ATOMIC_COUNTER_BUFFER);

		glContext_.setUniform("chunkPos", chunkPos.xy.to!Vec2I, false);
		glContext_.setUniform("itemCount", itemCount);
		glContext_.bind();

		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, glSSBO_);
		glBindBufferBase(GL_ATOMIC_COUNTER_BUFFER, 0, platform_.glAtomicCounterBuffer_);

		foreach (WorldGenCodeBuilder_GPU cb, GLint binding; input2DPasses_)
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, cb.glSSBO_);

		foreach (WorldGenCodeBuilder_GPU cb, GLint binding; connectedIterativePasses_)
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, binding, cb.glSSBO_);

		enum iterativeBufferWorkgroupSize = 64;
		glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT | GL_SHADER_IMAGE_ACCESS_BARRIER_BIT | GL_ATOMIC_COUNTER_BARRIER_BIT);
		glDispatchCompute((itemCount + iterativeBufferWorkgroupSize - 1) / iterativeBufferWorkgroupSize, 1, 1);
	}*/

public:
	override void finish() {
		assert(!finished_);
		finished_ = true;

		bindingsStr_ ~= ssboDefinition(0);
		glNamedBufferStorage(glSSBO_, ssboSize_, null, 0);
		calculatedVRAMUsage += ssboSize_;

		foreach (ip; input2DDataPasses_.byKeyValue)
			bindingsStr_ ~= ip.key.ssboDefinition(ip.value);

		foreach (ip; connectedIterativePasses_.byKeyValue)
			bindingsStr_ ~= ip.key.ssboDefinition(ip.value);

		glProgram_.define("__WORLDGEN_CODE__", code_.data.replace("\n", "\\\n"));
		glProgram_.define("__WORLDGEN_BINDINGS__", bindingsStr_.replace("\n", "\\\n"));

		immutable string[PassType] passPrograms = [ //
		PassType.pass3D : "worldgen3D", PassType.pass2D : "worldgen2D", PassType.passIterative : "worldgenIterative" //
		];
		glProgram_.addShaderFromFile(GLProgramShader.compute, "worldgen/%s.cs.glsl".format(passPrograms[passType_]));
		glProgram_.link();
	}

public:
	override Value constant(Block block) {
		return new GValue(VT.block, game_.blockId(block).to!string);
	}

	override Value constant(bool val) {
		return new GValue(VT.bool_, val.to!string);
	}

	override Value constant(int val) {
		return new GValue(VT.int_, val.to!string);
	}

	override Value constant(int x, int y) {
		return new GValue(VT.int2, "ivec2(%s, %s)".format(x, y));
	}

	override Value constant(float val) {
		return new GValue(VT.float_, val.to!string);
	}

	override Value vec2(Value a_, Value b_) {
		GValue a = cast(GValue) a_, b = cast(GValue) b_;
		VT commonType = commonType(a.type, b.type);
		VT resultType = vec2VT[commonType];

		string var = newVar();
		code_ ~= "const %s %s = %s(%s, %s);\n".format(VTstr[resultType], var, VTstr[resultType], a.to(commonType), b.to(commonType));
		return new GValue(resultType, var);
	}

	override Value var(Value x_) {
		GValue x = cast(GValue) x_;

		string var = newVar();
		code_ ~= "%s %s = %s;\n".format(VTstr[x.type], var, x);
		return new GValue(x.type, var, true);
	}

	override void set(Value var_, Value x) {
		GValue var = cast(GValue) var_;
		assert(var.isVar, "Only vars can be assigned to");
		code_ ~= "%s = %s;\n".format(var, x);
	}

	override Value air() {
		return new GValue(VT.block, "0");
	}

public:
	enum maxPerlinOctaveCount = 8;

	override Value perlin2D(uint firstOctaveSize, Value[] octaveWeights, uint seed) {
		assert(passType_ == PassType.pass2D, "perlin2D is only allowed for 2D passes");
		assert(firstOctaveSize >= workgroupSize2D, "Minimum perlin octave size is %s".format(workgroupSize2D));
		assert(popcnt(firstOctaveSize) == 1, "Octave size must be a power of 2");
		assert(octaveWeights.length > 0 && octaveWeights.length <= maxPerlinOctaveCount, "Octave count must be 0 < oc <= %s".format(maxPerlinOctaveCount));

		string var = newVar();
		code_ ~= "const vec3 %s = perlin2D(globalPos, %s, %s, %s, float[%s](%s));\n".format(var, seed, firstOctaveSize, octaveWeights.length, maxPerlinOctaveCount, octaveWeights.map!(x => x.toString).padRight("0", 8).joiner(","));

		glProgram_.define("USE_PERLIN", "1");

		return new GValue(VT.float3, var);
	}

	override Value perlin3D(uint firstOctaveSize, Value[] octaveWeights, uint seed) {
		assert(passType_ == PassType.pass3D, "perlin3D is only allowed for 3D passes");
		assert(firstOctaveSize >= workgroupSize3D, "Minimum perlin octave size is %s".format(workgroupSize3D));
		assert(popcnt(firstOctaveSize) == 1, "Octave size must be a power of 2");
		assert(octaveWeights.length > 0 && octaveWeights.length <= maxPerlinOctaveCount, "Octave count must be 0 < oc <= %s".format(maxPerlinOctaveCount));

		string var = newVar();
		code_ ~= "const float %s = perlin3D(globalPos, %s, %s, %s, float[%s](%s));\n".format(var, seed, firstOctaveSize, octaveWeights.length, maxPerlinOctaveCount, octaveWeights.map!(x => x.toString).padRight("0", 8).joiner(","));

		glProgram_.define("USE_PERLIN", "1");

		return new GValue(VT.float_, var);
	}

	enum maxVoronoi2DPointsPerRegion = 16;

	override Value voronoi2D(uint regionSize, uint maxPointsPerRegion, uint seed) {
		assert(passType_ == PassType.pass2D, "voronoi2D is only allowed for 2D passes");
		assert(regionSize >= workgroupSize2D, "minimum regionSize must is %s".format(workgroupSize2D));
		assert(popcnt(regionSize) == 1, "regionSize must be a power of 2");
		assert(maxPointsPerRegion > 0 && maxPointsPerRegion <= maxVoronoi2DPointsPerRegion, "maxPointsPerRegion must be 0 < maxPointsPerRegion <= %s".format(maxVoronoi2DPointsPerRegion));

		string var = newVar();
		code_ ~= "const vec4 %s = voronoi2D(globalPos, %s, %s, %s);\n".format(var, seed, regionSize, maxPointsPerRegion);

		glProgram_.define("USE_VORONOI", "1");
		glProgram_.define("VORONOI2D_MAX_POINTS_PER_REGION", maxVoronoi2DPointsPerRegion.to!string);

		return new GValue(VT.float4, var);
	}

	enum maxVoronoi3DPointsPerRegion = 8;

	override Value voronoi3D(uint regionSize, uint maxPointsPerRegion, float metricExp = 2, uint seed = __LINE__) {
		assert(passType_ == PassType.pass3D, "voronoi3D is only allowed for 3D passes");
		assert(popcnt(regionSize) == 1, "regionSize must be a power of 2");
		assert(maxPointsPerRegion > 0 && maxPointsPerRegion <= maxVoronoi3DPointsPerRegion, "maxPointsPerRegion must be 0 < maxPointsPerRegion <= %s".format(maxVoronoi3DPointsPerRegion));

		string var = newVar();
		code_ ~= "const ivec3 %s = voronoi3D(globalPos, %s, %s, %s, %s);\n".format(var, seed, regionSize, maxPointsPerRegion, metricExp);

		glProgram_.define("USE_VORONOI_3D", "1");
		glProgram_.define("VORONOI3D_MAX_POINTS_PER_REGION", maxVoronoi3DPointsPerRegion.to!string);

		return new GValue(VT.int3, var);
	}

	override Value randFloat01(uint seed) {
		string var = newVar();
		code_ ~= "const float %s = (hash(globalSeed ^ %s, globalPos) & 65535) / 65535.0f;\n".format(var, seed);
		return new GValue(VT.float_, var);
	}

	override Value randFloat01XY(uint seed) {
		string var = newVar();
		code_ ~= "const float %s = (hash(globalSeed ^ %s, globalPos.xy) & 65535) / 65535.0f;\n".format(var, seed);
		return new GValue(VT.float_, var);
	}

	override Value randFloat01XY(Value offset, uint seed) {
		string var = newVar();
		code_ ~= "const float %s = (hash(globalSeed ^ %s, globalPos.xy + ivec2(%s)) & 65535) / 65535.0f;\n".format(var, seed, offset);
		return new GValue(VT.float_, var);
	}

public:
	override void if_(Value cond_, void delegate() thenBranch, void delegate() elseBranch) {
		GValue cond = cast(GValue) cond_;
		assert(cond.type == VT.bool_);

		code_ ~= "if(%s) {\n".format(cond);
		thenBranch();
		code_ ~= "} else {\n";
		if (elseBranch)
			elseBranch();
		code_ ~= "}\n";
	}

	override void while_(lazy Value cond_, void delegate() loop) {
		code_ ~= "while(true) {\n";
		GValue cond = cast(GValue) cond_;
		assert(cond.type == VT.bool_);
		code_ ~= "if(!(%s)) break;".format(cond);
		loop();
		code_ ~= "}\n";
	}

	override void setBlock(Value result_) {
		assert(passType_ == PassType.pass3D, "Block return type is only valid for 3D passes");

		GValue result = cast(GValue) result_;
		assert(result.type == VT.block, "Return_ should be only called with block type");

		code_ ~= "imageStore(chunk, ivec3(gl_GlobalInvocationID), uvec4(%s, 0, 0, 0));\n".format(result);
	}

	override void set2DData(string field, Value value_) {
		GValue value = cast(GValue) value_;

		if (auto fld = field in ssboFields_)
			assert(*fld == value.type);
		else {
			ssboFields_[field] = value.type;
			ssboFieldsDef_ ~= "%s BUF%s_%s[%s][%s];\n".format(VTstr[value.type], passId_, field, Chunk.width * 3, Chunk.width * 3);
			ssboSize_ += Chunk.surface * 9 * VTsize[value.type];
		}

		code_ ~= "BUF%s_%s[gl_GlobalInvocationID.y][gl_GlobalInvocationID.x] = %s;\n".format(passId_, field, value);
	}
	/*
	override void iterativeCall2D(WorldGenCodeBuilder iterativePass_, Value z, Value[string] data) {
		assert(passType_ == PassType.pass2D);
		WorldGenCodeBuilder_GPU iterativePass = cast(WorldGenCodeBuilder_GPU) iterativePass_;

		// If the pass was not used set, prepare an image unit for it
		if (iterativePass !in connectedIterativePasses_) {
			GLint binding = ssboBindingCounter_++;
			connectedIterativePasses_[iterativePass] = binding;
		}

		foreach (string field, Value value_; data) {
			GValue value = cast(GValue) value_;
			if (auto it = field in iterativePass.ssboFields_)
				assert(*it == value.type);
			else {
				iterativePass.ssboFields_[field] = value.type;
				iterativePass.ssboSize_ += VTsize[value.type] * iterativePassSSBOItemCount;
			}
		}

		code_ ~= "{
			const uint ix = atomicCounterIncrement(BUFCTR%s);
			BUFPOS%s[ix] = ivec3(localPos.xy, %s);
			%s
		}".format(iterativePass.passId_, iterativePass.passId_, z, data.byKeyValue.map!(x => "BUF%s_%s[ix] = %s;\n".format(iterativePass.passId_, x.key, x.value)).joiner("\n"));
	}

	override void iterativeCall3D(WorldGenCodeBuilder iterativePass_, Value[string] data) {
		assert(passType_ == PassType.pass3D);
		WorldGenCodeBuilder_GPU iterativePass = cast(WorldGenCodeBuilder_GPU) iterativePass_;

		// If the pass was not used set, prepare an image unit for it
		if (iterativePass !in connectedIterativePasses_) {
			GLint binding = ssboBindingCounter_++;
			connectedIterativePasses_[iterativePass] = binding;
		}

		foreach (string field, Value value_; data) {
			GValue value = cast(GValue) value_;
			if (auto it = field in iterativePass.ssboFields_)
				assert(*it == value.type);
			else {
				iterativePass.ssboFields_[field] = value.type;
				iterativePass.ssboSize_ += VTsize[value.type] * iterativePassSSBOItemCount;
			}
		}

		code_ ~= "{
			uint ix = atomicCounterIncrement(BUFCTR%s);
			BUFPOS%s[ix] = localPos;
			%s
		}".format(iterativePass.passId_, iterativePass.passId_, data.byKeyValue.map!(x => "BUF%s_%s[ix] = %s;\n".format(iterativePass.passId_, x.key, x.value)));
	}*/

public:
	private VT pass2DDataType(WorldGenCodeBuilder pass_, string field) {
		WorldGenCodeBuilder_GPU pass = cast(WorldGenCodeBuilder_GPU) pass_;

		assert(pass && pass.platform_ is this.platform_, "Invalid argument passed");
		assert(pass.passId_ < this.passId_, "The pass you're referencing to must be registered before this pass");

		// If the pass was not used set, prepare an image unit for it
		if (pass !in input2DDataPasses_) {
			GLint binding = ssboBindingCounter_++;
			input2DDataPasses_[pass] = binding;
		}

		assert(field in pass.ssboFields_, "Pass does not have field %s".format(field));
		return pass.ssboFields_[field];
	}

	override Value pass2DData(WorldGenCodeBuilder pass_, string field) {
		WorldGenCodeBuilder_GPU pass = cast(WorldGenCodeBuilder_GPU) pass_;
		VT type = pass2DDataType(pass, field);

		string var = newVar();
		code_ ~= "const %s %s = BUF%s_%s[gl_GlobalInvocationID.y][gl_GlobalInvocationID.x];\n".format(VTstr[type], var, pass.passId_, field);
		return new GValue(type, var);
	}

	/// Retrieves result of a previous pass
	override Value pass2DData(WorldGenCodeBuilder pass_, string field, Value offset_) {
		WorldGenCodeBuilder_GPU pass = cast(WorldGenCodeBuilder_GPU) pass_;

		GValue offset = cast(GValue) offset_;
		assert(offset.type == VT.int2);

		VT type = pass2DDataType(pass, field);

		auto ox = offset.x;
		auto oy = offset.y;

		string var = newVar();
		code_ ~= "const %s %s = BUF%s_%s[clamp(int(gl_GlobalInvocationID.y) + %s, 0, CHUNK_WIDTH*3-1)][clamp(int(gl_GlobalInvocationID.x) + %s, 0, CHUNK_WIDTH*3-1)];\n".format(VTstr[type], var, pass.passId_, field, oy, ox);
		return new GValue(type, var);
	}

	override Value getBlock() {
		string var = newVar();
		code_ ~= "const uint %s = imageLoad(chunk, ivec3(gl_GlobalInvocationID)).r;".format(var);
		return new GValue(VT.block, var);
	}

	override Value getBlock(Value offsetX, Value offsetY, Value offsetZ) {
		string var = newVar();
		code_ ~= "const uint %s = imageLoad(chunk, ivec3(gl_GlobalInvocationID) + ivec3(%s, %s, %s)).r;".format(var, offsetX, offsetY, offsetZ);
		return new GValue(VT.block, var);
	}

	override Value iterativeData(string field) {
		assert(passType_ == PassType.passIterative);
		assert(field in ssboFields_);

		VT type = ssboFields_[field];

		string var = newVar();
		code_ ~= "const %s %s = BUF%s_%s[ix];\n".format(VTstr[type], var, passId_, field);
		return new GValue(type, var);
	}

public:
	override Value globalPos() {
		return new GValue(VT.int3, "globalPos");
	}

public:
	override Value compare(Value a, Value b, Comparison c) {
		immutable string[Comparison] op = [Comparison.eq : "==", Comparison.neq : "!=", Comparison.lt : "<", Comparison.lte : "<=", Comparison.gt : ">", Comparison.gte : ">="];
		string var = newVar();
		code_ ~= "const bool %s = %s %s %s;\n".format(var, a, op[c], b);
		return new GValue(VT.bool_, var);
	}

	override Value select(Value selA, Value a_, Value b_) {
		GValue a = cast(GValue) a_, b = cast(GValue) b_;
		VT resultType = commonType(a.type, b.type);

		string var = newVar();
		code_ ~= "const %s %s = %s ? %s : %s;\n".format(VTstr[resultType], var, selA, a.to(resultType), b.to(resultType));
		return new GValue(resultType, var);
	}

public:
	override Value and(Value a_, Value b_) {
		GValue a = cast(GValue) a_, b = cast(GValue) b_;
		assert(a.type == VT.bool_ && b.type == VT.bool_);

		string var = newVar();
		code_ ~= "const bool %s = %s && %s;\n".format(var, a, b);
		return new GValue(VT.bool_, var);
	}

	override Value not(Value a) {
		string var = newVar();
		code_ ~= "const bool %s = !%s;\n".format(var, a);
		return new GValue(VT.bool_, var);
	}

	override Value add(Value a, Value b) {
		return commonTypeOp(a, b, "%s + %s");
	}

	override Value sub(Value a, Value b) {
		return commonTypeOp(a, b, "%s - %s");
	}

	override Value mult(Value a, Value b) {
		return commonTypeOp(a, b, "%s * %s");
	}

	override Value div(Value a, Value b) {
		return commonTypeOp(a, b, "%s / %s");
	}

	override Value pow(Value a, Value b) {
		return commonTypeOp(a, b, "pow(%s, %s)");
	}

	override Value neg(Value a_) {
		GValue a = cast(GValue) a_;
		string var = newVar();

		code_ ~= "const %s %s = -%s;\n".format(VTstr[a.type], var, a);
		return new GValue(a.type, var);
	}

	override Value max(Value a, Value b) {
		return commonTypeOp(a, b, "max(%s, %s)");
	}

	override Value min(Value a, Value b) {
		return commonTypeOp(a, b, "min(%s, %s)");
	}

	override Value clamp(Value a_, Value min_, Value max_) {
		GValue a = cast(GValue) a_, min = cast(GValue) min_, max = cast(GValue) max_;
		VT resultType = commonType(commonType(a.type, min.type), max.type);

		string var = newVar();
		code_ ~= "const %s %s = clamp(%s, %s, %s);\n".format(VTstr[resultType], var, a.to(resultType), min.to(resultType), max.to(resultType));
		return new GValue(resultType, var);
	}

	override Value abs(Value a) {
		return unaryOp(a, "abs(%s)");
	}

	override Value floor(Value a) {
		return unaryOp(a, "floor(%s)");
	}

	override Value ceil(Value a) {
		return unaryOp(a, "ceil(%s)");
	}

	override Value round(Value a) {
		return unaryOp(a, "round(%s)");
	}

	override Value len(Value a_) {
		GValue a = cast(GValue) a_;
		VT resultType = componentVT[a.type];

		string var = newVar();
		code_ ~= "const %s %s = length(%s);\n".format(VTstr[resultType], var, a);
		return new GValue(resultType, var);
	}

public:
	override Value vectorComponent(Value vector_, uint component) {
		GValue vector = cast(GValue) vector_;
		string var = newVar();

		VT resultType = componentVT[vector.type];
		code_ ~= "%s %s = %s[%s];\n".format(VTstr[resultType], var, vector, component);
		return new GValue(resultType, var);
	}

	override Value toInt(Value val) {
		string var = newVar();
		code_ ~= "const int %s = int(%s);\n".format(var, val);
		return new GValue(VT.int_, var);
	}

private:
	string newVar() {
		return "var%s".format(varCounter_++);
	}

	Value commonTypeOp(Value a_, Value b_, string opStr) {
		GValue a = cast(GValue) a_, b = cast(GValue) b_;
		VT resultType = commonType(a.type, b.type);

		string var = newVar();
		code_ ~= "const %s %s = %s;\n".format(VTstr[resultType], var, opStr.format(a.to(resultType), b.to(resultType)));
		return new GValue(resultType, var);
	}

	Value unaryOp(Value a_, string opStr) {
		GValue a = cast(GValue) a_;

		string var = newVar();
		code_ ~= "const %s %s = %s;\n".format(VTstr[a.type], var, opStr.format(a));
		return new GValue(a.type, var);
	}

private:
	string ssboDefinition(int binding) {
		if (ssboFieldsDef_.length == 0)
			return null;

		string result = "layout(std430, binding = %s) buffer Buffer%s { %s };\n".format(binding, passId_, ssboFieldsDef_);

		if (passType_ == PassType.passIterative)
			result ~= "layout(binding = 0, offset = %s) uniform atomic_uint BUFCTR%s;\n".format(atomicCounterOffset_, passId_);

		return result;
	}

private:
	enum VT {
		block,

		bool_,

		int_,
		int2,
		int3,
		int4,

		float_,
		float2,
		float3,
		float4,

		_length
	}

	static immutable string[VT._length] VTstr = ["uint", "bool", "int", "ivec2", "ivec3", "ivec4", "float", "vec2", "vec3", "vec4"];
	static immutable size_t[VT._length] VTsize = [4, 4, 4, 8, 12, 16, 4, 8, 12, 16];
	static immutable VT[VT] componentVT, vec2VT, vec3VT, vec4VT;

	shared static this() {
		componentVT = [ //
		VT.int2 : VT.int_, VT.int3 : VT.int_, VT.int4 : VT.int_, //
			VT.float2 : VT.float_, VT.float3 : VT.float_, VT.float4 : VT.float_ //
			];
		vec2VT = [VT.float_ : VT.float2, VT.int_ : VT.int2];
		vec3VT = [VT.float_ : VT.float3, VT.int_ : VT.int3];
		vec4VT = [VT.float_ : VT.float4, VT.int_ : VT.int4];
	}

	final class GValue : Value {

	public:
		this(VT type, string val, bool isVar = false) {
			this.val = val;
			this.type = type;
			this.isVar = isVar;
		}

	public:
		string to(VT t) {
			if (t == type)
				return val;

			return "%s(%s)".format(VTstr[t], val);
		}

	public:
		override string toString() const {
			return val;
		}

	public:
		string val;
		VT type;
		bool isVar;

	}

	static VT commonType(VT a, VT b) {
		if (a == b)
			return a;

		if ((a == VT.int_ || a == VT.float_) && (b == VT.int_ || b == VT.float_))
			return VT.float_;

		assert(0, "%s and %s are not compatible".format(a, b));
	}

private:
	Game game_;
	WorldGenPlatform_GPU platform_;
	PassType passType_;
	Appender!string code_;
	string bindingsStr_;
	size_t varCounter_;
	size_t passId_;
	bool finished_;

private:
	GLuint atomicCounterOffset_; ///< used in iterative passes
	GLint ssboBindingCounter_ = 1; ///< Zero = output binding
	GLint glSSBO_; ///< SSBO storing the result (in 2D pass) or the input data (in iterative pass)
	size_t ssboSize_;
	VT[string] ssboFields_; ///< key: variable name, value: type; used in 2D pass and iterative pass
	string ssboFieldsDef_; /// SSBO definition string (so that ssboFields are in the order same order as they were requested)

private:
	GLProgram glProgram_;
	GLProgramContext glContext_;
	GLint[WorldGenCodeBuilder_GPU] input2DDataPasses_, connectedIterativePasses_; ///< value: binding id

}
