module ac.content.worldgen.overworld;

import ac.common.world.world;
import ac.common.world.gen.worldgen;
import ac.common.world.chunk;
import ac.common.world.blockcontext;
import ac.common.world.gen.worldgenplatform;
import ac.content.content;

final class WorldGen_Overworld : WorldGen {

public:
	override void initialize() {
		super.initialize();

		enum seaLevelVal = 80.0;
		enum generateTrees = true;
		enum generateCaves = true;

		// Basically everything
		auto pass2D_1 = platform.add2DPass();
		with (pass2D_1) {
			auto seaLevel = c(seaLevelVal);

			// These coeficiets practically make up biomes
			auto mountainess = clamp01(perlin2D(256, [c(0.25), c(0.5), c(1)]).x + 0.3);
			auto hillness = clamp01(abs(perlin2D(128, [c(0.3), c(0.5), c(0.7)]).x));
			auto temperature = clamp(perlin2D(16, [c(0.02), c(0.02), c(0.05), c(0.05), c(0.2), c(0.3), c(2)]).x * 4, c(-1), c(1));

			// Add some hills to the mountains (so that there are hills around mountains)

			// Some supplementary coefficients
			auto desertness = clamp01((temperature - 0.1) * 0.7);
			auto fullDesertness = clamp01((desertness - 0.3) * 3);
			auto isDesert = gt(fullDesertness, c(0));

			auto forestness = clamp01(perlin2D(64, [c(0.05), c(0.1), c(0.2), c(0.4)]).x * 2 - desertness);

			//hillness = max(hillness, (mountainessBase + 0.3) * 0.3);
			hillness = hillness * (1 - desertness);

			Value oceanZ;
			Value oceanCoefInv, oceanCoefInv2; // Goes to 0 when near oceans, otherwise 1
			{
				Value oceanVal = perlin2D(32, [c(0.02), c(0.01), c(0), c(0), c(0), c(0), c(1.8)]).x - 0.5;
				oceanCoefInv = clamp01(-oceanVal * 60);
				oceanCoefInv2 = clamp01(-oceanVal * 10);

				// Oceans go down quite fast
				Value oceanEffect = pow(max(c(0), oceanVal), c(0.5));
				oceanZ = seaLevel + 1 - oceanEffect * 40 /*+ perlin2D(16, [c(0.6), c(0.4)]).x * 8 * oceanEffect*/ ;
			}

			Value isOcean = lte(oceanZ, seaLevel);
			isDesert = isDesert & not(isOcean);

			// Elevation
			Value elevationZ;
			{
				auto coefs = [c(1), c(2)];
				enum baseOctave = 1024;
				elevationZ = 48 * clamp01(0.2 + perlin2D(baseOctave, coefs).x);

				elevationZ = elevationZ * oceanCoefInv;
			}

			// Rivers
			Value riverZ = c(90000);
			{
				auto riverSize = max(c(0.3), 0.5 + perlin2D(128, [c(0.5), c(0.10), c(0.20)]).x);
				auto riverPerlin = pow(perlin2D(256, [c(2), c(16), c(64)]).x, c(2));

				// riverZ goes very steeply up with distance from the river bed
				riverZ = abs(riverPerlin) * 10 / (1 + riverSize + pow(1 - oceanCoefInv, c(2))) - 2 - 8 * riverSize + pow(max(c(0), elevationZ - 4) * 2, c(2));
			} //

			// Hills
			Value hillsZ;
			{
				hillsZ = 32 * hillness + abs(perlin2D(32, [c(0.1), c(0.2), c(0.5), c(0.8), c(1.6), c(3.2), c(2)]).x) * 32 * hillness;

				//  Flatten areas around riverbed
				hillsZ = min(hillsZ, riverZ * 0.02) * pow(oceanCoefInv, c(2));
			}

			// Mountains
			Value mountainsZ;
			{
				// Big mountain peaks
				auto bigPeakVoronoi = voronoi2D(512, 4);
				auto bigPeakVoronoi2 = voronoi2D(512, 4);
				auto bigPeakVal = pow((max(bigPeakVoronoi.x, bigPeakVoronoi2.x) - 0.05) * 5, c(2)) * mountainess;

				// Small mountain peaks
				auto smallPeakVal = pow(voronoi2D(64, 4).x * 3, c(4));

				// Lil' perlin to smooth things out
				auto smoothPerlin = perlin2D(16, [c(0.3), c(0.2), c(0.1), c(0.1)]).x;

				// That riverZ is here for smoother transitions to rivers
				mountainsZ = max(c(0), min(riverZ * 0.5, bigPeakVal * 128) + smallPeakVal * 32 + smoothPerlin * 32 - 16) * mountainess;

				mountainsZ = mountainsZ * pow(oceanCoefInv, c(0.3)); /* Reduce the mountains when they are too high */ mountainsZ = mountainsZ - pow(mountainsZ / 255, c(5)) * 255;
				// Reduce the hills when making mountains, so the hills do not smooth out the mountain edges
				//hillsZ = max(c(0), hillsZ - mountainsZ * 0.3);
			}

			// Plains
			Value plainsZ;
			{
				plainsZ = 2 + abs(perlin2D(32, [c(0.02), c(0.04), c(0.08), c(0.16), c(0.32)]).x * 16);

				// Rather large areas around riverbed
				plainsZ = min(plainsZ, riverZ * 0.5) * oceanCoefInv2;
			}

			// Desert
			Value desertZ;
			{
				auto baseVal = abs(perlin2D(64, [c(0.2), c(0.2), c(0.6)]).x);
				auto duneVal = voronoi2D(256, 3).x;
				auto duneVal2 = voronoi2D(256, 3).x;

				desertZ = //
					(baseVal * 32) * desertness //
					 + max(c(0.0f), max(duneVal, duneVal2) * 160 - 16) * fullDesertness;

				// Less steep slopes to river beds
				desertZ = min(desertZ * oceanCoefInv2, riverZ * 0.1);
				elevationZ = elevationZ * (1 - (1 - oceanCoefInv2) * desertness);
			}

			oceanZ = select(isOcean, min(oceanZ, seaLevel + riverZ), oceanZ);

			// Ground level
			auto groundZ = select(isOcean, oceanZ, min(c(255), seaLevel + elevationZ + min(maxv(desertZ, plainsZ, mountainsZ, hillsZ), riverZ)));

			// stoneZ - Where stone ends and ground begins
			auto stoneZ = maxv( //
					oceanZ * 0.95, //
					min(oceanZ + elevationZ + max(hillsZ * 0.9, mountainsZ * 2), groundZ - 4) // Under mountains, it goes rapidly up so the stone is visible in the mountains
					// Deserts do not raise the stone level
					);

			stoneZ = select(lte(groundZ, seaLevel), min(stoneZ, groundZ - 6), stoneZ);
			auto snowZ = 220 + temperature * 40;

			set2DData("stoneZ", stoneZ);
			set2DData("groundZ", groundZ);
			set2DData("snowZ", snowZ);

			set2DData("riverZ", riverZ);

			set2DData("groundBlock", multiSelect(isDesert, c(content.block.sand), gt(desertness, c(0)), c(content.block.dirt), c(content.block.grass)));
			set2DData("soilBlock", select(isDesert, c(content.block.sand), c(content.block.dirt)));

			set2DData("desertness", desertness);
			set2DData("fullDesertness", fullDesertness);
			set2DData("forestness", forestness);
			set2DData("oceanCoefInv", oceanCoefInv);

			{
				auto blueOrchidProb = perlin2D(32, [c(1)]).x - 0.3;
				auto poppyProb = perlin2D(32, [c(1)]).x - 0.3;
				auto daisyProb = perlin2D(32, [c(1)]).x - 0.3;

				auto wheatProb = perlin2D(512, [c(1)]).x - 0.4;
				wheatProb = wheatProb * (1 - desertness);
				wheatProb = wheatProb * (1 - forestness);
				wheatProb = wheatProb * (1 - mountainess);

				auto redShroomProb = perlin2D(32, [c(2)]).x - 0.4;
				auto brownShroomProb = perlin2D(32, [c(2)]).x - 0.4;

				auto plantBlock = multiSelect( //
						gte(groundZ, snowZ), air, //
						randBool(desertness * 4), air, //
						randBool(wheatProb * 10), c(content.block.wheat), //
						randBool(c(0.9)), air, //
						randBool(forestness * redShroomProb), c(content.block.redMushroom), //
						randBool(forestness * brownShroomProb), c(content.block.brownMushroom), //
						randBool(forestness * 4), c(content.block.grassTuft), //
						randBool(blueOrchidProb), c(content.block.blueOrchid), //
						randBool(poppyProb), c(content.block.poppy), //
						randBool(daisyProb), c(content.block.oxyeyeDaisy), //
						c(content.block.grassTuft), //
						);

				set2DData("plantBlock", plantBlock);
			}

			finish();
		}

		// Derivation of height map -> decide what blocks to pud where
		auto pass2D_2 = platform.add2DPass();
		with (pass2D_2) {
			enum dist = 3;
			auto v1 = pass2DData(pass2D_1, "groundZ", c(-dist, -dist));
			auto v2 = pass2DData(pass2D_1, "groundZ", c(dist, -dist));
			auto v3 = pass2DData(pass2D_1, "groundZ", c(-dist, dist));
			auto v4 = pass2DData(pass2D_1, "groundZ", c(dist, dist));

			auto groundZ = pass2DData(pass2D_1, "groundZ");
			auto stoneZ = pass2DData(pass2D_1, "stoneZ");
			auto seaLevel = c(seaLevelVal);

			auto terrainGradient = maxv(v1, v2, v3, v4, groundZ) - minv(v1, v2, v3, v4, groundZ);

			// Stone layer is moved upwards depending on the terrain gradient, up to the ground level
			set2DData("stoneZ", toInt(min(stoneZ + terrainGradient * 0.6, groundZ)));

			// New variable soilZ is introduced - there might be one layer of grass on the ground
			set2DData("soilZ", toInt( //
					select( // If the ground is below water, there is only soil
					lt(groundZ, seaLevel), groundZ, //
					groundZ - max(c(0), 1.5 - terrainGradient * 0.2) //
					)));

			set2DData("terrainGradient", terrainGradient);

			finish();
		}

		auto pass3D_1 = platform.add3DPass;
		with (pass3D_1) {
			auto z = globalPos.z;

			auto groundZ = toInt(pass2DData(pass2D_1, "groundZ"));
			auto snowZ = toInt(pass2DData(pass2D_1, "snowZ"));
			auto seaLevel = c(seaLevelVal);

			auto stoneZ = pass2DData(pass2D_2, "stoneZ");
			auto soilZ = pass2DData(pass2D_2, "soilZ");

			auto riverZ = pass2DData(pass2D_1, "riverZ");

			auto oceanCoefInv = pass2DData(pass2D_1, "oceanCoefInv");

			Value isCave = c(false);
			if (generateCaves) {
				Value caveVal = perlin3D(8, [c(1), c(0.8), c(0.6), c(0.3)]);

				// Caves are only somewhere
				Value isCaveArea = gte(perlin3D(32, [c(0.2), c(0.2), c(0.1), c(0.2), c(0.1)]), c(0.15));

				// There is only few entry points from the surface
				Value isCaveEntryArea = gte(perlin3D(32, [c(0.9), c(0.5), c(0.5)]) * oceanCoefInv + (groundZ - z) * 0.02 - max(c(0), seaLevel - riverZ), c(0.3));

				isCave = isCaveEntryArea & isCaveArea & gte(caveVal, c(0.3)) & lte(z, groundZ) & gt(z, c(1));
			}

			if_(eq(z, groundZ), { //
				set2DData("caveOnSurface", isCave);
			});

			auto oreness = perlin3D(8, [c(1)]);
			auto rockBlock = select(gt(oreness, c(0.7)) & lt(z, groundZ), c(content.block.glowingOre), c(content.block.stone));

			setBlock(multiSelect( //
					isCave, air, //
					lte(z, stoneZ), rockBlock, //
					lte(z, soilZ), pass2DData(pass2D_1, "soilBlock"), //
					lte(z, groundZ), select(gte(z, snowZ), c(content.block.snow), pass2DData(pass2D_1, "groundBlock")), //
					lte(z, seaLevel), c(content.block.water), //
					air //
					));

			finish();
		}

		auto pass2D_3 = platform.add2DPass();
		with (pass2D_3) {
			auto groundZ = toInt(pass2DData(pass2D_1, "groundZ"));
			auto snowZ = toInt(pass2DData(pass2D_1, "snowZ"));
			auto seaLevel = c(seaLevelVal);

			// Tree generation
			if (generateTrees) {
				auto treeData = voronoi2D(32, 12);
				auto treeOffset = vec2(toInt(floor(treeData.z)), toInt(floor(treeData.w)));
				auto treeGroundZ = pass2DData(pass2D_1, "groundZ", treeOffset);
				auto treeCaveOnSurface = pass2DData(pass3D_1, "caveOnSurface", treeOffset);
				auto treeTerrainGradient = pass2DData(pass2D_2, "terrainGradient", treeOffset);
				auto treeForestness = pass2DData(pass2D_1, "forestness", treeOffset);

				auto treeDistance = select( //
						gt(treeGroundZ, seaLevel) & lt(groundZ, snowZ) & not(treeCaveOnSurface) & lt(treeTerrainGradient, c(6)) //
						 & gt(treeForestness, c(0.2)), max(abs(treeOffset.x), abs(treeOffset.y)), c(1000));

				auto treeHeight = 3 + randFloat01XY(treeOffset) * 7;

				set2DData("treeDistance", treeDistance);
				set2DData("treeZ", treeGroundZ + treeHeight);
				set2DData("treeCrownZ", treeGroundZ + treeHeight * 0.8);
				set2DData("treeCrownSize", 2 + clamp(treeHeight * 0.4 + randFloat01() * 2, c(0), c(6)));
			}

			finish();
		}

		// Generate glowshrooms & trees & grass
		with (platform.add3DPass) {
			auto z = globalPos.z;

			auto fullDesertness = pass2DData(pass2D_1, "fullDesertness");
			auto desertness = pass2DData(pass2D_1, "desertness");
			auto isDesert = gt(fullDesertness, c(0));

			auto groundZ = toInt(pass2DData(pass2D_1, "groundZ"));
			auto blockOnGround = getBlock(c(0), c(0), groundZ - z);
			auto seaLevel = c(seaLevelVal);
			auto caveOnSurface = pass2DData(pass3D_1, "caveOnSurface");

			auto thisBlock = getBlock();
			auto blockBelow = getBlock(c(0), c(0), c(-1));
			auto terrainGradient = pass2DData(pass2D_2, "terrainGradient");

			auto plantBlock = pass2DData(pass2D_1, "plantBlock");

			Value blockToSet = var(multiSelect( //
					eq(z, groundZ + 1) & gt(groundZ, seaLevel) & not(caveOnSurface) & lt(terrainGradient, c(6)), plantBlock, //
					thisBlock));

			if (generateTrees) {
				auto treeDistance = pass2DData(pass2D_3, "treeDistance");
				auto treeZ = pass2DData(pass2D_3, "treeZ");
				auto treeCrownZ = pass2DData(pass2D_3, "treeCrownZ");
				auto treeCrownSize = pass2DData(pass2D_3, "treeCrownSize");

				set(blockToSet, multiSelect( //
						lte(z, groundZ), blockToSet, //
						eq(treeDistance, c(0)) & lte(z, treeZ), c(content.block.oakLog), //
						lt(treeDistance, treeCrownSize - max(c(0), z - treeZ - 2) * 1) & gt(z, treeCrownZ) & randBool(1.2 - treeDistance * 0.1), c(content.block.oakLeaves), //
						lt(treeDistance, treeCrownSize * 0.7) & eq(z, floor(treeCrownZ)) & randBool(c(0.5)), c(content.block.oakLeaves), //
						blockToSet //
						));
			}

			if_(lt(randFloat01XY(), fullDesertness * 0.0005) & gt(z, groundZ) & gt(groundZ, seaLevel) & lt(z - groundZ, randFloat01XY(0x96843) * 4) & eq(blockOnGround, c(content.block.sand)) & lt(terrainGradient, c(2)), { //
				set(blockToSet, c(content.block.cactus));
			});

			// TODO rather check is liquid
			if_(lt(z, groundZ) & eq(thisBlock, air) & neq(blockBelow, air) & neq(blockBelow, c(content.block.water)) & randBool(c(0.01)), { //
				set(blockToSet, c(content.block.glowShroom));
			});

			// Support sand with stone
			if_(eq(thisBlock, c(content.block.sand)) & eq(blockBelow, air), { //
				set(blockToSet, c(content.block.stone));
			});

			if_(neq(blockToSet, thisBlock), { //
				setBlock(blockToSet);
			});

			finish();
		}

		platform.finish();
	}

}
