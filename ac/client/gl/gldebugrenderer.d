module ac.client.gl.gldebugrenderer;

import bindbc.opengl;
import std.conv;

import ac.client.application;
import ac.client.gl.glbuffer;
import ac.client.gl.glprogram;
import ac.client.gl.glprogramcontext;
import ac.client.gl.glstate;
import ac.common.math.matrix;
import ac.common.math.vector;

__gshared GLDebugRenderer glDebugRenderer;

final class GLDebugRenderer {

public:
	this() {
		linePosBuffer_ = new GLBuffer!float;
		lineColBuffer_ = new GLBuffer!ubyte(false);

		lineProgramContext_ = new GLProgramContext(new GLProgram("utilRender/debugLines", GLProgramShader.vertex, GLProgramShader.fragment));
		lineProgramContext_.bindBuffer("pos", linePosBuffer_, 4);
		lineProgramContext_.bindBuffer("color", lineColBuffer_, 1);

		lineProgramContext_.disable(GL_CULL_FACE);
		lineProgramContext_.disable(GL_DEPTH_TEST);
	}

public:
	void drawPoint(Vec2F pt, ubyte color = 0) {
		Vec2F windowSize = application.windowSize.to!Vec2F;

		drawLine(pt - Vec2F(10, 0) / windowSize, pt + Vec2F(10, 0) / windowSize, color);
		drawLine(pt - Vec2F(0, 10) / windowSize, pt + Vec2F(0, 10) / windowSize, color);
	}

	void drawPoint(Vec4F pt, ubyte color = 0) {
		Vec4F v = Vec4F(1 / application.windowSize.to!Vec2F, 0, 0) * pt.w;

		drawLine(pt - Vec4F(10, 0, 0, 0) * v, pt + Vec4F(10, 0, 0, 0) * v, color);
		drawLine(pt - Vec4F(0, 10, 0, 0) * v, pt + Vec4F(0, 10, 0, 0) * v, color);
	}

	void drawLine(Vec2F from, Vec2F to, ubyte color = 0) {
		linePosBuffer_ ~= Vec4F(from, 0, 1);
		linePosBuffer_ ~= Vec4F(to, 0, 1);
		lineColBuffer_ ~= color;
		lineColBuffer_ ~= color;
	}

	void drawLine(Vec4F from, Vec4F to, ubyte color = 0) {
		linePosBuffer_ ~= from;
		linePosBuffer_ ~= to;
		lineColBuffer_ ~= color;
		lineColBuffer_ ~= color;
	}

	void drawQuad(const ref Matrix m, Vec3F v1, Vec3F v2, Vec3F v3, Vec3F v4, ubyte color = 0) {
		Vec4F p1 = m * v1;
		Vec4F p2 = m * v2;
		Vec4F p3 = m * v3;
		Vec4F p4 = m * v4;

		drawLine(p1, p2, color);
		drawLine(p2, p3, color);
		drawLine(p3, p4, color);
		drawLine(p4, p1, color);
	}

	void drawQuad(Vec4F v1, Vec4F v2, Vec4F v3, Vec4F v4, ubyte color = 0) {
		drawLine(v1, v2, color);
		drawLine(v2, v3, color);
		drawLine(v3, v4, color);
		drawLine(v4, v1, color);
	}

	void drawBox(const ref Matrix m, Vec3F v1, Vec3F v2, ubyte color = 0) {
		Vec4F p000 = m * Vec3F(v1.x, v1.y, v1.z);
		Vec4F p001 = m * Vec3F(v1.x, v1.y, v2.z);
		Vec4F p010 = m * Vec3F(v1.x, v2.y, v1.z);
		Vec4F p011 = m * Vec3F(v1.x, v2.y, v2.z);
		Vec4F p100 = m * Vec3F(v2.x, v1.y, v1.z);
		Vec4F p101 = m * Vec3F(v2.x, v1.y, v2.z);
		Vec4F p110 = m * Vec3F(v2.x, v2.y, v1.z);
		Vec4F p111 = m * Vec3F(v2.x, v2.y, v2.z);

		drawQuad(p000, p001, p011, p010, color);
		drawQuad(p100, p101, p111, p110, color);

		drawLine(p000, p100, color);
		drawLine(p001, p101, color);
		drawLine(p010, p110, color);
		drawLine(p011, p111, color);
	}

public:
	void render() {
		lineColBuffer_.upload(GL_DYNAMIC_DRAW);
		linePosBuffer_.upload(GL_DYNAMIC_DRAW);

		lineProgramContext_.bind();
		glDrawArrays(GL_LINES, 0, cast(GLint) lineColBuffer_.length);

		lineColBuffer_.clear();
		linePosBuffer_.clear();
	}

private:
	GLBuffer!float linePosBuffer_;
	GLBuffer!ubyte lineColBuffer_;
	GLProgramContext lineProgramContext_;

}
