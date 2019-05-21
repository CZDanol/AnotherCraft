module ac.client.gui.sliderwidget;

import ac.client.gui.devtoolkit;
import std.algorithm;

final class SliderWidget : Widget {

public:
	alias Orientation = HVOrientation;

public:
	this(Orientation orientation) {
		orientation_ = orientation;
		optimalSize_ = Vec2I(20, 20);
		optimalSize_[uint(orientation)] = 150;

		rect_ = sfRectangleShape_create();
		sfRectangleShape_setOutlineColor(rect_, guiResources.outlineColor);
		sfRectangleShape_setOutlineThickness(rect_, guiResources.outlineThickness);

		lineRect_ = sfRectangleShape_create();
		sfRectangleShape_setOutlineColor(lineRect_, guiResources.outlineColor);
		sfRectangleShape_setOutlineThickness(lineRect_, guiResources.outlineThickness);
		sfRectangleShape_setFillColor(lineRect_, guiResources.inactiveFaceColor);
	}

public:
	float value() {
		return value_;
	}

	void value(float set) {
		if (value_ == set)
			return;

		value_ = clamp(set, minValue_, maxValue_);

		if (onValueChanged)
			onValueChanged();
	}

	float minValue() {
		return minValue_;
	}

	void minValue(float set) {
		minValue_ = set;
	}

	float maxValue() {
		return maxValue_;
	}

	void maxValue(float set) {
		maxValue_ = set;
	}

public:
	override void draw(sfRenderWindow* rt, sfRenderStates* rs) {
		const float normalizedValue = (value_ - minValue_) / (maxValue_ - minValue_);
		const int sliderSize = guiResources.sliderSize;
		const int outlineThickness = guiResources.outlineThickness;

		enum lineSize = 2;

		if (orientation_ == Orientation.horizontal) {
			rectSize_ = Vec2I(sliderSize, size_.y - outlineThickness * 2);
			rectPos_ = pos_ + outlineThickness + Vec2I(cast(int)(normalizedValue * (size_.x - outlineThickness * 2 - sliderSize)), 0);

			sfRectangleShape_setSize(lineRect_, sfVector2f(size_.x - outlineThickness * 2 - sliderSize, lineSize));
			sfRectangleShape_setPosition(lineRect_, sfVector2f(pos_.x + outlineThickness + sliderSize / 2, pos_.y + (size_.y - lineSize) / 2));
		}
		else {
			rectSize_ = Vec2I(size_.x - outlineThickness * 2, sliderSize);
			rectPos_ = pos_ + outlineThickness + Vec2I(0, cast(int)(normalizedValue * (size_.y - outlineThickness * 2 - sliderSize)));

			sfRectangleShape_setSize(lineRect_, sfVector2f(2, size_.y - outlineThickness * 2 - sliderSize));
			sfRectangleShape_setPosition(lineRect_, sfVector2f(pos_.x + (size_.x - lineSize) / 2, pos_.y + outlineThickness + sliderSize / 2));
		}

		sfRectangleShape_setPosition(rect_, sfVector2f(rectPos_.x, rectPos_.y));
		sfRectangleShape_setSize(rect_, sfVector2f(rectSize_.x, rectSize_.y));

		sfRectangleShape_setFillColor(rect_, pressed_ ? guiResources.pressedFaceColor : hovered_ ? guiResources.hoveredFaceColor : guiResources.inactiveFaceColor);

		sfRenderWindow_drawRectangleShape(rt, lineRect_, rs);
		sfRenderWindow_drawRectangleShape(rt, rect_, rs);
	}

public:
	override bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		if (ev.button != sfMouseLeft)
			return true;

		if (ev.pos.x < rectPos_.x || ev.pos.y < rectPos_.y || ev.pos.x > rectPos_.x + rectSize_.x || ev.pos.y > rectPos_.y + rectSize_.y)
			return true;

		const int sliderSize = guiResources.sliderSize;
		const int outlineThickness = guiResources.outlineThickness;

		pressed_ = true;
		pressOffset_ = orientation_ == Orientation.horizontal ? ev.pos.x - rectPos_.x : ev.pos.y - rectPos_.y;
		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (!mev.buttonPressed[sfMouseLeft]) {
				pressed_ = false;
				return false;
			}

			const float normalizedValue = orientation_ == Orientation.horizontal //
			 ? float((mev.pos.x - pressOffset_) - (pos_.x + outlineThickness)) / (size_.x - outlineThickness * 2 - sliderSize) //
			 : float((mev.pos.y - pressOffset_) - (pos_.y + outlineThickness)) / (size_.y - outlineThickness * 2 - sliderSize);

			value_ = minValue_ + clamp(normalizedValue, 0.0f, 1.0f) * (maxValue_ - minValue_);

			if (onValueChanged)
				onValueChanged();

			if (onValueChangedByUser)
				onValueChangedByUser();

			return true;
		});

		return true;
	}

	override void mouseMoveEvent(const ref MouseMoveEvent ev) {
		if (hovered_ || ev.pos.x < rectPos_.x || ev.pos.y < rectPos_.y || ev.pos.x > rectPos_.x + rectSize_.x || ev.pos.y > rectPos_.y + rectSize_.y)
			return;

		hovered_ = true;
		application.addMouseEventListener((const ref Application.MouseEvent mev) {
			if (mev.pos.any!((a, b) => a < b)(pos_) || mev.pos.any!((a, b) => a >= b)(pos_ + size_)) {
				hovered_ = false;
				return false;
			}

			return true;
		});
	}

public:
	void delegate() onValueChangedByUser = null;
	void delegate() onValueChanged = null;

private:
	Orientation orientation_;

private:
	float value_ = 0, minValue_ = 0, maxValue_ = 1;

private:
	sfRectangleShape* rect_, lineRect_;
	Vec2I rectPos_, rectSize_;
	bool hovered_, pressed_;
	float pressOffset_;

}
