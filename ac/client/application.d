module ac.client.application;

import bindbc.opengl;
import core.thread;
import core.memory;
import derelict.sfml2;
import std.algorithm;
import std.conv;
import std.datetime : Duration;
import std.datetime.stopwatch;
import std.exception;
import std.format;
import std.stdio;
import std.string;

import ac.client.gl;
import ac.client.graphicsettings;
import ac.client.gui.widget;
import ac.common.math.vector;
import ac.common.util.log;
import ac.common.util.perfwatch;
import ac.common.util.set;

version (profileGC)
	enum profileOpts = " profile:1";
else
	enum profileOpts = "";

extern (C) __gshared bool rt_envvars_enabled = true;
extern (C) __gshared string[] rt_options = ["gcopt=minPoolSize:200" ~ profileOpts];

__gshared Application application;

/// How many seconds passed between current and previous frame
__gshared float deltaTime = 0;

/// How many seconds passed since application start; is updated each application step
__gshared float appTime = 0;

/// How many seconds passed since aplication start; returns immediate value
pragma(inline) float appTimeNow() {
	return application.appTimer_.peek.total!"usecs" / 1_000_000.0f;
}

abstract class Application {

public:
	alias MouseEventListener = bool delegate(const ref MouseEvent);

	struct MouseEvent {
		Vec2I pos, deltaPos;
		bool[sfMouseButtonCount] buttonPressed;
		int wheelDelta;
	}

	alias OverlayDraw = bool delegate(sfRenderWindow* rt, sfRenderStates* rs);

public:
	this(string windowTitle) {
		windowTitle_ = windowTitle;
		version (profileGC)
			lastGCStats_ = GC.profileStats;
	}

public:
	final size_t currentFps() {
		return currentFps_;
	}

	final size_t peakFps() {
		return currentPeakFps_;
	}

	final size_t peakLowFps() {
		return currentPeakLowFps_;
	}

	final Vec2I windowSize() {
		return windowSize_;
	}

	final sfRenderWindow* window() {
		return window_;
	}

public:
	final private void initWindow() {
		windowSize_ = Vec2I(1920, 1080);

		sfContextSettings contextSettings = sfContextSettings(24, 8, 1, 4, 5, debugGL ? sfContextDebug : 0);
		window_ = sfRenderWindow_create(sfVideoMode(windowSize_.x, windowSize_.y, 32), windowTitle_.toStringz, graphicSettings.fullScreen ? sfFullscreen : sfDefaultStyle, &contextSettings);
		view_ = sfView_copy(sfRenderWindow_getDefaultView(window_));
		graphicSettings.resolution = windowSize_;
	}

	/// When overriding, call the parent function first
	void initialize() {
		initWindow();

		GLSupport glSupport = loadOpenGL();
		enforce(glSupport != GLSupport.noLibrary, "OpenGL library failed to load");
		enforce(glSupport != GLSupport.badLibrary, "OpenGL bad library");
		enforce(glSupport != GLSupport.noContext, "OpenGL context was not created");
		enforce(glSupport >= GLSupport.gl45, "This application requires at least OpenGL v4.5 to run (currently %s)".format(glSupport));
		enforce(hasARBBindlessTexture, "The graphics card does not support GL_ARB_bindless_texture");
		//enforce(hasARBShaderDrawParameters, "The graphics card does not support ARB_shader_draw_parameters");
		enforce(hasARBTextureFilterAnisotropic, "The graphics card does not support ARB_texture_filter_anisotropic");
	}

	~this() {
		if (window_)
			sfRenderWindow_destroy(window_);
	}

	final void run() {
		appTimer_ = StopWatch(AutoStart.yes);

		sfEvent event;
		mainLoop: while (!shouldExit_) {
			sfJoystick_update();
			while (sfRenderWindow_pollEvent(window_, &event)) {
				switch (event.type) {

				case sfEvtClosed:
					break mainLoop;

				case sfEvtResized:
					windowSize_ = Vec2I(event.size.width, event.size.height);
					mousePos_ = mousePos_.combine!"min(a,b)"(windowSize_);

					sfView_reset(view_, sfFloatRect(0, 0, event.size.width, event.size.height));
					sfRenderWindow_setView(window_, view_);

					glViewport(0, 0, windowSize_.x, windowSize_.y);

					if (mainWidget_)
						mainWidget_.recalculate(Vec2I(), windowSize_);

					foreach (w; screenResizeWatchers.byValue)
						w();

					graphicSettings.resolution = windowSize_;
					graphicSettings.emitChange(GraphicSettings.Change.resolution);

					break;

				case sfEvtMouseButtonPressed:
					pressedMouseButtons_[event.mouseButton.button] = true;
					{
						MouseEvent ev = MouseEvent(mousePos_, Vec2I(), pressedMouseButtons_, 0);
						emitMouseEvent(ev);
					}
					{
						Widget.MouseButtonEvent ev;
						ev.pos = mousePos_;
						ev.button = cast(Widget.MouseButton) event.mouseButton.button;

						if (!mainWidget_ || !mainWidget_.mouseButtonPressEvent(ev))
							mouseButtonPressEvent(ev);
					}
					break;

				case sfEvtMouseButtonReleased:
					pressedMouseButtons_[event.mouseButton.button] = false;

					MouseEvent ev = MouseEvent(mousePos_, Vec2I(), pressedMouseButtons_, 0);
					emitMouseEvent(ev);
					break;

				case sfEvtMouseMoved:
					Vec2I prevMousePos = mousePos_;
					mousePos_ = Vec2I(event.mouseMove.x, event.mouseMove.y);

					{
						MouseEvent ev = MouseEvent(mousePos_, mousePos_ - prevMousePos, pressedMouseButtons_, 0);
						emitMouseEvent(ev);
					}
					{
						Widget.MouseMoveEvent ev;
						ev.pos = mousePos_;
						ev.deltaPos = mousePos_ - prevMousePos;

						if (mainWidget_)
							mainWidget_.mouseMoveEvent(ev);
					}
					break;

				case sfEvtMouseWheelMoved: {
						MouseEvent ev = MouseEvent(mousePos_, Vec2I(), pressedMouseButtons_, event.mouseWheel.delta);
						emitMouseEvent(ev);
					}
					{
						Widget.MouseButtonEvent ev;
						ev.pos = mousePos_;
						ev.button = Widget.MouseButton.wheel;
						ev.wheelDelta = event.mouseWheel.delta;

						if (!mainWidget_ || !mainWidget_.mouseButtonPressEvent(ev))
							mouseButtonPressEvent(ev);
					}
					break;

				case sfEvtKeyPressed:
					pressedKeys_ += event.key.code;
					keyPressEvent(event.key.code);
					break;

				case sfEvtKeyReleased:
					pressedKeys_ -= event.key.code;
					break;

				default:
					break;

				}
			}

			sfRenderWindow_clear(window_, sfBlack);

			glState.forget();

			drawGL();

			glState.reset();
			sfRenderWindow_resetGLStates(window_);

			if (mainWidget_ && graphicSettings.gui == GraphicSettings.GUI.full)
				mainWidget_.draw(window_, null);

			drawGUI();

			{
				OverlayDraw[] newOverlayDraws;
				foreach (OverlayDraw draw; overlayDraws_) {
					if (draw(window_, null))
						newOverlayDraws ~= draw;
				}
				overlayDraws_ = newOverlayDraws;
			}

			// Time measurement stuff
			{
				Duration appTimerValue = appTimer_.peek;
				appTime = appTimerValue.total!"usecs" / 1_000_000.0f;
				deltaTime = (appTimerValue - lastFrameTime_).total!"usecs" / 1_000_000.0f;
				lastFrameTime_ = appTimerValue;

				freeTime_ += deltaTime * freeTimePool + max(0, targetFrameTime_ - deltaTime);
				freeTime_ = clamp(freeTime_, -1.0f, maxFrameLag * targetFrameTime_);
				canHaveFreeTime_ = true;

				// Frame counting
				size_t immediateFps = cast(size_t)(1 / deltaTime);
				peakFps_ = max(peakFps_, immediateFps);
				peakLowFps_ = min(peakLowFps_, immediateFps);

				fpsAccum_ += deltaTime;
				frameCounter_++;
				if (fpsAccum_ >= 1) {
					fpsAccum_ = 0;
					currentFps_ = frameCounter_;
					currentPeakFps_ = peakFps_;
					currentPeakLowFps_ = peakLowFps_;
					peakFps_ = 0;
					peakLowFps_ = 100000;
					frameCounter_ = 0;
				}
			}

			sfRenderWindow_display(window_);
			glResourceManager.cleanup();

			version (profileGC) {
				GC.ProfileStats stats = GC.profileStats;
				if (stats.numCollections != lastGCStats_.numCollections) {
					writeLog("GC run %s, %s".format(stats.numCollections, stats.totalCollectionTime - lastGCStats_.totalCollectionTime));
					customPerfReport((stats.totalCollectionTime - lastGCStats_.totalCollectionTime).total!"msecs" / 1000.0f, "gcCollect", null);
					lastGCStats_ = stats;
				}
			}
		}

		releaseResources();
	}

public:
	/// Calls the listener for any mouse event until the function returns false
	final void addMouseEventListener(MouseEventListener listener) {
		mouseEventListeners_ ~= listener;
	}

	final bool isKeyPressed(sfKeyCode key) {
		return key in pressedKeys_;
	}

	final bool isMouseButtonPressed(sfMouseButton btn) {
		return pressedMouseButtons_[btn];
	}

	final Vec2I mousePos() {
		return mousePos_;
	}

	final void isCursorVisible(bool set) {
		sfRenderWindow_setMouseCursorVisible(window_, set);
	}

	/// Calls the draw function atop the GUI draw until the function returns false
	final void addOverlayDraw(OverlayDraw draw) {
		overlayDraws_ ~= draw;
	}

public:
	pragma(inline) final float deltaTimeFromFrameStart() {
		return (appTimer_.peek - lastFrameTime_).total!"usecs" / 1_000_000.0f;
	}

	static struct FreeTimeGuard {

	public:
		 ~this() {
			if (isOpen) {
				const float duration = appTimeNow - appTimeStart_;
				application.freeTime_ -= duration;
				customPerfReport(duration, perfReportName_, null);
			}
		}

	public:
		pragma(inline) bool isOpen() {
			return result_;
		}

		alias isOpen this;

	private:
		bool result_;
		string perfReportName_;
		float appTimeStart_;

	}

	/// Returns if the application has free time to do job with $priority
	/// Do not use this for doing the job (use freeTimeGuard instead which also tracks how much time the job took)
	/// This is only used for pretest purposes
	pragma(inline) final bool hasFreeTime(float priority = 0.5) {
		if (!canHaveFreeTime_)
			return false;

		canHaveFreeTime_ = freeTime_ + clamp(priority, 0, 1) * maxFrameLag * targetFrameTime_ > 0;
		return canHaveFreeTime_;
	}

	/// Returns if there is time remaining for non-critical tasks (so that the application lag is reduced)
	/// Priority 0 - 1 (1 - max)
	pragma(inline) final FreeTimeGuard freeTimeGuard(string perfGuardName, float priority = 0.5) {
		if (hasFreeTime(priority))
			return FreeTimeGuard(true, perfGuardName, appTimeNow);
		else
			return FreeTimeGuard(false);
	}

	pragma(inline) final FreeTimeGuard condFreeTimeGuard(bool cond, string perfGuardName, float priority = 0.5) {
		if (!cond)
			return FreeTimeGuard(false);

		return freeTimeGuard(perfGuardName, priority);
	}

	pragma(inline) final FreeTimeGuard condFreeTimeGuard(uint cond, string perfGuardName, float priority = 0.5) {
		return condFreeTimeGuard(cond != 0, perfGuardName, priority);
	}

public:
	void delegate()[void* ] screenResizeWatchers;

protected:
	void mouseButtonPressEvent(const ref Widget.MouseButtonEvent ev) {

	}

	void keyPressEvent(sfKeyCode key) {

	}

protected:
	void drawGUI() {
	}

	void drawGL() {

	}

	void releaseResources() {

	}

private:
	void emitMouseEvent(const ref MouseEvent ev) {
		MouseEventListener[] newMouseEventListeners;

		foreach (MouseEventListener listener; mouseEventListeners_) {
			if (listener(ev))
				newMouseEventListeners ~= listener;
		}
		mouseEventListeners_ = newMouseEventListeners;
	}

protected:
	Widget mainWidget_;
	bool shouldExit_;
	public bool debugGL;

private:
	sfRenderWindow* window_;
	sfView* view_;
	string windowTitle_;
	Vec2I windowSize_;

private:
	StopWatch appTimer_;
	Duration lastFrameTime_;
	size_t frameCounter_, currentFps_, peakFps_, peakLowFps_, currentPeakFps_, currentPeakLowFps_;
	float targetFrameTime_ = 1 / 60.0f, fpsAccum_ = 0, freeTime_ = 0;
	bool canHaveFreeTime_;

	/// How many frames time we have to distribute to complex computations (how many frames worth of computations can be done in one frame)
	enum maxFrameLag = 0.5;
	enum freeTimePool = 0.2; ///< How many time can be dedicated to extra calculations per second

private:
	bool[sfMouseButtonCount] pressedMouseButtons_;
	Vec2I mousePos_;
	MouseEventListener[] mouseEventListeners_;
	OverlayDraw[] overlayDraws_;
	Set!(sfKeyCode) pressedKeys_;

private:
	version (profileGC) GC.ProfileStats lastGCStats_;

}
