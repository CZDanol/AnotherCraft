module ac.common.math.vector;

import std.algorithm;
import std.conv;
import std.format;
import std.functional;
import std.math;
import std.meta;
import std.range;
import std.traits;
import std.string;
import std.typecons;

alias Vec2F = Vector!(float, 2);
alias Vec3F = Vector!(float, 3);
alias Vec4F = Vector!(float, 4);

alias Vec2I = Vector!(int, 2);
alias Vec3I = Vector!(int, 3);
alias Vec4I = Vector!(int, 4);

alias Vec2U = Vector!(uint, 2);
alias Vec3U = Vector!(uint, 3);
alias Vec4U = Vector!(uint, 4);

alias Vec2U8 = Vector!(ubyte, 2);
alias Vec3U8 = Vector!(ubyte, 3);
alias Vec4U8 = Vector!(ubyte, 4);

alias Vec2U16 = Vector!(ushort, 2);
alias Vec3U16 = Vector!(ushort, 3);
alias Vec4U16 = Vector!(ushort, 4);

struct Vector(T_, uint D_, string cookie = "") {

public:
	template isSubcomponent(X) {
		static if (is(X : T) || is(X == int))
			enum isSubcomponent = true;
		else static if (is(X : Vector!(T, D2, cookie2), uint D2, string cookie2))
			enum isSubcomponent = true;
		else
			enum isSubcomponent = false;
	}

public:
	alias Vec = typeof(this);
	alias T = T_;
	enum D = D_;
	enum length = D;

	static if (__traits(compiles, T.min)) {
		enum max = Vec(T.max);
		enum min = Vec(T.min);
	}

public:
	this(Repeat!(D, T) vals) {
		static foreach (i; 0 .. D)
			val[i] = vals[i];
	}

	static if (D > 1) {
		this(T v) {
			val[] = v;
		}
	}

	this(Args...)(Args args) if (allSatisfy!(isSubcomponent, Args)) {
		size_t dim;
		static foreach (arg; args) {
			{
				alias Arg = typeof(arg);
				static if (is(Arg : T))
					val[dim++] = arg;

				else static if (is(Arg == int))
					val[dim++] = cast(T) arg;

				else static if (is(Arg : Vector!(T, D2, cookie2), uint D2, string cookie2)) {
					val[dim .. dim + D2] = arg.val;
					dim += D2;
				}
				else
					static assert(0, Arg.stringof);
			}
		}
	}

public:
	static if (isSigned!T)
		Vec abs() const {
			Vec result;
			static foreach (i; 0 .. D)
				result[i] = std.math.abs(this[i]);

			return result;
		}

	static if (is(T == float))
		Vec pow(float exp) const {
			Vec result;
			static foreach (i; 0 .. D)
				result[i] = std.math.pow(this[i], exp);

			return result;
		}

	static if (is(T == float) && D == 4)
		Vec3F perspectiveNormalized() const {
			return this.xyz / this.w;
		}

	static if (is(T == float))
		Vec normalized() const {
			return this / vecLength;
		}

	static if (is(T == float))
		T vecLength() const {
			T result = 0;
			static foreach (i; 0 .. D)
				result += this[i] * this[i];

			return sqrt(result);
		}

	static if (is(T == float))
		T distanceTo(Vec other) const {
			return (this - other).vecLength;
		}

	T vecLengthSqr() const {
		T result = 0;
		static foreach (i; 0 .. D)
			result += this[i] * this[i];

		return result;
	}

public:
	pragma(inline) ref T opIndex(size_t i) {
		return val[i];
	}

	pragma(inline) T opIndex(size_t i) const {
		return val[i];
	}

public:
	// vec +-*/% vec
	Vec opBinary(string op)(Vec other) const  //
	if (["+", "-", "*", "/", "%"].canFind(op)) //
	{
		Vec result;
		static foreach (i; 0 .. D)
			mixin("result[i] = cast(T)(this[i] %s other[i]);".format(op));

		return result;
	}

	// vec +-*/% const
	Vec opBinary(string op)(T v) const  //
	if (["+", "-", "*", "/", "%"].canFind(op)) //
	{
		Vec result;
		static foreach (i; 0 .. D)
			mixin("result[i] = cast(T)(this[i] %s v);".format(op));

		return result;
	}

	// const +-*/% vec
	Vec opBinaryRight(string op)(T v) const  //
	if (["+", "-", "*", "/", "%"].canFind(op)) //
	{
		Vec result;
		static foreach (i; 0 .. D)
			mixin("result[i] = cast(T)(v %s this[i]);".format(op));

		return result;
	}

	// vec +-*/% vec
	void opOpAssign(string op)(Vec other) //
	if (["+", "-", "*", "/", "%"].canFind(op)) //
	{
		static foreach (i; 0 .. D)
			mixin("this[i] %s= other[i];".format(op));
	}

	// vec +-*/% const
	void opOpAssign(string op)(T v) //
	if (["+", "-", "*", "/", "%"].canFind(op)) //
	{
		static foreach (i; 0 .. D)
			mixin("this[i] %s= v;".format(op));
	}

	static if (isSigned!T)
		Vec opUnary(string op : "-")() const {
			Vec ret = this;
			foreach (i; 0 .. D)
				ret.val[i] *= -1;

			return ret;
		}

public:
	auto opCast(Vec2 : Vector!(T2, D, cookie2), T2, string cookie2)() const {
		Vec2 result;
		foreach (i; 0 .. D)
			result[i] = cast(T2) val[i];

		return result;
	}

	string toString() const {
		string x;
		foreach (i; 1 .. D)
			x ~= ",%s".format(val[i]);

		return "(%s%s)".format(val[0], x);
	}

	pragma(inline) bool opEquals(Vec : Vector!(T, D, cookie2), string cookie2)(Vec other) const {
		return val == other.val;
	}

	extern (D) size_t toHash() const nothrow @safe {
		return val.hashOf;
	}

	static if (is(T == float))
		bool isValid() {
			static foreach (i; 1 .. D) {
				if (val[i].isNaN || val[i].isInfinity)
					return false;
			}

			return true;
		}

public:
	T[D] val = 0;

public:
	enum componentLetters = "xyzwrgba";
	enum componentIndexes = [0, 1, 2, 3, 0, 1, 2, 3];

	enum extendedComponentLetters = componentLetters ~ "OI";
	enum extendedComponentIndexes = componentIndexes ~ [-1, -2];

	pragma(inline) ref T opDispatch(string s)() if (s.length == 1 && componentLetters.canFind(s[0])) {
		enum ix = componentIndexes[componentLetters.indexOf(s[0])];
		return val[ix];
	}

	pragma(inline) T opDispatch(string s)() const if (s.length == 1 && componentLetters.canFind(s[0])) {
		enum ix = componentIndexes[componentLetters.indexOf(s[0])];
		return val[ix];
	}

	auto opDispatch(string s)() const if (s.length > 1 && s.each!(ch => extendedComponentLetters.canFind(ch))) {
		Vector!(T, s.length) result;
		static foreach (i, ch; s) {
			{
				enum ix = extendedComponentIndexes[extendedComponentLetters.indexOf(ch)];
				static if (ix >= 0)
					result[i] = val[ix];
				else static if (ix == -1)
					result[i] = 0;
				else static if (ix == -2)
					result[i] = 1;
				else
					static assert(0);
			}
		}
		return result;
	}

	void opDispatch(string s)(Vector!(T, s.length, cookie) set) if (s.length > 1 && s.each!(ch => componentLetters.canFind(ch))) {
		static foreach (i, ch; s)
			val[componentIndexes[componentLetters.indexOf(ch)]] = set.val[i];
	}

}

bool all(alias pred, Vec : Vector!(T, D, cookie), T, uint D, string cookie)(const Vec v1, const Vec v2) {
	static foreach (i; 0 .. D) {
		if (!binaryFun!(pred)(v1[i], v2[i]))
			return false;
	}

	return true;
}

bool any(alias pred, Vec : Vector!(T, D, cookie), T, uint D, string cookie)(const Vec v1, const Vec v2) {
	static foreach (i; 0 .. D) {
		if (binaryFun!(pred)(v1[i], v2[i]))
			return true;
	}

	return false;
}

Vec map(alias pred, Vec : Vector!(T, D, cookie), T, uint D, string cookie)(const Vec v) {
	Vec result;
	static foreach (i; 0 .. D)
		result[i] = cast(T) unaryFun!(pred)(v[i]);

	return result;
}

Vec combine(alias pred, Vec : Vector!(T, D, cookie), T, uint D, string cookie)(const Vec v1, const Vec v2) {
	Vec result;
	static foreach (i; 0 .. D)
		result[i] = cast(T) binaryFun!(pred)(v1[i], v2[i]);

	return result;
}

Vec combine(alias pred, Vec : Vector!(T, D, cookie), T, uint D, string cookie)(const Vec v1, T p) {
	Vec result;
	static foreach (i; 0 .. D)
		result[i] = cast(T) binaryFun!(pred)(v1[i], p);

	return result;
}
