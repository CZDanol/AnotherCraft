module ac.common.world.env.overworld;

import std.math;

import ac.common.world.world;
import ac.common.world.env.worldenvironment;
import ac.common.math.vector;

final class WorldEnvironment_Overworld : WorldEnvironment {

public:
	override void step() {
		lightSettings_.ambientLightColor = Vec3F(0.06, 0.06, 0.06);

		const float dayTime = world.dayTime;

		enum dawnTime = 0.2;
		enum dawnMargin = 0.05;

		enum duskTime = 0.8;
		enum duskMargin = 0.05;

		enum noonTime = 0.5;
		enum midnightTime = 0;

		enum nightEnd = dawnTime - dawnMargin;
		enum nightStart = duskTime + duskMargin;

		enum dayLength = nightStart - nightEnd;
		enum nightLength = 1 - dayLength;

		enum moonEnd = nightEnd - 0.03;
		enum moonStart = nightStart + 0.03;

		const bool isDay = dayTime >= nightEnd && dayTime <= nightStart;

		const float nightProgress = fmod(1 + dayTime - nightStart, 1) / nightLength;
		const float dayProgress = (dayTime - nightEnd) / dayLength;
		const float moonProgress = fmod(1 + dayTime - moonStart, 1) / (moonEnd + 1 - moonStart);

		// Daylight direction
		{
			//result.daylightDirection = Vec3F(0,0,1);
			const float prog = interpolate(dayTime, //
					[0.5, 0, dayProgress, dayProgress, 1, 0.5], //
					[0, moonEnd, nightEnd, nightStart, moonStart, 1] //
			);

			//auto prog = isDay ? dayProgress : moonProgress;
			lightSettings_.daylightDirection = Vec3F(-cos(prog * PI), sin(prog * PI) * 0.5, sin(prog * PI) * 1.25 - 0.25).normalized;

			enum float dayHalo = 4;
			enum float dawnHalo = 1;
			enum float nightHalo = 4;

			lightSettings_.sunHaloPow = interpolate(dayTime, //
					[nightHalo, dawnHalo, dayHalo, dayHalo, dawnHalo, nightHalo], //
					[moonEnd, dawnTime - dawnMargin, dawnTime + dawnMargin, duskTime - duskMargin, duskTime + duskMargin, moonStart], //
					);
		}

		// Directional daylight color
		{
			immutable moonColor = Vec3F(2, 5, 20) / 255;
			immutable dawnColor = Vec3F(120, 120, 120) / 255;
			immutable duskColor = Vec3F(240, 88, 88) / 255;
			immutable dayColor = Vec3F(120, 120, 50) / 255;
			immutable noColor = Vec3F(0, 0, 0);

			//result.directionalDaylightColor = Vec3F(1, 1, 1);
			lightSettings_.directionalDaylightColor = interpolateColors(dayTime, //
					[moonColor, noColor, dawnColor, dayColor, dayColor, duskColor, noColor, moonColor], //
					[moonEnd, nightEnd, dawnTime, dawnTime + dawnMargin, duskTime - duskMargin, duskTime, nightStart, moonStart] //
			);
		}

		// Ambient daylight color
		{
			immutable midnightColor = Vec3F(2, 2, 2) / 255;
			immutable noonColor = Vec3F(145, 145, 145) / 255;

			lightSettings_.ambientDaylightColor = interpolateColors(dayTime, //
					[midnightColor, noonColor, noonColor, midnightColor], //
					[dawnTime - dawnMargin, dawnTime + dawnMargin, duskTime - duskMargin, duskTime + duskMargin] //
			);
		}

		// Sky color
		{
			immutable midnightColor = Vec3F(10, 10, 10) / 255;
			immutable dawnColor = Vec3F(0, 65, 85) / 255;
			immutable duskColor = Vec3F(19, 47, 84) / 255;
			immutable dayColor = Vec3F(67, 168, 249) / 255;

			lightSettings_.skyColor = interpolateColors(dayTime, //
					[midnightColor, dawnColor, dayColor, dayColor, duskColor, midnightColor], //
					[dawnTime - dawnMargin, dawnTime, dawnTime + dawnMargin, duskTime - duskMargin, duskTime, duskTime + duskMargin] //
			);
		}

		// Horizon halo color
		{
			immutable midnightColor = Vec3F(10, 10, 10) / 255;
			immutable dawnColor = Vec3F(150, 100, 50) * 0.5 / 255;
			immutable duskColor = Vec3F(230, 100, 50) * 0.5 / 255;

			immutable dayColor = Vec3F(60, 60, 60) / 255;
			immutable morningColor = Vec3F(120, 120, 60) * 0.8 / 255;
			immutable eveningColor = Vec3F(80, 30, 30) / 255;

			lightSettings_.horizonHaloColor = interpolateColors(dayTime, //
					[midnightColor, dawnColor, morningColor, dayColor, eveningColor, duskColor, midnightColor], //
					[dawnTime - dawnMargin, dawnTime, dawnTime + dawnMargin * 2, noonTime, duskTime - duskMargin, duskTime, duskTime + duskMargin] //
			);

			immutable midnightSunHaloColor = Vec3F(10, 10, 20) / 255;

			lightSettings_.sunHorizonHaloColor = interpolateColors(dayTime, //
					[midnightSunHaloColor, dawnColor * 1.5, Vec3F(0), Vec3F(0), duskColor * 1.5, midnightSunHaloColor], //
					[dawnTime - dawnMargin, dawnTime, dawnTime + dawnMargin, duskTime - duskMargin, duskTime, duskTime + duskMargin]);
		}

		// Sun color
		{
			immutable dayColor = Vec3F(255, 255, 100) / 255;
			immutable nightColor = Vec3F(130, 180, 252) * 0.8 / 255;
			immutable mezzoColor = Vec3F(0, 0, 0);

			lightSettings_.sunColor = interpolateColors(dayTime, //
					[nightColor, mezzoColor, dayColor, dayColor, mezzoColor, nightColor], //
					[moonEnd, nightEnd, dawnTime, duskTime, nightStart, moonStart] //
			);
		}

		// Sun size
		{
			immutable midnightSize = 0.07;
			immutable dawnSize = 0.19;
			immutable daySize = 0.12;

			lightSettings_.sunSize = interpolate(dayTime, //
					[midnightSize, dawnSize, daySize, daySize, dawnSize, midnightSize], //
					[nightEnd, dawnTime, dawnTime + dawnMargin * 4, duskTime - duskMargin * 4, duskTime, nightStart] //
			);
		}

		// Artificial light effect
		{
			enum artificialLightEffectReductionDuringDay = 0.8;

			lightSettings_.artificialLightEffectReduction = interpolate(dayTime, //
					[0, artificialLightEffectReductionDuringDay, artificialLightEffectReductionDuringDay, 0], //
					[nightEnd, dawnTime + dawnMargin, duskTime - duskMargin, nightStart] //
			);

		}
	}
}
