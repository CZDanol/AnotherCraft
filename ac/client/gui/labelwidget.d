module ac.client.gui.labelwidget;

import ac.client.gui.devtoolkit;

final class LabelWidget : Widget {

public:
	this(string text = "") {
		optimalSize_ = Vec2I(150, 18);

		dtext_ = sfText_create();
		sfText_setFont(dtext_, guiResources.defaultFont);
		sfText_setCharacterSize(dtext_, guiResources.fontSize);
		sfText_setColor(dtext_, guiResources.fontColor);
		sfText_setString(dtext_, text.toStringz);

		this.text = text;
	}

	~this() {
		sfText_destroy(dtext_);
	}

public:
	string text() {
		return text_;
	}

	void text(string set) {
		if (text_ == set)
			return;

		sfText_setString(dtext_, set.toStringz);
		dtextBounds_ = sfText_getLocalBounds(dtext_);
		dtextBounds_.width -= dtextBounds_.left;
		dtextBounds_.height -= dtextBounds_.top;

		text_ = set;
	}

	void optimalSize(Vec2I set) {
		optimalSize_ = set;
	}

public:
	override void draw(sfRenderWindow* rt, sfRenderStates* rs) {
		Vec2I center = pos_ + size_ / 2;
		sfText_setPosition(dtext_, sfVector2f(floor(center.x - dtextBounds_.width / 2), floor(center.y - dtextBounds_.height / 2)));
		sfRenderWindow_drawText(rt, dtext_, rs);
	}

private:
	sfText* dtext_;
	sfFloatRect dtextBounds_;
	string text_;

}
