module ac.client.gui.container.boxlayoutwidget;

import ac.client.gui.devtoolkit;
import std.algorithm;
import std.conv;

final class BoxLayoutWidget : ContainerWidget {

public:
	alias Orientation = HVOrientation;

public:
	this(Orientation orientation) {
		orientation_ = orientation;
	}

public:
	void addItem(Widget item) {
		items_ ~= item;
		item.parent_ = this;
		needsOptimalSizeRecalc_ = true;
	}

public:
	int margin() const {
		return margin_;
	}

	void margin(int set) {
		margin_ = set;
	}

	override Vec2I optimalSize() {
		if (!needsOptimalSizeRecalc_)
			return optimalSize_;

		const int orientationDim = int(orientation_);
		const int otherDim = 1 - orientationDim;

		optimalSize_[orientationDim] = items_.map!(x => x.optimalSize[orientationDim]).sum;
		optimalSize_[otherDim] = items_.map!(x => x.optimalSize[otherDim]).maxElement;

		needsOptimalSizeRecalc_ = false;
		return optimalSize_;
	}

public:
	override void recalculate(Vec2I position, Vec2I size) {
		pos_ = position;
		size_ = size;

		// Ensure optimalSize is calculated
		optimalSize();

		const int orientationDim = int(orientation_);
		const int otherDim = 1 - orientationDim;

		const SizePolicy mostAggresiveSizePolicy = items_.map!(x => uint(x.sizePolicy_[orientationDim]))
			.maxElement
			.to!SizePolicy;
		const size_t mostAggresizeSizePolicyWidgetCount = items_.count!(x => x.sizePolicy_[orientationDim] == mostAggresiveSizePolicy);

		float sizeToDistribute = size_[orientationDim] - optimalSize[orientationDim] - spacing_ * (items_.length - 1) - margin_ * 2;
		float remainingDistributionUnits = 0;
		float delegate(Widget) unitsPerWidget;

		if (size_[orientationDim] < optimalSize_[orientationDim]) {
			remainingDistributionUnits = items_.length;
			unitsPerWidget = x => 0;
		}

		else if (mostAggresiveSizePolicy == SizePolicy.preffered) {
			remainingDistributionUnits = items_.length;
			unitsPerWidget = x => 1;
		}

		else {
			remainingDistributionUnits = mostAggresizeSizePolicyWidgetCount;
			unitsPerWidget = x => x.sizePolicy_[orientationDim] == SizePolicy.softExpanding ? 1 : 0;
		}

		Vec2I newItemSize, newItemPos;
		newItemSize[otherDim] = size_[otherDim] - margin_ * 2;
		newItemPos = pos_ + margin;

		foreach (Widget item; items_) {
			const float units = unitsPerWidget(item);
			int distributedSize = units ? cast(int)(sizeToDistribute / remainingDistributionUnits * units) : 0;

			newItemSize[orientationDim] = item.optimalSize[orientationDim] + distributedSize;
			item.recalculate(newItemPos, newItemSize);

			newItemPos[orientationDim] += item.size_[orientationDim] + spacing_;
			sizeToDistribute -= distributedSize;
			remainingDistributionUnits -= units;
		}
	}

	override void draw(sfRenderWindow* rt, sfRenderStates* rs) {
		foreach (Widget item; items_)
			item.draw(rt, rs);
	}

public:
	override bool mouseButtonPressEvent(const ref MouseButtonEvent ev) {
		foreach (Widget item; items_) {
			if (ev.pos.all!((a, b) => a >= b)(item.pos_) && ev.pos.all!((a, b) => a < b)(item.pos_ + item.size_) && item.mouseButtonPressEvent(ev))
				return true;
		}

		return false;
	}

	override void mouseMoveEvent(const ref MouseMoveEvent ev) {
		foreach (Widget item; items_) {
			if (ev.pos.all!((a, b) => a >= b)(item.pos_) && ev.pos.all!((a, b) => a < b)(item.pos_ + item.size_))
				item.mouseMoveEvent(ev);
		}
	}

private:
	Orientation orientation_;
	bool needsOptimalSizeRecalc_;
	int spacing_ = 3;
	int margin_;

private:
	Widget[] items_;

}
