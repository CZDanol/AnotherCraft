module ac.client.gui.comboboxwidget;

import ac.client.gui.devtoolkit;
import std.algorithm;

final class ComboBoxWidget : Widget {
	enum radius = 2;

public:
	this(string[] items) {
		optimalSize_ = Vec2I(150, 20);
		items_ = items;

		text_ = sfText_create();
		sfText_setFont(text_, guiResources.defaultFont);
		sfText_setCharacterSize(text_, guiResources.fontSize);
		sfText_setColor(text_, guiResources.fontColor);

		rect_ = sfRectangleShape_create();
		sfRectangleShape_setOutlineColor(rect_, guiResources.outlineColor);
		sfRectangleShape_setOutlineThickness(rect_, guiResources.outlineThickness);

		triangle_ = sfCircleShape_create();
		sfCircleShape_setPointCount(triangle_, 3);
		sfCircleShape_setRadius(triangle_, radius);
		sfCircleShape_setOutlineColor(triangle_, guiResources.outlineColor);
		sfCircleShape_setOutlineThickness(triangle_, guiResources.outlineThickness);
		sfCircleShape_rotate(triangle_, 180);

		updateText();
	}

	~this() {
		sfRectangleShape_destroy(rect_);
		sfCircleShape_destroy(triangle_);
		sfText_destroy(text_);
	}

public:
	size_t currentItem() {
		return currentItem_;
	}

	void currentItem(size_t set) {
		currentItem_ = min(items_.length - 1, max(0, set));
		updateText();
	}

public:
	override void draw(sfRenderWindow* rt, sfRenderStates* rs) {
		sfRectangleShape_setFillColor(rect_, hovered_ ? guiResources.hoveredFaceColor : guiResources.inactiveFaceColor);

		Vec2I sz = size_ - guiResources.outlineThickness * 2;
		sfRectangleShape_setSize(rect_, sfVector2f(sz.x, sz.y));

		Vec2I rectCenter = pos_ + guiResources.outlineThickness + sz / 2;
		sfRectangleShape_setPosition(rect_, sfVector2f(pos_.x + guiResources.outlineThickness, pos_.y + guiResources.outlineThickness));
		sfRenderWindow_drawRectangleShape(rt, rect_, rs);

		sfCircleShape_setPosition(triangle_, sfVector2f(pos_.x + size_.x - guiResources.outlineThickness * 2 - 8, pos_.y + cast(int)(size_.y / 2.0f + radius / sqrt(2.0f))));
		sfRenderWindow_drawCircleShape(rt, triangle_, rs);

		sfFloatRect b = sfText_getLocalBounds(text_);
		sfText_setPosition(text_, sfVector2f(floor(rectCenter.x - b.left - b.width / 2), floor(rectCenter.y - b.top - b.height / 2)));
		sfRenderWindow_drawText(rt, text_, rs);
	}

	bool overlayDraw(sfRenderWindow* rt, sfRenderStates* rs) {
		foreach (size_t i, string item; items_) {
			Vec2I pos = pos_ + guiResources.outlineThickness + Vec2I(0, (cast(int)(i) + 1) * size_.y);

			sfRectangleShape_setFillColor(rect_, i == currentItem_ ? guiResources.pressedFaceColor : guiResources.inactiveFaceColor);
			sfRectangleShape_setPosition(rect_, sfVector2f(pos.x, pos.y));
			sfRenderWindow_drawRectangleShape(rt, rect_, rs);

			sfText_setString(text_, items_[i].toStringz);
			sfFloatRect b = sfText_getLocalBounds(text_);

			pos += size_ / 2 - Vec2F(b.left + b.width / 2, b.top + b.height / 2).to!Vec2I;

			sfText_setPosition(text_, sfVector2f(pos.x, pos.y));
			sfRenderWindow_drawText(rt, text_, rs);
		}

		updateText();

		return pressed_;
	}

public:
	override bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		if (ev.button != sfMouseLeft)
			return true;

		pressed_ = true;
		pressedItem_ = currentItem_;

		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (!mev.buttonPressed[sfMouseLeft]) {
				pressed_ = false;
				return false;
			}

			size_t oldCurrentItem = currentItem_;

			int newItem = min(items_.length - 1, max(-1, cast(int) floor(float(mev.pos.y - pos_.y - size_.y) / size_.y)));

			if (newItem >= 0)
				currentItem_ = newItem;

			if (oldCurrentItem == currentItem_)
				return true;

			updateText();
			if (onCurrentItemChangedByUser)
				onCurrentItemChangedByUser();

			return true;
		});
		application.addOverlayDraw(&overlayDraw);

		return true;
	}

	override void mouseMoveEvent(const ref MouseMoveEvent ev) {
		watchForHover(ev, hovered_);
	}

public:
	void delegate() onCurrentItemChangedByUser = null;

protected:
	void updateText() {
		sfText_setString(text_, items_[currentItem_].toStringz);
	}

private:
	string[] items_;
	size_t currentItem_;

private:
	sfRectangleShape* rect_;
	sfCircleShape* triangle_;
	sfText* text_;
	string label_;
	bool hovered_, pressed_;

	size_t pressedItem_;

}
