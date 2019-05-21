module ac.client.main;

import bindbc.opengl;
import core.stdc.stdlib;
import core.memory;
import derelict.sfml2;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime : Duration;
import std.datetime.stopwatch;
import std.exception;
import std.file;
import std.format;
import std.getopt;
import std.json;
import std.math;
import std.range;
import std.stdio;
import std.string;
import std.datetime;

import ac.client.application;
import ac.client.game.gamerenderer;
import ac.client.gl;
import ac.client.gl.gl2ddraw;
import ac.client.gl.gldebugrenderer;
import ac.client.graphicsettings;
import ac.client.gui.guiresources;
import ac.client.gui.widgets;
import ac.client.resources;
import ac.client.world.chunkrenderregion;
import ac.client.world.gen.worldgenplatformgpu;
import ac.common.game.game;
import ac.common.math.matrix;
import ac.common.math.vector;
import ac.common.util.json;
import ac.common.util.log;
import ac.common.util.perfwatch;
import ac.common.world.blockcontext;
import ac.common.world.chunk;
import ac.common.world.collisionmanager;
import ac.common.world.env.overworld;
import ac.common.world.world;
import ac.content.content;
import ac.content.worldgen.overworld;

// These two lines force the app to run on the dedicated graphics card by default
extern (C) export ulong NvOptimusEnablement = 0x00000001;
extern (C) export int AmdPowerXpressRequestHighPerformance = 1;

version = recordingMode;

void main(string[] args) {
	DerelictSFML2System.load();
	DerelictSFML2Window.load();
	DerelictSFML2Graphics.load();

	glResourceManager = new GLResourceManager();
	scope (exit)
		glResourceManager.releaseAll();

	glState = new GLState();
	guiResources = new GUIResources();

	graphicSettings = new GraphicSettings();

	ClientApplication app = new ClientApplication();
	application = app;

	bool savePerfLogs;

	{
		auto opts = getopt(args, //
				"saveName", "Name of the save file", &app.saveName, //
				"recreate", "Recreate the save (delete all user changes)", &app.recreateWorld, //
				"fullScreen", "Start in fullscreen mode", &graphicSettings.fullScreen, //
				"debugGL", "Enable OpenGL debug mode", &app.debugGL, //
				"collectPerfData", "Collects performance data into 'perfReport_XXX.csv'", &app.collectPerfData_, //
				"savePerfLog", "Creates a perfLog.txt file with more detailed performance log data", &savePerfLogs, //
				"position", "Load position X from positions.txt file (save using F5, cycle F6)", &app.positionIx_, //
				);

		if (opts.helpWanted) {
			defaultGetoptPrinter("AnotherCraft\nAuthor: Daniel Cejchan | xcejch00 | Danol", opts.options);
			return;
		}
	}

	application.initialize();

	try {
		application.run();

		if (savePerfLogs)
			savePerfLog();
	}
	catch (Throwable t) {
		std.stdio.stderr.writeln(t.toString);
		exit(5);
	}
}

float joyVal(sfJoystickAxis axis) {
	const float baseVal = sfJoystick_getAxisPosition(0, axis) * 0.01;
	enum float deadZone = 0.2;
	return pow(clamp(abs(baseVal) - deadZone, 0, 1) / (1 - deadZone), 1.8) * sgn(baseVal);
}

class ClientApplication : Application {

public:
	this() {
		super("AnotherCraft");
	}

	~this() {
		if (ui.middleMouseHint)
			sfText_destroy(ui.middleMouseHint);
	}

protected:
	override void drawGUI() {
		enum GL_GPU_MEM_INFO_TOTAL_AVAILABLE_MEM_NVX = 0x9048;
		enum GL_GPU_MEM_INFO_CURRENT_AVAILABLE_MEM_NVX = 0x9049;

		GLint totalMemory, availableMemory;
		glGetIntegerv(GL_GPU_MEM_INFO_TOTAL_AVAILABLE_MEM_NVX, &totalMemory);
		glGetIntegerv(GL_GPU_MEM_INFO_CURRENT_AVAILABLE_MEM_NVX, &availableMemory);

		size_t usedVramKb = totalMemory - availableMemory;

		ui.fps.text = "FPS: %s (%s/%s)".format(currentFps, peakLowFps, peakFps);

		/*ui.regionsDrawn.text = "%s/%s/%s".format(ChunkRenderRegion.drawnRegions, ChunkRenderRegion.visibleRegions, ChunkRenderRegion.consideredRegions);
		ChunkRenderRegion.drawnRegions = 0;
		ChunkRenderRegion.consideredRegions = 0;
		ChunkRenderRegion.visibleRegions = 0;*/

		perfFrameCounter_++;
		if (appTime - lastPerfReport_ >= 1) {
			if (collectPerfData_ && lastPerfReport_ != 0) {
				perfDataFile_.writefln("%s;%s;%s;%s;%s;%s;%s;%s;", appTime, currentFps, peakLowFps, peakFps, GC.stats.usedSize / 1024 / 1024, usedVramKb / 1024, world.activeChunkCount, perfDataFileFields.map!(x => perfStat(x).eventCount.to!string).joiner(";"));
			}

			lastPerfReport_ = appTime;
			ui.perfReport.text = perfReport(perfFrameCounter_);
			perfFrameCounter_ = 0;
		}

		ui.pos.text = "%s".format(cameraPos_);
		ui.dayTime.value = world.dayTime;
		ui.dayTimeLabel.text = "Daytime: %s".format(world.dayTime);

		ui.memory.text = "%s/%s MB GPU (%s MB calculated)".format(usedVramKb / 1024, totalMemory / 1024, calculatedVRAMUsage / 1024 / 1024);
		ui.bufferAtlas.text = "%s/%s verts in U8 buffer".format(resources.chunkRenderBufferAtlases[0].itemsUsed, resources.chunkRenderBufferAtlases[0].itemsAllocated);
		ui.bufferAtlas2.text = "%s/%s verts in F buffer".format(resources.chunkRenderBufferAtlases[1].itemsUsed, resources.chunkRenderBufferAtlases[1].itemsAllocated);
		ui.triangleCount.text = "%s triangles drawn".format(gameRenderer.drawnTriangleCount);
		ui.activeChunks.text = "%s active chunks".format(world.activeChunkCount);

		if (graphicSettings.gui == GraphicSettings.GUI.full && !isCameraFPV_) {
			sfRenderWindow_drawText(window, ui.middleMouseHint, null);
			sfText_setPosition(ui.middleMouseHint, sfVector2f((windowSize.x - ui.middleMouseHintBounds.width) / 2, windowSize.y / 2 - ui.middleMouseHintBounds.height - 15));
		}
	}

	override void drawGL() {
		if (isKeyPressed(sfKeyP))
			world.dayTime += deltaTime * 0.1;
		if (isKeyPressed(sfKeyO))
			world.dayTime -= deltaTime * 0.1;

		glClearColor(0.22, 0.34, 0.42, 1);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		if (animationRecord_) {
			if (animationTime_ > lastRecordTime_ + 0.1) {
				animationFile_.writeln(animationValues_.map!(x => (*x).to!string).joiner(";"));
				lastRecordTime_ = animationTime_;
			}
			animationTime_ += deltaTime;
		}

		if (animationPlay_) {
			float prog = (animationTime_ - animationPlayKeyframes_[0][0]) / (animationPlayKeyframes_[1][0] - animationPlayKeyframes_[0][0]);
			foreach (i, ref val; animationValues_[1 .. $])
				*val = animationPlayKeyframes_[1][i + 1] * prog + animationPlayKeyframes_[0][i + 1] * (1 - prog);

			animationTime_ += deltaTime;
			while (animationPlayKeyframes_.length >= 2 && animationTime_ > animationPlayKeyframes_[1][0])
				animationPlayKeyframes_ = animationPlayKeyframes_[1 .. $];

			if (animationPlayKeyframes_.length < 2) {
				writeLog("Animation finished");
				animationPlay_ = false;
			}
		}
		else {
			if (isCameraFPV_ && sfRenderWindow_hasFocus(window)) {
				auto mousePos = sfMouse_getPositionRenderWindow(window);
				auto center = sfVector2i(windowSize.x / 2, windowSize.y / 2);
				Vec2F targetCameraRot = cameraRot_;
				targetCameraRot.x += (mousePos.x - center.x) * 0.003;
				targetCameraRot.y = clamp(cameraRot_.y + (mousePos.y - center.y) * 0.003, -PI / 2, PI / 2);
				sfMouse_setPositionRenderWindow(center, window);

				if (smoothCamera_)
					cameraRot_ = cameraRot_ + (targetCameraRot - cameraRot_).map!(x => sgn(x) * min(deltaTime, abs(x)));
				else
					cameraRot_ = targetCameraRot;
			}

			const Matrix rotXMatrix = Matrix.rotationZ(-cameraRot_.x);
			{
				Vec3F targetDeltaPos;
				immutable float movementSpeed = movementSpeeds[cast(int) movementMode];

				if (isKeyPressed(sfKeyW))
					targetDeltaPos += Vec3F((rotXMatrix * Vec3F(0, movementSpeed, 0)).xy, 0) * deltaTime;
				if (isKeyPressed(sfKeyS))
					targetDeltaPos += Vec3F((rotXMatrix * Vec3F(0, -movementSpeed, 0)).xy, 0) * deltaTime;
				if (isKeyPressed(sfKeyA))
					targetDeltaPos += Vec3F((rotXMatrix * Vec3F(-movementSpeed, 0, 0)).xy, 0) * deltaTime;
				if (isKeyPressed(sfKeyD))
					targetDeltaPos += Vec3F((rotXMatrix * Vec3F(movementSpeed, 0, 0)).xy, 0) * deltaTime;

				if (movementMode == MovementMode.gravityCollisions) {
					cameraVelocity_.z -= deltaTime * 20;
					targetDeltaPos += cameraVelocity_ * deltaTime;
				}
				else {
					if (isKeyPressed(sfKeyLShift) || isKeyPressed(sfKeyE))
						targetDeltaPos += Vec3F(0, 0, movementSpeed) * deltaTime;
					if (isKeyPressed(sfKeyLControl) || isKeyPressed(sfKeyQ))
						targetDeltaPos += Vec3F(0, 0, -movementSpeed) * deltaTime;
				}

				bool joystickConnected = sfJoystick_isConnected(0) != 0;
				if (joystickConnected) {
					targetDeltaPos += Vec3F((rotXMatrix * (Vec3F(joyVal(sfJoystickX), -joyVal(sfJoystickY), 0) * movementSpeed)).xy, -joyVal(sfJoystickZ) * movementSpeed) * deltaTime;

					cameraRot_.x += joyVal(sfJoystickU) * 1.2 * deltaTime;
					cameraRot_.y = clamp(cameraRot_.y + joyVal(sfJoystickV) * 1.2 * deltaTime, -PI / 2, PI / 2);
				}

				if (smoothCamera_)
					deltaPos_ = deltaPos_ + (targetDeltaPos - deltaPos_).map!(x => sgn(x) * min(deltaTime * 0.5, abs(x)));
				else
					deltaPos_ = targetDeltaPos;

				if (movementMode == MovementMode.collisions || movementMode == MovementMode.gravityCollisions) {
					// Do not move more that 0.5 blocks each frame (to prevent glitches)
					deltaPos_ = deltaPos_.map!"min(abs(a), 0.5) * sgn(a)";

					scope MutableBlockContext ctx = new MutableBlockContext();
					scope CollisionManager cmgr = new CollisionManager();
					const Vec3F colliderOffset = Vec3F(0, 0, -0.4);

					cmgr.colliderPos = cameraPos_ + colliderOffset;
					cmgr.targetColliderPos = cmgr.colliderPos + deltaPos_;
					cmgr.colliderBoxRadius = Vec3F(0.4, 0.4, 0.9);
					cmgr.colliderVelocity = cameraVelocity_;

					WorldVec cameraPosI = cameraPos_.to!WorldVec;
					WorldVec l = cameraPosI - 2;
					WorldVec h = cameraPosI + WorldVec(3, 3, 4);

					foreach (x; l.x .. h.x) {
						foreach (y; l.y .. h.y) {
							foreach (z; l.z .. h.z) {
								WorldVec pos = WorldVec(x, y, z);
								if (!world.isValidBlockPosition(pos))
									continue;
								ctx.setContext(world, pos);
								if (ctx.isAir)
									continue;
								cmgr.offset = ctx.pos.to!Vec3F;
								ctx.block.b_collision(ctx, cmgr);
							}
						}
					}

					cameraPos_ = cmgr.targetColliderPos - colliderOffset;
					cameraVelocity_ = cmgr.colliderVelocity;
					if ((isKeyPressed(sfKeySpace) || (joystickConnected && sfJoystick_isButtonPressed(0, 0))) && cmgr.isColliderOnGround)
						cameraVelocity_.z = 7;
				}
				else
					cameraPos_ += deltaPos_;
			}
		}

		gl2DDraw.viewMatrix = Matrix.orthogonal(windowSize.to!Vec2F);

		if (run_) {
			gameRenderer.cameraRot = cameraRot_;
			gameRenderer.cameraPos = cameraPos_;

			gameRenderer.issueGPUComputation();

			const WorldVec cameraChunkPos = Chunk.chunkPos(WorldVec(cameraPos_.to!WorldVec.xy, 0));
			if (Chunk chunk = world.maybeLoadChunkAt(cameraChunkPos))
				chunk.requestVisible();
			foreach (r; 1 .. graphicSettings.viewDistance + 1) {
				foreach (i; -r .. r) {
					if (Chunk chunk = world.maybeLoadChunkAt(cameraChunkPos + WorldVec(i, r, 0) * Chunk.size))
						chunk.requestVisible();
					if (Chunk chunk = world.maybeLoadChunkAt(cameraChunkPos + WorldVec(-i, -r, 0) * Chunk.size))
						chunk.requestVisible();
					if (Chunk chunk = world.maybeLoadChunkAt(cameraChunkPos + WorldVec(r, -i, 0) * Chunk.size))
						chunk.requestVisible();
					if (Chunk chunk = world.maybeLoadChunkAt(cameraChunkPos + WorldVec(-r, i, 0) * Chunk.size))
						chunk.requestVisible();
				}
			}

			world.cameraPos = cameraPos_.to!WorldVec;

			world.step(deltaTime);
			gameRenderer.render();

			gameRenderer.processGLJobs();
			world.loadNewChunks();
		}

		if (graphicSettings.gui != GraphicSettings.GUI.none)
			glDebugRenderer.drawPoint(Vec2F(0, 0), 6); // Crosshair

		glDebugRenderer.render();
	}

protected:
	override void initialize() {
		super.initialize();

		prepareResources();
		createUi();

		isCursorVisible = !isCameraFPV_;

		if (positionIx_ != -1)
			loadPositionFromFile(false);
		else
			loadPlayerPos();

		if (collectPerfData_) {
			auto time = Clock.currTime;
			perfDataFile_ = File("perfReport_%s-%s-%s.csv".format(time.hour, time.minute, time.second), "w");
			perfDataFile_.writeln("time;fps;minFps;maxFps;ram;vram;activeChunks;", perfDataFileFields.joiner(";"));
		}

		reserveMemory();

		animationValues_ = [&animationTime_, &cameraPos_.x, &cameraPos_.y, &cameraPos_.z, &cameraRot_.x, &cameraRot_.y, &gameRenderer.animationTime(), &world.dayTime];
	}

	void prepareResources() {
		resources = new Resources();
		glDebugRenderer = new GLDebugRenderer();
		gl2DDraw = new GL2DDraw();
		content = new Content();

		content.registerContent();
		resources.finish();

		game = new Game(saveName);

		if (recreateWorld) {
			game.db.execute("DELETE FROM CHUNKS");
		}

		world = new World(game, 0);
		world.worldGen = new WorldGen_Overworld().setPlatform(new WorldGenPlatform_GPU());
		world.environment = new WorldEnvironment_Overworld();

		gameRenderer = new GameRenderer();
		gameRenderer.world = world;
		gameRenderer.buildPreviewBlock = content.blockList[buildBlockIx_];
	}

	void createUi() {
		auto bl = new BoxLayoutWidget(BoxLayoutWidget.Orientation.horizontal);
		bl.margin = 8;
		bl.addItem(new SpacerWidget(SpacerWidget.Orientation.horizontal));
		{
			ui.middleMouseHint = sfText_create();
			sfText_setFont(ui.middleMouseHint, guiResources.defaultFont);
			sfText_setCharacterSize(ui.middleMouseHint, guiResources.fontSize);
			sfText_setColor(ui.middleMouseHint, guiResources.fontColor);
			sfText_setString(ui.middleMouseHint, "Press middle mouse button to toggle camera control".toStringz);
			ui.middleMouseHintBounds = sfText_getLocalBounds(ui.middleMouseHint);
			ui.middleMouseHintBounds.width -= ui.middleMouseHintBounds.left;
			ui.middleMouseHintBounds.height -= ui.middleMouseHintBounds.top;
		}

		{
			auto bl2 = new BoxLayoutWidget(BoxLayoutWidget.Orientation.vertical);
			ui.fps = new LabelWidget();
			bl2.addItem(ui.fps);

			ui.pos = new LabelWidget();
			bl2.addItem(ui.pos);

			ui.memory = new LabelWidget();
			bl2.addItem(ui.memory);

			ui.bufferAtlas = new LabelWidget();
			bl2.addItem(ui.bufferAtlas);

			ui.bufferAtlas2 = new LabelWidget();
			bl2.addItem(ui.bufferAtlas2);

			ui.triangleCount = new LabelWidget();
			bl2.addItem(ui.triangleCount);

			ui.activeChunks = new LabelWidget();
			bl2.addItem(ui.activeChunks);

			ui.surfaceData = new ComboBoxWidget(["Color", "Normal", "Depth", "White", "WorldCoords", "Aggregation", "UV coordinates"]);
			ui.surfaceData.currentItem = graphicSettings.surfaceData;
			ui.surfaceData.onCurrentItemChangedByUser = { //
				graphicSettings.surfaceData = cast(GraphicSettings.SurfaceData) ui.surfaceData.currentItem;
				graphicSettings.emitChange(GraphicSettings.Change.surfaceData);
			};
			bl2.addItem(ui.surfaceData);

			ui.shading = new ComboBoxWidget(["Shading off", "MSAA Shading", "Final pixel shading"]);
			ui.shading.currentItem = graphicSettings.shading;
			ui.shading.onCurrentItemChangedByUser = { //
				graphicSettings.shading = cast(GraphicSettings.Shading) ui.shading.currentItem;
				graphicSettings.emitChange(GraphicSettings.Change.shading);
			};
			bl2.addItem(ui.shading); /*ui.shadingArtifactCompensation = new ComboBoxWidget(["Shd artifact comp. off", "Shd artifact comp. on"]);
			ui.shadingArtifactCompensation.currentItem = cast(int) graphicSettings.shadingArtifactCompensation;
			ui.shadingArtifactCompensation.onCurrentItemChangedByUser = { //
				graphicSettings.shadingArtifactCompensation = ui.shadingArtifactCompensation.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.shadingArtifactCompensation);
			};
			bl2.addItem(ui.shadingArtifactCompensation);*/

			ui.ssao = new ComboBoxWidget(["SSAO off", "SSAO blurred", "SSAO sharp"]);
			ui.ssao.currentItem = graphicSettings.ssao;
			ui.ssao.onCurrentItemChangedByUser = { //
				graphicSettings.ssao = cast(GraphicSettings.SSAO) ui.ssao.currentItem;
				graphicSettings.emitChange(GraphicSettings.Change.ssao);
			};
			bl2.addItem(ui.ssao);

			immutable int[] msaaOpts = [1, 2, 4, 8];
			ui.msaa = new ComboBoxWidget(["MSAA OFF", "2x MSAA", "4x MSAA", "8x MSAA"]);
			ui.msaa.currentItem = msaaOpts.countUntil(graphicSettings.antiAliasing);
			ui.msaa.onCurrentItemChangedByUser = { //
				graphicSettings.antiAliasing = msaaOpts[ui.msaa.currentItem];
				graphicSettings.emitChange(GraphicSettings.Change.antiAliasing);
			};
			bl2.addItem(ui.msaa);

			ui.shadowMapping = new ComboBoxWidget(["Shadow mapping off", "Shadow mapping x1024", "Shadow mapping x2048", "Shadow mapping x4096"]);
			ui.shadowMapping.currentItem = graphicSettings.shadowMapping;
			ui.shadowMapping.onCurrentItemChangedByUser = { //
				graphicSettings.shadowMapping = cast(GraphicSettings.ShadowMapping) ui.shadowMapping.currentItem;
				graphicSettings.emitChange(GraphicSettings.Change.shadowMapping);
			};
			bl2.addItem(ui.shadowMapping);

			ui.depthOfField = new ComboBoxWidget(["DOF off", "DOF on"]);
			ui.depthOfField.currentItem = cast(int) graphicSettings.depthOfField;
			ui.depthOfField.onCurrentItemChangedByUser = { //
				graphicSettings.depthOfField = ui.depthOfField.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.depthOfField);
			};
			bl2.addItem(ui.depthOfField);

			ui.atmosphere = new ComboBoxWidget(["Atmosphere off", "Atmosphere on"]);
			ui.atmosphere.currentItem = cast(int) graphicSettings.atmosphere;
			ui.atmosphere.onCurrentItemChangedByUser = { //
				graphicSettings.atmosphere = ui.atmosphere.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.atmosphere);
			};
			bl2.addItem(ui.atmosphere);

			ui.godRays = new ComboBoxWidget(["God rays off", "God rays on"]);
			ui.godRays.currentItem = cast(int) graphicSettings.godRays;
			ui.godRays.onCurrentItemChangedByUser = { //
				graphicSettings.godRays = ui.godRays.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.godRays);
			};
			bl2.addItem(ui.godRays);

			immutable int[] viewDistanceItems = [4, 8, 10, 16, 24, 32, 48, 56, 64];
			ui.viewDistance = new ComboBoxWidget(viewDistanceItems.map!(x => "%s chunks".format(x)).array);
			ui.viewDistance.currentItem = viewDistanceItems.countUntil(graphicSettings.viewDistance);
			ui.viewDistance.onCurrentItemChangedByUser = { //
				graphicSettings.viewDistance = viewDistanceItems[ui.viewDistance.currentItem];
				reserveMemory();
			};
			bl2.addItem(ui.viewDistance);

			ui.showSingleBlendLayer = new ComboBoxWidget(["Show all blend layers", "Blend layer 0", "Blend layer 1", "Blend layer 2"]);
			ui.showSingleBlendLayer.currentItem = graphicSettings.showSingleBlendLayer + 1;
			ui.showSingleBlendLayer.onCurrentItemChangedByUser = { //
				graphicSettings.showSingleBlendLayer = cast(int) ui.showSingleBlendLayer.currentItem - 1;
				graphicSettings.emitChange(GraphicSettings.Change.showSingleBlendLayer);
			};
			bl2.addItem(ui.showSingleBlendLayer);

			ui.blendLayerCount = new ComboBoxWidget(["0 blend layers", "1 blend layer", "2 blend layers", "3 blend layers"]);
			ui.blendLayerCount.currentItem = graphicSettings.blendLayerCount;
			ui.blendLayerCount.onCurrentItemChangedByUser = { //
				graphicSettings.blendLayerCount = cast(int) ui.blendLayerCount.currentItem;
				graphicSettings.emitChange(GraphicSettings.Change.blendLayerCount);
			};
			bl2.addItem(ui.blendLayerCount);

			ui.betterTexturing = new ComboBoxWidget(["Better texturing off", "Better texturing on"]);
			ui.betterTexturing.currentItem = cast(int) graphicSettings.betterTexturing;
			ui.betterTexturing.onCurrentItemChangedByUser = { //
				graphicSettings.betterTexturing = ui.betterTexturing.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.betterTexturing);
			};
			bl2.addItem(ui.betterTexturing);

			ui.msaaAlphaTest = new ComboBoxWidget(["MSAA alpha test off", "MSAA alpha test on"]);
			ui.msaaAlphaTest.currentItem = cast(int) graphicSettings.msaaAlphaTest;
			ui.msaaAlphaTest.onCurrentItemChangedByUser = { //
				graphicSettings.msaaAlphaTest = ui.msaaAlphaTest.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.msaaAlphaTest);
			};
			bl2.addItem(ui.msaaAlphaTest);

			ui.aggregationStrategy = new ComboBoxWidget(["No aggregation", "Lines aggregation", "Squares aggregation", "Squares ext aggregation"]);
			ui.aggregationStrategy.currentItem = graphicSettings.aggregationStrategy;
			ui.aggregationStrategy.onCurrentItemChangedByUser = { //
				graphicSettings.aggregationStrategy = cast(GraphicSettings.AggregationStrategy) ui.aggregationStrategy.currentItem;
				graphicSettings.emitChange(GraphicSettings.Change.aggregationStrategy);

				foreach (ch; world.visibleChunks)
					ch.globalUpdate(Chunk.Update.staticRender);
			};
			bl2.addItem(ui.aggregationStrategy);

			ui.tJunctionHiding = new ComboBoxWidget(["T-junction hiding off", "T-junction hiding on"]);
			ui.tJunctionHiding.currentItem = cast(int) graphicSettings.tJunctionHiding;
			ui.tJunctionHiding.onCurrentItemChangedByUser = { //
				graphicSettings.tJunctionHiding = ui.tJunctionHiding.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.tJunctionHiding);
			};
			bl2.addItem(ui.tJunctionHiding);

			ui.waving = new ComboBoxWidget(["Waving off", "Waving on"]);
			ui.waving.currentItem = cast(int) graphicSettings.waving;
			ui.waving.onCurrentItemChangedByUser = { //
				graphicSettings.waving = ui.waving.currentItem > 0;
				graphicSettings.emitChange(GraphicSettings.Change.waving);

				/*foreach (ch; world.visibleChunks)
					ch.globalUpdate(Chunk.Update.staticRender);*/
			};
			bl2.addItem(ui.waving);

			ui.movement = new ComboBoxWidget(["Fast noClip move", "Slow noClip move", "Collisions", "Gravity + collisions", "Movement disabled"]);
			ui.movement.currentItem = cast(size_t) movementMode;
			ui.movement.onCurrentItemChangedByUser = { //
				movementMode = cast(MovementMode) ui.movement.currentItem;
			};
			bl2.addItem(ui.movement);

			ui.dayTimeLabel = new LabelWidget();
			bl2.addItem(ui.dayTimeLabel);

			ui.dayTime = new SliderWidget(SliderWidget.Orientation.horizontal);
			ui.dayTime.onValueChangedByUser = { //
				world.dayTime = ui.dayTime.value;
			};

			ui.dayTime.value = world.dayTime;
			ui.dayTime.onValueChangedByUser();
			bl2.addItem(ui.dayTime);

			ui.perfReport = new LabelWidget();
			ui.perfReport.optimalSize = Vec2I(300, 200);
			bl2.addItem(ui.perfReport);
			bl2.addItem(new SpacerWidget(SpacerWidget.Orientation.vertical));
			bl.addItem(bl2);
		}

		mainWidget_ = bl;
		mainWidget_.recalculate(Vec2I(), windowSize);
	}

	override void releaseResources() {
		writeln("Saving world...");
		savePlayerPos();
		world.unloadWorld();
		game.end();
	}

	override void mouseButtonPressEvent(const ref Widget.MouseButtonEvent ev) {
		if (ev.button == Widget.MouseButton.middle) {
			isCameraFPV_ ^= true;
			isCursorVisible = !isCameraFPV_;
			if (isCameraFPV_)
				sfMouse_setPositionRenderWindow(sfVector2i(windowSize.x / 2, windowSize.y / 2), window);
		}
		else if (ev.button == Widget.MouseButton.left && gameRenderer.mousePosInWorldIsValid) {
			scope BlockContext ctx = new BlockContext(world, gameRenderer.mousePosInWorld);
			writeLog("block destroy ", ctx.pos, " chunk ", ctx.chunk.pos);
			if (!ctx.isAir)
				ctx.block.b_destroy(ctx);
			else
				writeLog("block isAir");
		}
		else if (ev.button == Widget.MouseButton.right && gameRenderer.mousePosInWorldIsValid) {
			scope BlockContext ctx = new BlockContext(world, gameRenderer.mouseBuildPosInWorld);
			writeLog("block construct ", ctx.pos, " chunk ", ctx.chunk.pos);
			if (ctx.isAir)
				gameRenderer.buildPreviewBlock.b_construct(ctx);
			else
				writeLog("block isNotAir");
		}
		else if (ev.button == Widget.MouseButton.wheel) {
			buildBlockIx_ = (content.blockList.length * 2 + buildBlockIx_ + cast(size_t) ev.wheelDelta) % content.blockList.length;
			gameRenderer.buildPreviewBlock = content.blockList[buildBlockIx_];
		}
	}

	override void keyPressEvent(sfKeyCode key) {
		switch (key) {

		case sfKeyEscape:
			shouldExit_ = true;
			break;

		case sfKeyF2:
			graphicSettings.gui = ((graphicSettings.gui.to!int + 1) % GraphicSettings.GUI._count.to!int).to!(GraphicSettings.GUI);
			/*if (graphicSettings.gui == GraphicSettings.GUI.none) {
				GC.disable();
				writeLog("Disable GC");
				gcDisabled_ = true;
			}
			else if (gcDisabled_) {
				gcDisabled_ = false;
				GC.enable();
				writeLog("Enable GC");
			}*/
			graphicSettings.emitChange(GraphicSettings.Change.gui);
			break;

		case sfKeyF3:
			gameRenderer.topDownView ^= true;
			break;

		case sfKeyF4:
			gameRenderer.visualiseLoadedChunks ^= true;
			break;

		case sfKeyF5:
			append("positions.txt", JSONValue([world.dayTime, cameraPos_.x, cameraPos_.y, cameraPos_.z, cameraRot_.x, cameraRot_.y]).toString ~ "\n");
			break;

		case sfKeyF6:
			loadPositionFromFile(true);
			break;

		case sfKeyReturn:
			if (!run_) {
				run_ = true;
				runTimer_.start();
			}
			else {
				writeLog("Run timer: ", runTimer_.peek.total!"msecs", "ms");
			}
			break;

		case sfKeyF7:
			animationPlay_ = false;

			if (!animationRecord_) {
				animationRecord_ = true;
				animationTime_ = 0;
				lastRecordTime_ = -100;
				animationFile_ = File("animation.txt", "wb");
				writeLog("Started recording animation");
			}
			else {
				animationRecord_ = false;
				writeLog("Stopped recording animation");
				animationFile_.close();
			}
			break;

		case sfKeyF8:
			animationRecord_ = false;
			if (!animationPlay_) {
				if (!"animation.txt".exists)
					break;

				animationTime_ = 0;
				animationPlayKeyframes_ = File("animation.txt", "rb").byLine
					.filter!(x => x.length > 0)
					.map!(x => x.splitter(';').map!(x => x.to!float).array)
					.array;

				animationPlay_ = animationPlayKeyframes_.length > 1;
				if (animationPlay_)
					writeLog("Started playing animation");
				else
					writeLog("Animation unavailable");
			}
			else {
				animationPlay_ = false;
				writeLog("Stopped playing animation");
			}
			break;

		case sfKeyF9:
			smoothCamera_ ^= true;
			writeLog("Smooth camera: ", smoothCamera_);
			break;

		case sfKeyI:
			graphicSettings.advanceDaytimeSpeed = graphicSettings.advanceDaytimeSpeed == 0 ? 1 : fmod(graphicSettings.advanceDaytimeSpeed * 2, 16);
			break;

		default:
			break;
		}
	}

private:
	void reserveMemory() {
		size_t cap = cast(size_t)(pow(graphicSettings.viewDistance * 2 + 3, 2) * __traits(classInstanceSize, Chunk) * 1.2);
		size_t used = GC.stats.usedSize;
		if (cap > used)
			GC.reserve(cap - used);
	}

private:
	void loadPositionFromFile(bool increaseIx) {
		if (!"positions.txt".exists)
			return;

		string[] lines = File("positions.txt").byLine.map!(x => x.to!string).array;

		if (lines.length == 0)
			return;

		positionIx_ = (positionIx_ + (increaseIx ? 1 : 0)) % lines.length;

		float[] data = lines[positionIx_].parseJSON().array.map!(x => x.float_).array;
		world.dayTime = data[0];
		cameraPos_ = Vec3F(data[1], data[2], data[3]);
		cameraRot_ = Vec2F(data[4], data[5]);

		graphicSettings.advanceDaytimeSpeed = 0;
		isCameraFPV_ = false;
		isCursorVisible = true;
		movementMode = MovementMode.fastNoClip;
		ui.movement.currentItem = 0;
	}

	void loadPlayerPos() {
		auto data = game.db.execute("SELECT value FROM settings WHERE key = 'playerPos'");
		if (data.empty)
			return;

		JSONValue[string] json = data.oneValue!string.parseJSON().object;

		cameraPos_.x = json["x"].float_;
		cameraPos_.y = json["y"].float_;
		cameraPos_.z = json["z"].float_;

		cameraRot_.x = json["rotX"].float_;
		cameraRot_.y = json["rotY"].float_;
	}

	void savePlayerPos() {
		JSONValue[string] json;

		json["x"] = cameraPos_.x;
		json["y"] = cameraPos_.y;
		json["z"] = cameraPos_.z;

		json["rotX"] = cameraRot_.x;
		json["rotY"] = cameraRot_.y;

		game.db.execute("INSERT OR REPLACE INTO settings (key, value) VALUES ('playerPos', ?)", JSONValue(json).toString);
	}

public:
	string saveName = "default";
	bool recreateWorld = false;

public:
	World world;
	enum MovementMode {
		fastNoClip,
		slowNoClip,
		collisions,
		gravityCollisions,
		disabled
	}

	immutable movementSpeeds = [32, 16, 8, 8, 0];
	MovementMode movementMode = MovementMode.gravityCollisions;

private:
	bool animationRecord_, animationPlay_;
	float animationTime_, lastRecordTime_;
	float[][] animationPlayKeyframes_;
	File animationFile_;
	float*[] animationValues_;

private:
	size_t positionIx_ = -1;

private:
	Vec3F cameraPos_ = Vec3F(0, 0, 138), deltaPos_;
	Vec2F cameraRot_;
	Vec3F cameraVelocity_; // Currently only gravity
	bool isLeftMouseButtonPressed_;
	bool isCameraFPV_ = false;
	bool smoothCamera_ = false;
	size_t buildBlockIx_ = 0;

private:
	float lastPerfReport_ = -100;
	float perfFrameCounter_ = 0;

private:
	bool run_ = true;
	//bool gcDisabled_ = false;
	std.datetime.stopwatch.StopWatch runTimer_;

private:
	static string[] perfDataFileFields = ["generateChunk", "staticRenderRegion", "staticRenderRegion2", "chunkLoad", "lightMapUpdate", "lightMapUpdate2", "gpuBlockIDMapUpdate", "gcCollect"];
	bool collectPerfData_ = false;
	File perfDataFile_;

private:
	static struct UI {
		LabelWidget fps, pos, memory, bufferAtlas, bufferAtlas2, perfReport, dayTimeLabel, triangleCount, activeChunks;
		ComboBoxWidget surfaceData, ssao, msaa, viewDistance, shading, shadowMapping, depthOfField, atmosphere, showSingleBlendLayer, tJunctionHiding;
		ComboBoxWidget blendLayerCount, godRays, shadingArtifactCompensation, movement, betterTexturing, msaaAlphaTest, aggregationStrategy, waving;
		SliderWidget dayTime;
		sfText* middleMouseHint;
		sfFloatRect middleMouseHintBounds;
	}

	UI ui;
}
