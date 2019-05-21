module ac.client.block.renderer.standardblockrenderer;

import core.bitop;
import std.conv;
import std.format;

import ac.common.block.block;
import ac.client.block.blockface;
import ac.client.block.blockrenderer;
import ac.client.world.chunkrenderbuffers;
import ac.client.resources;
import ac.common.math.vector;
import ac.common.world.chunk;
import ac.common.world.world;

/// Standard block renderer, renders to a buffer
final class StandardBlockRenderer : BlockRenderer {

private:
	alias UByteBuilder = ChunkRenderBufferBuildersT[0];

public:
	this() {
		buffersBuilder = ChunkRenderBuffersBuilder(0);
	}

public:
	override void drawBlock(BlockFace face) {
		auto bb = buffersBuilder[face.contextId][0];
		drawBlock(bb, bb, bb, bb, bb, bb, face, face, face, face, face, face);
	}

	override void drawBlock(BlockFace topBottomFace, BlockFace sideFace) {
		auto topBottomBB = buffersBuilder[topBottomFace.contextId][0];
		auto sideBB = buffersBuilder[sideFace.contextId][0];
		drawBlock( //
				sideBB, sideBB, sideBB, sideBB, topBottomBB, topBottomBB, //
				sideFace, sideFace, sideFace, sideFace, topBottomFace, topBottomFace //
				);
	}

	override void drawBlock(BlockFace topFace, BlockFace bottomFace, BlockFace sideFace) {
		auto topBB = buffersBuilder[topFace.contextId][0];
		auto bottomBB = buffersBuilder[bottomFace.contextId][0];
		auto sideBB = buffersBuilder[sideFace.contextId][0];

		drawBlock( //
				sideBB, sideBB, sideBB, sideBB, bottomBB, topBB, //
				sideFace, sideFace, sideFace, sideFace, bottomFace, topFace //
				);
	}

	/// normal is 0 - 255
	override void drawFace(BlockFace face, Vec3U8 lt, Vec3U8 rt, Vec3U8 lb, Vec3U8 rb, Vec3U8 normal) {
		auto bb = buffersBuilder[face.contextId][0];

		bb[0].addTrianglesQuad(offset + lt, offset + rt, offset + lb, offset + rb);
		bb[1] ~= singleFaceUVOffsets;
		bb[2] ~= face.uvIData;
		bb[3] ~= normal;
		bb[3] ~= normal;
	} //

	/// normal is 0 - 255
	override void drawFace(BlockFace face, Vec3F lt, Vec3F rt, Vec3F lb, Vec3F rb, Vec3U8 normal) {
		auto bb = buffersBuilder[face.contextId][1];
		const Vec3F offsetF = offset.to!Vec3F;

		bb[0].addTrianglesQuad(offsetF + lt, offsetF + rt, offsetF + lb, offsetF + rb);
		bb[1] ~= singleFaceUVOffsets;
		bb[2] ~= face.uvIData;
		bb[3] ~= normal;
		bb[3] ~= normal;
	} //

private:
	pragma(inline) void drawBlock( //
			UByteBuilder bb0, UByteBuilder bb1, UByteBuilder bb2, UByteBuilder bb3, UByteBuilder bb4, UByteBuilder bb5, //
			BlockFace face0, BlockFace face1, BlockFace face2, BlockFace face3, BlockFace face4, BlockFace face5 //
			) {

		debug assert(visibleFaces);

		// Vector swizzling data for all the faces, O = 0, I = 1
		enum quads = [ //
			"Oxy OOy OxO OOO", // left
			"IOy Ixy IOO IxO", // right
			"OOy xOy OOO xOO", // front
			"xIy OIy xIO OIO", // back
			"OOO xOO OyO xyO", // bottom
			"OyI xyI OOI xOI", // top
			];

		// For all 6 faces
		static foreach (i; 0 .. 6) {
			if ( //
				(visibleFaces & (1 << i)) // Face is visible
				 && ( //
					!mixin("face%s".format(i)).isUniformFace // Face is not uniform (cannot be aggregated)
					 || ((faceAggregation >> (i * 8)) & 0xff) // or face is not aggregated out
				) //
				) {

				/// Packed UV coordinates (can go from 0 - 8; >1 is used for aggregated faces)
				const ubyte packedAggregation = mixin("face%s".format(i)).isUniformFace ? ((faceAggregation >> (i * 8)) & 0xff) : 0x11;
				const Vec2U8 fa = Vec2U8(packedAggregation & 0xf, (packedAggregation >> 4) & 0xf);

				auto builder = mixin("bb%s".format(i));

				// Quads are defined using vector swizzles (taken from the quads enum)
				// This for example creates (offset, fa.Oxy, fa.OOy, fa.OxO, fa.OOO)
				builder[0].addTrianglesQuad(offset, fa.opDispatch!(quads[i][0 .. 3]), fa.opDispatch!(quads[i][4 .. 7]), fa.opDispatch!(quads[i][8 .. 11]), fa.opDispatch!(quads[i][12 .. 15]));

				// UV coordinates packed into single byte
				builder[1] ~= Vector!(ubyte, 6)(0xf0 & packedAggregation, packedAggregation, 0x00, packedAggregation, 0x0f & packedAggregation, 0x00);

				// Texture layer
				builder[2] ~= mixin("face%s".format(i)).uvIData;

				// Normal, repeated twice for two faces
				builder[3] ~= Block.FaceNormalU8.array[i].xyzxyz;
			}
		}
	}

public:
	// This is to be updated before each block render
	Vec3U8 offset;
	ulong faceAggregation = 0x111111111111; // 4 bits * 2 dimensions * 6 faces

public:
	ChunkRenderBuffersBuilder buffersBuilder;

private:
	static immutable Vector!(ubyte, 6) singleFaceUVOffsets = Vector!(ubyte, 6)(0x10, 0x11, 0x00, 0x11, 0x01, 0x00);

}
