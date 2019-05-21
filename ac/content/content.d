module ac.content.content;

import ac.common.block.block;
import ac.common.math.vector;
import ac.content.registercontent;

class Content {

public:
	void registerContent() {
		.registerContent();

		foreach (block; blockList)
			block.finishRegistering();
	}

public:
	/// General block list. Index in this list DOES NOT CORRESPOND to the block ids
	/// For block ids, the block list in the Game class is used
	Block[] blockList = [];

public:
	static struct _Block {
		Block stone;
		Block sand, cactus;
		Block snow;
		Block dirt, grass;
		Block grassTuft, poppy, blueOrchid, oxyeyeDaisy, wheat;
		Block brownMushroom, redMushroom;

		Block cyanGlass;
		Block lamp, lampR, lampG, lampB, glowShroom, glowingOre;
		Block water;

		Block oakLog, oakLeaves;

		Block lightTestBlock;
	}

	_Block block;

}

__gshared Content content;
