module ac.client.gui.spacerwidget;

import ac.client.gui.devtoolkit;

final class SpacerWidget : Widget {

public:
	alias Orientation = HVOrientation;

public:
	this(Orientation orientation) {
		orientation_ = orientation;
		sizePolicy_[uint(orientation_)] = SizePolicy.softExpanding;
	}

private:
	Orientation orientation_;

}
