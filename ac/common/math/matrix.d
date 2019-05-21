module ac.common.math.matrix;

import std.math;
import std.format;

import ac.common.math.vector;

struct Matrix {

public:
	alias T = float;
	alias TI = float;

	// dfmt off
	enum : ubyte {
		xx, yx, zx, wx,
		xy, yy, zy, wy,
		xz, yz, zz, wz,
		xw, yw, zw, ww
	}
	// dfmt on

public:
	float[16] m = [ //
	1, 0, 0, 0, //
		0, 1, 0, 0, //
		0, 0, 1, 0, //
		0, 0, 0, 1 //
		];

public:
	this(TI[16] m...) {
		this.m = m;
	}

	/*float[16] toGL() const {
		float[16] result;
		foreach (x; 0 .. 16)
			result[x] = cast(float) m[x];

		return result;
	}*/

	static Matrix identity() {
		return Matrix();
	}

	static Matrix translation(T x, T y, T z = 0) {
		return Matrix( //
				1, 0, 0, 0, //
				0, 1, 0, 0, //
				0, 0, 1, 0, //
				x, y, z, 1 //
				);
	}

	static Matrix translation(Vector!(T, 2) vec) {
		return Matrix( //
				1, 0, 0, 0, //
				0, 1, 0, 0, //
				0, 0, 1, 0, //
				vec.x, vec.y, 0, 1 //
				);
	}

	static Matrix translation(Vector!(T, 3) vec) {
		return Matrix( //
				1, 0, 0, 0, //
				0, 1, 0, 0, //
				0, 0, 1, 0, //
				vec.x, vec.y, vec.z, 1 //
				);
	}

	static Matrix rotationX(float angle) {
		float asin = sin(angle), acos = cos(angle);
		return Matrix( //
				1, 0, 0, 0, //
				0, acos, asin, 0, //
				0, -asin, acos, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationXSin(float asin) {
		float acos = sqrt(1 - asin * asin);
		return Matrix( //
				1, 0, 0, 0, //
				0, acos, asin, 0, //
				0, -asin, acos, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationY(float angle) {
		float asin = sin(angle), acos = cos(angle);
		return Matrix( //
				acos, 0, asin, 0, //
				0, 1, 0, 0, //
				-asin, 0, acos, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationYSin(float asin) {
		float acos = sqrt(1 - asin * asin);
		return Matrix( //
				acos, 0, asin, 0, //
				0, 1, 0, 0, //
				-asin, 0, acos, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationZ(float angle) {
		float asin = sin(angle), acos = cos(angle);
		return Matrix( //
				acos, asin, 0, 0, //
				-asin, acos, 0, 0, //
				0, 0, 1, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationX90() {
		return Matrix( //
				1, 0, 0, 0, //
				0, 0, 1, 0, //
				0, -1, 0, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix rotationX270() {
		return Matrix( //
				1, 0, 0, 0, //
				0, 0, -1, 0, //
				0, 1, 0, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix scaling(T u) {
		return Matrix( //
				u, 0, 0, 0, //
				0, u, 0, 0, //
				0, 0, u, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix scaling(T x, T y, T z = 1) {
		return Matrix( //
				x, 0, 0, 0, //
				0, y, 0, 0, //
				0, 0, z, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix scaling(Vector!(T, 2) v) {
		return Matrix( //
				v.x, 0, 0, 0, //
				0, v.y, 0, 0, //
				0, 0, 1, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix scaling(Vector!(T, 3) v) {
		return Matrix( //
				v.x, 0, 0, 0, //
				0, v.y, 0, 0, //
				0, 0, v.z, 0, //
				0, 0, 0, 1 //
				);
	}

	static Matrix orthogonal(Vec2F screenSize, float near = 0, float far = 10_000) {
		return Matrix( //
				2f / screenSize.x, 0, 0, 0, //
				0, -2f / screenSize.y, 0, 0, //
				0, 0, 2.0f / (far - near), 0, //
				-1, 1, -(far + near) / (far - near), 1 //
				);
	}

	static Matrix orthogonalCentered(Vec2F screenSize, float near = 0, float far = 10_000) {
		return Matrix( //
				2f / screenSize.x, 0, 0, 0, //
				0, -2f / screenSize.y, 0, 0, //
				0, 0, 2.0f / (far - near), 0, //
				0, 0, -(far + near) / (far - near), 1 //
				);
	}

	static Matrix orthogonalCentered_infFar(Vec2F screenSize) {
		return Matrix( //
				2f / screenSize.x, 0, 0, 0, //
				0, -2f / screenSize.y, 0, 0, //
				0, 0, 1, 1, //
				0, 0, 0, 1 //
				);
	}

	static Matrix perspective(Vec2F screenSize, float fovy = 0.3 * PI, float near = 1, float far = 10_000) {
		const float aspect = screenSize.x / screenSize.y;
		const float f = 1 / tan(fovy / 2);

		return Matrix( //
				f / aspect, 0, 0, 0, //
				0, f, 0, 0, //
				0, 0, (far + near) / (near - far), -1, //
				0, 0, 2 * far * near / (near - far), 0 //
				);
	}

	static Matrix perspective_infFar(Vec2F screenSize, float fovy = 0.3 * PI, float near = 1) {
		const float aspect = screenSize.x / screenSize.y;
		const float f = 1 / tan(fovy / 2);

		return Matrix( //
				f / aspect, 0, 0, 0, //
				0, f, 0, 0, //
				0, 0, -1, -1, //
				0, 0, -near - 1, -near + 1 //
				);
	}

public:
	Matrix inverted() const {
		/* stolen from MESA */
		/*Matrix inv;
		float det;
		inv.m[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10];
		inv.m[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10];
		inv.m[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9];
		inv.m[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9];
		inv.m[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10];
		inv.m[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10];
		inv.m[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9];
		inv.m[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9];
		inv.m[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6];
		inv.m[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6];
		inv.m[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5];
		inv.m[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5];
		inv.m[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6];
		inv.m[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6];
		inv.m[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5];
		inv.m[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5];
		det = m[0] * inv.m[0] + m[1] * inv.m[4] + m[2] * inv.m[8] + m[3] * inv.m[12];
		if (det == 0)
			return Matrix();
		det = 1.0 / det;
		foreach (i; 0 .. 16)
			inv.m[i] = inv.m[i] * det;
		return inv;*/

		double det;
		double[16] res;
		res[0] = double(m[5]) * double(m[10]) * double(m[15]) - double(m[5]) * double(m[11]) * double(m[14]) - double(m[9]) * double(m[6]) * double(m[15]) + double(m[9]) * double(m[7]) * double(m[14]) + double(m[13]) * double(m[6]) * double(m[11]) - double(m[13]) * double(m[7]) * double(m[10]);
		res[4] = -double(m[4]) * double(m[10]) * double(m[15]) + double(m[4]) * double(m[11]) * double(m[14]) + double(m[8]) * double(m[6]) * double(m[15]) - double(m[8]) * double(m[7]) * double(m[14]) - double(m[12]) * double(m[6]) * double(m[11]) + double(m[12]) * double(m[7]) * double(m[10]);
		res[8] = double(m[4]) * double(m[9]) * double(m[15]) - double(m[4]) * double(m[11]) * double(m[13]) - double(m[8]) * double(m[5]) * double(m[15]) + double(m[8]) * double(m[7]) * double(m[13]) + double(m[12]) * double(m[5]) * double(m[11]) - double(m[12]) * double(m[7]) * double(m[9]);
		res[12] = -double(m[4]) * double(m[9]) * double(m[14]) + double(m[4]) * double(m[10]) * double(m[13]) + double(m[8]) * double(m[5]) * double(m[14]) - double(m[8]) * double(m[6]) * double(m[13]) - double(m[12]) * double(m[5]) * double(m[10]) + double(m[12]) * double(m[6]) * double(m[9]);
		res[1] = -double(m[1]) * double(m[10]) * double(m[15]) + double(m[1]) * double(m[11]) * double(m[14]) + double(m[9]) * double(m[2]) * double(m[15]) - double(m[9]) * double(m[3]) * double(m[14]) - double(m[13]) * double(m[2]) * double(m[11]) + double(m[13]) * double(m[3]) * double(m[10]);
		res[5] = double(m[0]) * double(m[10]) * double(m[15]) - double(m[0]) * double(m[11]) * double(m[14]) - double(m[8]) * double(m[2]) * double(m[15]) + double(m[8]) * double(m[3]) * double(m[14]) + double(m[12]) * double(m[2]) * double(m[11]) - double(m[12]) * double(m[3]) * double(m[10]);
		res[9] = -double(m[0]) * double(m[9]) * double(m[15]) + double(m[0]) * double(m[11]) * double(m[13]) + double(m[8]) * double(m[1]) * double(m[15]) - double(m[8]) * double(m[3]) * double(m[13]) - double(m[12]) * double(m[1]) * double(m[11]) + double(m[12]) * double(m[3]) * double(m[9]);
		res[13] = double(m[0]) * double(m[9]) * double(m[14]) - double(m[0]) * double(m[10]) * double(m[13]) - double(m[8]) * double(m[1]) * double(m[14]) + double(m[8]) * double(m[2]) * double(m[13]) + double(m[12]) * double(m[1]) * double(m[10]) - double(m[12]) * double(m[2]) * double(m[9]);
		res[2] = double(m[1]) * double(m[6]) * double(m[15]) - double(m[1]) * double(m[7]) * double(m[14]) - double(m[5]) * double(m[2]) * double(m[15]) + double(m[5]) * double(m[3]) * double(m[14]) + double(m[13]) * double(m[2]) * double(m[7]) - double(m[13]) * double(m[3]) * double(m[6]);
		res[6] = -double(m[0]) * double(m[6]) * double(m[15]) + double(m[0]) * double(m[7]) * double(m[14]) + double(m[4]) * double(m[2]) * double(m[15]) - double(m[4]) * double(m[3]) * double(m[14]) - double(m[12]) * double(m[2]) * double(m[7]) + double(m[12]) * double(m[3]) * double(m[6]);
		res[10] = double(m[0]) * double(m[5]) * double(m[15]) - double(m[0]) * double(m[7]) * double(m[13]) - double(m[4]) * double(m[1]) * double(m[15]) + double(m[4]) * double(m[3]) * double(m[13]) + double(m[12]) * double(m[1]) * double(m[7]) - double(m[12]) * double(m[3]) * double(m[5]);
		res[14] = -double(m[0]) * double(m[5]) * double(m[14]) + double(m[0]) * double(m[6]) * double(m[13]) + double(m[4]) * double(m[1]) * double(m[14]) - double(m[4]) * double(m[2]) * double(m[13]) - double(m[12]) * double(m[1]) * double(m[6]) + double(m[12]) * double(m[2]) * double(m[5]);
		res[3] = -double(m[1]) * double(m[6]) * double(m[11]) + double(m[1]) * double(m[7]) * double(m[10]) + double(m[5]) * double(m[2]) * double(m[11]) - double(m[5]) * double(m[3]) * double(m[10]) - double(m[9]) * double(m[2]) * double(m[7]) + double(m[9]) * double(m[3]) * double(m[6]);
		res[7] = double(m[0]) * double(m[6]) * double(m[11]) - double(m[0]) * double(m[7]) * double(m[10]) - double(m[4]) * double(m[2]) * double(m[11]) + double(m[4]) * double(m[3]) * double(m[10]) + double(m[8]) * double(m[2]) * double(m[7]) - double(m[8]) * double(m[3]) * double(m[6]);
		res[11] = -double(m[0]) * double(m[5]) * double(m[11]) + double(m[0]) * double(m[7]) * double(m[9]) + double(m[4]) * double(m[1]) * double(m[11]) - double(m[4]) * double(m[3]) * double(m[9]) - double(m[8]) * double(m[1]) * double(m[7]) + double(m[8]) * double(m[3]) * double(m[5]);
		res[15] = double(m[0]) * double(m[5]) * double(m[10]) - double(m[0]) * double(m[6]) * double(m[9]) - double(m[4]) * double(m[1]) * double(m[10]) + double(m[4]) * double(m[2]) * double(m[9]) + double(m[8]) * double(m[1]) * double(m[6]) - double(m[8]) * double(m[2]) * double(m[5]);
		det = m[0] * res[0] + m[1] * res[4] + m[2] * res[8] + m[3] * res[12];
		if (det == 0)
			return Matrix();

		det = 1.0 / det;

		Matrix inv;
		foreach (i; 0 .. 16)
			inv.m[i] = cast(TI)(res[i] * det);

		return inv;
	}

	Matrix translated(Vec3F offset) const {
		Matrix result = this;
		result.m[xw] += offset.x * m[xx] + offset.y * m[xy] + offset.z * m[xz];
		result.m[yw] += offset.x * m[yx] + offset.y * m[yy] + offset.z * m[yz];
		result.m[zw] += offset.x * m[zx] + offset.y * m[zy] + offset.z * m[zz];
		result.m[ww] += offset.x * m[wx] + offset.y * m[wy] + offset.z * m[wz];
		return result;
	}

	Matrix translated(Vec2F offset) const {
		Matrix result = this;
		result.m[xw] += offset.x * m[xx] + offset.y * m[xy];
		result.m[yw] += offset.x * m[yx] + offset.y * m[yy];
		result.m[zw] += offset.x * m[zx] + offset.y * m[zy];
		result.m[ww] += offset.x * m[wx] + offset.y * m[wy];
		return result;
	}

	Matrix translatedZ(T offset) const {
		Matrix result = this;
		result.m[xw] += offset * m[xz];
		result.m[yw] += offset * m[yz];
		result.m[zw] += offset * m[zz];
		result.m[ww] += offset * m[wz];
		return result;
	}

public:
	void translate(Vec3F offset) {
		m[xw] += offset.x * m[xx] + offset.y * m[xy] + offset.z * m[xz];
		m[yw] += offset.x * m[yx] + offset.y * m[yy] + offset.z * m[yz];
		m[zw] += offset.x * m[zx] + offset.y * m[zy] + offset.z * m[zz];
		m[ww] += offset.x * m[wx] + offset.y * m[wy] + offset.z * m[wz];
	}

	void translateZ(T offset) {
		m[xw] += offset * m[xz];
		m[yw] += offset * m[yz];
		m[zw] += offset * m[zz];
		m[ww] += offset * m[wz];
	}

public:
	bool isBoxInFrustum(Vec3F v1, Vec3F v2) const {
		ubyte flags;

		static foreach (i; 0 .. 8) {
			{
				const Vec4F px = this * Vec3F(mixin("v%s".format((i & 1) + 1)).x, mixin("v%s".format(((i >> 1) & 1) + 1)).y, mixin("v%s".format(((i >> 2) & 1) + 1)).z);
				const Vec3F p = px.perspectiveNormalized;
				const ubyte pw = (cast(ubyte)(px.w < 0)) * 0b11110;
				flags |= (((p.z <= 1) << 0) | ((p.x <= 1) << 1) | ((p.x >= -1) << 2) | ((p.y <= 1) << 3) | ((p.y >= -1) << 4)) ^ pw;
			}
		}

		return flags  == 0b11111;
	}

public:
	Matrix opBinary(string s : "*")(Matrix mat) const {
		Matrix result = void;
		TI tmp;
		static foreach (x; 0 .. 4) {
			static foreach (y; 0 .. 4) {
				tmp = 0;
				static foreach (i; 0 .. 4)
					tmp += m[i * 4 + y] * mat.m[x * 4 + i];
				result.m[x * 4 + y] = tmp;
			}
		}
		return result;
	}

	Vec4F opBinary(string s : "*")(Vec2F v) const {
		return Vec4F( //
				v.x * m[xx] + v.y * m[xy] + m[xw], //
				v.x * m[yx] + v.y * m[yy] + m[yw], //
				v.x * m[zx] + v.y * m[zy] + m[zw], //
				v.x * m[wx] + v.y * m[wy] + m[ww],);
	}

	Vec4F opBinary(string s : "*")(Vec3F v) const {
		return Vec4F( //
				v.x * m[xx] + v.y * m[xy] + v.z * m[xz] + m[xw], //
				v.x * m[yx] + v.y * m[yy] + v.z * m[yz] + m[yw], //
				v.x * m[zx] + v.y * m[zy] + v.z * m[zz] + m[zw], //
				v.x * m[wx] + v.y * m[wy] + v.z * m[wz] + m[ww] //
		);
	}

	void opOpAssign(string s : "*")(Matrix mat) {
		this = this * mat;
	}

}
