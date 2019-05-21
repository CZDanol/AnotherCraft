module ac.client.gui.widget;

import ac.client.gui.devtoolkit;

abstract class Widget {

public:
	enum MouseButton {
		wheel = -1,
		left,
		right,
		middle
	}

	struct MouseButtonEvent {
		Vec2I pos;
		MouseButton button;
		int wheelDelta;
	}

	struct MouseMoveEvent {
		Vec2I pos, deltaPos;
	}

public:
enum SizePolicy:
uint {
		/// Tries to set itself to optimalSize
		preffered,

		/// Tries to fill the free space, but does not force other widgets under their optimalSize
		softExpanding
	}

public:
final Vec2I size() {
		return size_;
	}

	Vec2I optimalSize() {
		return optimalSize_;
	}

	final SizePolicy[2] sizePolicy() {
		return sizePolicy_;
	}

public:
void recalculate(Vec2I position, Vec2I size) {
		pos_ = position;
		size_ = size;
	}

	void draw(sfRenderWindow *rt, sfRenderStates *rs) {

	}

public:
	/// Returns true if the event is captured by the widget and should not propagate further
	bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		return false;
	}

	/// Returns true if the event is captured by the widget and should not propagate further
	void mouseMoveEvent(const ref MouseMoveEvent ev) {

	}

protected:
	final void watchForHover(const ref MouseMoveEvent ev, ref bool hovered_) {
		if (hovered_)
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

package:
	Vec2I size_, optimalSize_;
	SizePolicy[2] sizePolicy_ = [SizePolicy.preffered, SizePolicy.preffered];
	Widget parent_;

	/// Position of the widget relative to the parent
	Vec2I pos_;

}
