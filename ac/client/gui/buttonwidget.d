module ac.client.gui.buttonwidget;

import ac.client.gui.devtoolkit;

final class ButtonWidget : Widget {

public:
	this(string label = "") {
		optimalSize_ = Vec2I(150, 20);
		text_ = label;

		dtext_ = sfText_create();
		sfText_setFont(dtext_, guiResources.defaultFont);
		sfText_setCharacterSize(dtext_, guiResources.fontSize);
		sfText_setColor(dtext_, guiResources.fontColor);
		sfText_setString(dtext_, text_.toStringz);
		dtextBounds_ = sfText_getLocalBounds(dtext_);

		rect_ = sfRectangleShape_create();
		sfRectangleShape_setOutlineColor(rect_, guiResources.outlineColor);
		sfRectangleShape_setOutlineThickness(rect_, guiResources.outlineThickness);
	}

	~this() {
		sfRectangleShape_destroy(rect_);
		sfText_destroy(dtext_);
	}

public:
	override void draw(sfRenderWindow* rt, sfRenderStates* rs) {
		sfRectangleShape_setFillColor(rect_, pressed_ ? guiResources.pressedFaceColor : hovered_ ? guiResources.hoveredFaceColor : guiResources.inactiveFaceColor);

		Vec2I sz = size_ - guiResources.outlineThickness * 2;
		sfRectangleShape_setSize(rect_, sfVector2f(sz.x, sz.y));

		Vec2I center = pos_ + size_ / 2;
		sfRectangleShape_setPosition(rect_, sfVector2f(pos_.x, pos_.y));
		sfRenderWindow_drawRectangleShape(rt, rect_, rs);

		sfText_setPosition(dtext_, sfVector2f(floor(center.x - dtextBounds_.left - dtextBounds_.width / 2), floor(center.y - dtextBounds_.top - dtextBounds_.height / 2)));
		sfRenderWindow_drawText(rt, dtext_, rs);
	}

public:
	override bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		if (ev.button != sfMouseLeft)
			return true;

		if (onClick)
			onClick();

		pressed_ = true;
		
		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (!mev.buttonPressed[sfMouseLeft]) {
				pressed_ = false;
				return false;
			}

			return true;
		});

		return true;
	}

	override void mouseMoveEvent(const ref MouseMoveEvent ev) {
		watchForHover(ev, hovered_);
	}

public:
	void delegate() onClick;

private:
	sfRectangleShape* rect_;
	sfFloatRect dtextBounds_;
	sfText* dtext_;
	string text_;
	bool hovered_, pressed_;

}
