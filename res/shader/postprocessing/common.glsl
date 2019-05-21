#if MSAA_SAMPLES > 1
	#define uimage2DX uimage2DMS
	#define image2DX image2DMS
	#define sampler2DX sampler2DMS

	#define imageLoadX(tex, pos, sample) imageLoad(tex, pos, sample)
	#define texelFetchX(tex, pos, sample) texelFetch(tex, pos, sample)
	#define texelFetchOffsetX(tex, pos, sample, offset) texelFetchOffset(tex, pos, sample, offset)
	#define textureSizeX(tex) textureSize(tex)
#else
	#define uimage2DX uimage2D
	#define image2DX image2D
	#define sampler2DX sampler2D

	#define imageLoadX(tex, pos, sample) imageLoad(tex, pos)
	#define texelFetchX(tex, pos, sample) texelFetch(tex, pos, 0)
	#define texelFetchOffsetX(tex, pos, sample, offset) texelFetchOffset(tex, pos, 0, offset)
	#define textureSizeX(tex) textureSize(tex, 0)
#endif

float depthToZ(float depth) {
	return 2 * CAMERA_VIEW_NEAR * CAMERA_VIEW_FAR / (CAMERA_VIEW_FAR + CAMERA_VIEW_NEAR - depth * (CAMERA_VIEW_FAR - CAMERA_VIEW_NEAR));
}