module ac.client.gl.gl2ddraw;

import std.conv;
import bindbc.opengl;

import ac.client.application;
import ac.client.gl.glbuffer;
import ac.client.gl.glprogram;
import ac.client.gl.glprogramcontext;
import ac.client.gl.glscreentexture;
import ac.client.gl.glstate;
import ac.client.gl.gltexture;
import ac.common.math.matrix;
import ac.common.math.vector;

GL2DDraw gl2DDraw;

final class GL2DDraw {

public:
	this() {
		quadBuffer = new GLBuffer!ubyte;
		quadBuffer.addTrianglesQuad(Vec2U8(0, 0), Vec2U8(1, 0), Vec2U8(0, 1), Vec2U8(1, 1));
		quadBuffer.upload(GL_STATIC_DRAW);

		textureContext_ = new GLProgramContext(new GLProgram("utilRender/simpleTexture", GLProgramShader.fragment, GLProgramShader.vertex));
		textureContext_.bindBuffer("uv", quadBuffer, 2);
		textureContext_.enable(GL_BLEND);

		msTextureContext_ = new GLProgramContext(new GLProgram("utilRender/simpleMultisampleTexture", GLProgramShader.fragment, GLProgramShader.vertex));
		msTextureContext_.bindBuffer("uv", quadBuffer, 2);
		msTextureContext_.enable(GL_BLEND);
	}

public:
	void draw(GLTexture texture, Vec2F pos = Vec2F(0, 0), Vec2F size = application.windowSize.to!Vec2F) {
		GLProgramContext ctx;
		switch (texture.textureType) {

		case GL_TEXTURE_2D:
			ctx = textureContext_;
			break;

		case GL_TEXTURE_2D_MULTISAMPLE:
			ctx = msTextureContext_;

			msTextureContext_.setUniform("textureSize", application.windowSize.to!Vec2F);
			break;

		default:
			assert(0);

		}

		ctx.setUniform("viewMatrix", viewMatrix.translated(pos) * Matrix.scaling(size));
		ctx.bindTexture("tex", texture);
		ctx.bind();

		glDrawArrays(GL_TRIANGLES, 0, 6);
	}

public:
	Matrix viewMatrix;
	GLBuffer!ubyte quadBuffer; ///< A buffer that contains trinalges for rectangle (0,0) -- (1,1)

private:
	GLProgramContext textureContext_, msTextureContext_;

}
