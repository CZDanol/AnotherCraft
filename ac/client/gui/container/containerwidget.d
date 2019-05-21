module ac.client.gui.container.containerwidget;

import ac.client.gui.widget;
import ac.common.math.vector;

abstract class ContainerWidget : Widget {

	abstract override void recalculate(Vec2I position, Vec2I size);

}