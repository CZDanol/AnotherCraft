module ac.client.gui.guiresources;

import derelict.sfml2;
import std.string;

__gshared GUIResources guiResources;

final class GUIResources {

public:
	this() {
		defaultFont = sfFont_createFromFile("../res/font/FiraCode-Regular.ttf".toStringz);
	}

	~this() {
		sfFont_destroy(defaultFont);
	}

public:
	sfFont* defaultFont;

public:
	int outlineThickness = 1;
	int fontSize = 12;

	int sliderSize = 16;

public:
	sfColor fontColor = sfColor(255, 255, 255, 255);
	sfColor outlineColor = sfColor(255, 255, 255, 128);
	sfColor inactiveFaceColor = sfColor(10, 10, 10, 200);
	sfColor hoveredFaceColor = sfColor(40, 40, 40, 200);
	sfColor pressedFaceColor = sfColor(70, 70, 70, 200);

}
