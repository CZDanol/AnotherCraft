module ac.common.world.gen.worldgencodebuilder;

import std.format;
import std.meta;
import std.range;

import ac.common.block.block;
import ac.common.world.gen.worldgen;

abstract class WorldGenCodeBuilder {

public:
	enum Comparison {
		eq,
		neq,
		lt,
		lte,
		gt,
		gte
	}

public:
	abstract void finish();

public:
	/// Constant value
	abstract Value constant(Block block);
	abstract Value constant(bool val);
	abstract Value constant(int val);
	abstract Value constant(int x, int y);
	abstract Value constant(float val);

	abstract Value vec2(Value x, Value y);

	/// Creates a variable (otherwise assign is not allowed)
	abstract Value var(Value x);

	/// Set variable var to value val
	abstract void set(Value var, Value val);

	alias c = constant;

	abstract Value air();

public:
	/// Generates a 2D perlin noise (-1 .. 1), returns float3, y and z is the gradient
	/// Only usable in 2D passes
	abstract Value perlin2D(uint firstOctaveSize, Value[] octaveWeights, uint seed = __LINE__);

	/// Generates a 3D perlin noise (-1 .. 1)
	/// Only usable in 3D passes
	abstract Value perlin3D(uint firstOctaveSize, Value[] octaveWeights, uint seed = __LINE__);

	/// Returns float4 with (distance to closest point 0..1, dist to closest/dist to second closest, offsetX, offsetY)
	/// Only usable in 2D passes
	abstract Value voronoi2D(uint regionSize, uint maxPointsPerRegion, uint seed = __LINE__);

	/// Returns int3 with offset to the closest voronoi 3F point
	abstract Value voronoi3D(uint regionSize, uint maxPointsPerRegion, float metricExp = 2, uint seed = __LINE__);

	abstract Value randFloat01(uint seed = __LINE__);

	/// The value is same for all z
	abstract Value randFloat01XY(uint seed = __LINE__);

	abstract Value randFloat01XY(Value offset, uint seed = __LINE__);

	final Value randBool(Value prob, uint seed = __LINE__) {
		return lt(randFloat01(seed), prob);
	}

public:
	abstract void if_(Value cond, void delegate() thenBranch, void delegate() elseBranch = null);
	abstract void while_(lazy Value cond, void delegate() loop);

	abstract void setBlock(Value result); ///< 3D passes only, sets the current block to the given value

	abstract void set2DData(string field, Value value); ///< 2D & 3D passes, data is stored only as 2D (you should not write from the blocks on different heights)
	/*
	abstract void iterativeCall2D(WorldGenCodeBuilder iterativePass, Value z, Value[string] data);
	abstract void iterativeCall3D(WorldGenCodeBuilder iterativePass, Value[string] data);*/

public:
	/// Retrieves result of a previous pass (2D or 3D)
	abstract Value pass2DData(WorldGenCodeBuilder pass, string field);

	/// Retrieves result of a previous pass (2D or 3D)
	/// Offset is ivec2
	abstract Value pass2DData(WorldGenCodeBuilder pass, string field, Value offset);

	/// Only for 3D passes. Returns block at the current position from previous pass
	abstract Value getBlock();

	/// Only for 3D passes. Returns block at the current position from previous pass
	abstract Value getBlock(Value offsetX, Value offsetY, Value offsetZ);

	/// Only usable in iterative pass. Returns #field data for the current iterative call
	abstract Value iterativeData(string field);

public:
	abstract Value globalPos();

public:
	abstract Value compare(Value a, Value b, Comparison c);

	pragma(inline) auto eq(T)(T a, T b) {
		return compare(a, b, Comparison.eq);
	}

	pragma(inline) auto neq(T)(T a, T b) {
		return not(eq(a, b));
	}

	pragma(inline) auto lt(T)(T a, T b) {
		return compare(a, b, Comparison.lt);
	}

	pragma(inline) auto lte(T)(T a, T b) {
		return compare(a, b, Comparison.lte);
	}

	pragma(inline) auto gt(T)(T a, T b) {
		return compare(a, b, Comparison.gt);
	}

	pragma(inline) auto gte(T)(T a, T b) {
		return compare(a, b, Comparison.gte);
	}

	abstract Value select(Value selA, Value a, Value b);

	Value multiSelect(Args...)(Args args) {
		Value result = args[$ - 1];

		static foreach (i; iota(0, args.length - 1, 2))
			result = select(args[$ - 3 - i], args[$ - 2 - i], result);

		return result;
	}

public:
	abstract Value and(Value a, Value b);
	abstract Value not(Value a);

	abstract Value add(Value a, Value b);
	abstract Value sub(Value a, Value b);
	abstract Value mult(Value a, Value b);
	abstract Value div(Value a, Value b);

	abstract Value pow(Value a, Value b);

	abstract Value neg(Value a);

	abstract Value max(Value a, Value b);
	abstract Value min(Value a, Value b);
	abstract Value clamp(Value a, Value min, Value max);

	abstract Value abs(Value a);
	abstract Value floor(Value a);
	abstract Value ceil(Value a);
	abstract Value round(Value a);

	abstract Value len(Value vec);

public:
	final Value clamp01(Value a) {
		return clamp(a, c(0), c(1));
	}

	Value maxv(Value a, Value[] vs...) {
		Value result = a;
		foreach (v; vs)
			result = max(result, v);
		return result;
	}

	Value minv(Value a, Value[] vs...) {
		Value result = a;
		foreach (v; vs)
			result = min(result, v);
		return result;
	}

public:
	abstract Value vectorComponent(Value vector, uint component);

	abstract Value toInt(Value val);

protected:
	abstract class Value {

	public:
		Value opBinary(string op : "+")(Value other) {
			return add(this, other);
		}

		Value opBinary(string op : "-")(Value other) {
			return sub(this, other);
		}

		Value opBinary(string op : "*")(Value other) {
			return mult(this, other);
		}

		Value opBinary(string op : "/")(Value other) {
			return div(this, other);
		}

		Value opUnary(string op : "-")() {
			return neg(this);
		}

		Value opBinary(string op)(float other) {
			return opBinary!op(c(other));
		}

		Value opBinaryRight(string op)(float other) {
			return c(other).opBinary!op(this);
		}

		Value opBinary(string op)(int other) {
			return opBinary!op(c(other));
		}

		Value opBinaryRight(string op)(int other) {
			return c(other).opBinary!op(this);
		}

	public:
		Value opBinary(string s : "&")(Value other) {
			return and(this, other);
		}

	public:
		final Value x() {
			return vectorComponent(this, 0);
		}

		final Value y() {
			return vectorComponent(this, 1);
		}

		final Value z() {
			return vectorComponent(this, 2);
		}

		final Value w() {
			return vectorComponent(this, 3);
		}

	}

}

uint fhash(uint x) {
	import std.stdio;

	uint hash = 1_315_423_911;
	hash ^= ((hash << 5) + (x & 0xff) + (hash >> 2));
	hash ^= ((hash << 5) + ((x >> 8) & 0xff) + (hash >> 2));
	hash ^= ((hash << 5) + ((x >> 16) & 0xff) + (hash >> 2));
	hash ^= ((hash << 5) + ((x >> 24) & 0xff) + (hash >> 2));
	writefln("%s -> %s", x, hash);
	return hash;
}
