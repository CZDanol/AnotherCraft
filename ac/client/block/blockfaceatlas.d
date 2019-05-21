module ac.client.block.blockfaceatlas;

import bindbc.opengl;
import derelict.sfml2;
import std.conv;
import std.algorithm;
import std.math;
import std.string;
import std.format;

import ac.common.math.vector;
import ac.client.gl.glstate;
import ac.client.gl.gltexture;
import ac.client.gl.glresourcemanager;
import ac.client.graphicsettings;
import ac.client.resources;

/// Atlas for storing block faces
/// Faces are stored with spacing equal to face size because of mipmapping
final class BlockFaceAtlas {

public:
	this(int itemSize, size_t id, bool mipmapping, bool premultiplyAlpha, bool wrapping, bool betterTexturing) {
		id_ = id;
		premultiplyAlpha_ = premultiplyAlpha;
		mipmapping_ = mipmapping;
		wrapping_ = wrapping;
		betterTexturing_ = betterTexturing;

		itemSize_ = itemSize;
		image_ = sfImage_createFromColor(itemSize_, itemSize_ * capacity_, sfColor(0, 0, 0, 0));

		texture_ = new GLTexture(GL_TEXTURE_2D_ARRAY);

		graphicSettings[this] = (GraphicSettings.Changes changes) { //
			if (!uploaded_ || !(changes & GraphicSettings.Change.betterTexturing))
				return;

			auto set = graphicSettings.betterTexturing && betterTexturing_ ? GL_LINEAR : GL_NEAREST;
			glTextureParameteri(texture_.textureId, GL_TEXTURE_MAG_FILTER, set);
		};
	}

	~this() {
		sfImage_destroy(image_);
	}

public:
	/// Adds an item (from file) and returns its layer id
	uint addItem(sfImage* img, bool wrapping = false) {
		auto imgSize = sfImage_getSize(img);
		assert(imgSize.x == itemSize_ && imgSize.y == itemSize_, "Image size does not match the grid size");

		if (length_ == capacity_) {
			capacity_ *= 2;
			sfImage* newImage = sfImage_createFromColor(itemSize_, itemSize_ * capacity_, sfColor(0, 0, 0, 0));
			sfImage_copyImage(newImage, image_, 0, 0, sfIntRect(), false);
			sfImage_destroy(image_);
			image_ = newImage;
		}

		sfImage_copyImage(image_, img, 0, length_ * itemSize_, sfIntRect(), false);
		return length_++;
	}

public:
	/// Uploads the progress to 
	void upload() {
		assert(!uploaded_);
		uploaded_ = true;

		//sfImage_saveToFile(image_, "atlas_%s.png".format(id_).toStringz);
		auto texId = texture_.textureId;

		glTextureParameteri(texId, GL_TEXTURE_MIN_FILTER, mipmapping_ ? GL_LINEAR_MIPMAP_LINEAR : GL_NEAREST);
		glTextureParameteri(texId, GL_TEXTURE_MAG_FILTER, graphicSettings.betterTexturing && betterTexturing_ ? GL_LINEAR : GL_NEAREST);
		glTextureParameteri(texId, GL_TEXTURE_WRAP_S, wrapping_ ? GL_REPEAT : GL_CLAMP_TO_EDGE);
		glTextureParameteri(texId, GL_TEXTURE_WRAP_T, wrapping_ ? GL_REPEAT : GL_CLAMP_TO_EDGE);

		float aniso;
		int maxLevel = mipmapping_ ? max(0, cast(int) log2(itemSize_) - 1) : 0;
		glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY, &aniso);
		glTextureParameterf(texId, GL_TEXTURE_MAX_ANISOTROPY, mipmapping_ ? min(aniso, 8) : 1);
		glTextureParameteri(texId, GL_TEXTURE_MAX_LEVEL, maxLevel);

		texture_.bind();

		if (premultiplyAlpha_) {
			glTextureStorage3D(texId, maxLevel + 1, GL_RGBA8, itemSize_, itemSize_, capacity_);

			auto suppTexId = glResourceManager.create(GLResourceType.texture2DArray);
			glTextureParameteri(suppTexId, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

			glBindTexture(GL_TEXTURE_2D_ARRAY, suppTexId);
			glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, itemSize_, itemSize_, capacity_, 0, GL_RGBA, GL_UNSIGNED_BYTE, sfImage_getPixelsPtr(image_));

			resources.premultiplyAlpha_program.bind();
			glBindImageTexture(0, suppTexId, 0, GL_FALSE, 0, GL_READ_WRITE, GL_RGBA8);

			Vec2I workgroups = (itemSize_ + resources.premultiplyAlpha_workgroupSize - 1) / resources.premultiplyAlpha_workgroupSize;
			glDispatchCompute(workgroups.x, workgroups.y, length_);
			glMemoryBarrier(GL_ALL_BARRIER_BITS);

			glCopyImageSubData( //
					suppTexId, GL_TEXTURE_2D_ARRAY, 0, 0, 0, 0, //
					texId, GL_TEXTURE_2D_ARRAY, 0, 0, 0, 0, //
					itemSize_, itemSize_, length_ //
					);

			glResourceManager.release(GLResourceType.texture2D, suppTexId);
		}
		else
			glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, itemSize_, itemSize_, capacity_, 0, GL_RGBA, GL_UNSIGNED_BYTE, sfImage_getPixelsPtr(image_));

		glGenerateTextureMipmap(texId);
	}

	pragma(inline) GLTexture texture() {
		return texture_;
	}

private:
	GLTexture texture_;
	sfImage* image_;
	bool uploaded_;
	bool premultiplyAlpha_, mipmapping_, wrapping_, betterTexturing_;

private:
	int itemSize_;
	int length_, capacity_ = 8;
	size_t id_;

}
