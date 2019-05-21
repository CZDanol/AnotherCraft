module ac.client.gl.glscreentexture;

import bindbc.opengl;

import ac.client.gl.glresourcemanager;
import ac.client.graphicsettings;
import ac.client.gl.glstate;
import ac.client.gl.gltexture;
import ac.common.math.vector;
import ac.client.application;

/// Texture that is automatically adjusted to the screen size
final class GLScreenTexture : GLTexture {

public:
	alias OnSetup = void delegate();

public:
	this(GLenum internalFormat = GL_RGB, bool multiSample = false, int levels = 1) {
		internalFormat_ = internalFormat;
		multiSample_ = multiSample;
		levels_ = levels;

		super(getType);

		initialize();

		graphicSettings[this] = (GraphicSettings.Changes changes) {
			if (!(changes & (GraphicSettings.Change.resolution | GraphicSettings.Change.antiAliasing)))
				return;

			glResourceManager.release(typeAA_[type_], textureId_);
			type_ = getType;
			textureId_ = glResourceManager.create(typeAA_[type_]);
			initialize();
			versionId_++;
		};
	}

	override void release() {
		super.release();
		application.screenResizeWatchers.remove(cast(void*) this);
	}

public:
	void onSetup(OnSetup set) {
		onSetup_ = set;
		if (set)
			set();
	}

private:
	void initialize() {
		if (textureType == GL_TEXTURE_2D_MULTISAMPLE)
			glTextureStorage2DMultisample(textureId_, graphicSettings.antiAliasing, internalFormat_, application.windowSize.x, application.windowSize.y, GL_FALSE);
		else {
			glTextureParameteri(textureId_, GL_TEXTURE_MIN_FILTER, levels_ == 1 ? GL_NEAREST : GL_NEAREST_MIPMAP_NEAREST);
			glTextureParameteri(textureId_, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

			glTextureParameteri(textureId_, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTextureParameteri(textureId_, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

			glTextureStorage2D(textureId_, levels_, internalFormat_, application.windowSize.x, application.windowSize.y);

			if (onSetup_)
				onSetup_();
		}
	}

	pragma(inline) GLenum getType() {
		return multiSample_ && graphicSettings.antiAliasing > 1 ? GL_TEXTURE_2D_MULTISAMPLE : GL_TEXTURE_2D;
	}

private:
	GLenum internalFormat_;
	size_t windowSizeChangeId_;
	bool multiSample_;
	int levels_;
	OnSetup onSetup_;

}
