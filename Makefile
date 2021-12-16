OBJS	= ./src//ui/ui_manager.o ./src//ui/checkbox.o ./src//ui/button.o ./src//ui/component.o ./src//ui/panel.o ./src//ui/label.o ./src//ui/font_renderer.o ./src//ui/rectangle.o ./src//ui/container.o ./src//ui/text_field.o ./src//rendering/color.o ./src//rendering/render_model.o ./src//rendering/baseModels/star_sphere.o ./src//rendering/baseModels/sphere.o ./src//rendering/baseModels/cube.o ./src//rendering/renderer.o ./src//universe/scene_loader.o ./src//universe/mass_body.o ./src//universe/universe.o ./src//main.o
SOURCE	= ./src//ui/ui_manager.cpp ./src//ui/checkbox.cpp ./src//ui/button.cpp ./src//ui/component.cpp ./src//ui/panel.cpp ./src//ui/label.cpp ./src//ui/font_renderer.cpp ./src//ui/rectangle.cpp ./src//ui/container.cpp ./src//ui/text_field.cpp ./src//rendering/color.cpp ./src//rendering/render_model.cpp ./src//rendering/baseModels/star_sphere.cpp ./src//rendering/baseModels/sphere.cpp ./src//rendering/baseModels/cube.cpp ./src//rendering/renderer.cpp ./src//universe/scene_loader.cpp ./src//universe/mass_body.cpp ./src//universe/universe.cpp ./src//main.cpp
HEADER	= ./src//ui/label.h ./src//ui/container.h ./src//ui/text_field.h ./src//ui/ui_palette.h ./src//ui/checkbox.h ./src//ui/panel.h ./src//ui/button.h ./src//ui/ui_manager.h ./src//ui/component.h ./src//ui/rectangle.h ./src//ui/font_renderer.h ./src//rendering/render_model.h ./src//rendering/renderer.h ./src//rendering/color.h ./src//rendering/baseModels/sphere.h ./src//rendering/baseModels/star_sphere.h ./src//rendering/baseModels/cube.h ./src//universe/scene_loader.h ./src//universe/mass_body.h ./src//universe/universe.h
OUT	= opengl-gravity-simulator
CCC=xcrun -sdk macosx clang
CC	 = $(CCC)++ -std=c++17
FLAGS	 = -target x86_64-apple-macos10.15 -g -c -Wall #$(NIX_CFLAGS_COMPILE) -I/nix/store/6wjagzn8yjca07gkpqqh6abhs32hczz6-stb-20180211/include/stb 	`pkg-config --cflags sdl2`
LFLAGS	 =  -framework OpenGL -framework Foundation -framework CoreFoundation -framework AppKit -framework CoreGraphics -framework Accelerate #$(NIX_LDFLAGS) `pkg-config --list-all | awk '{print $$1}' | xargs -n 1 pkg-config --libs-only-l`
OBJCFLAGS= -x objective-c -fmessage-length=0 -fdiagnostics-show-note-include-stack -fmacro-backtrace-limit=0 -std=gnu11 -fobjc-arc -fobjc-weak -fmodules -gmodules

objs2=src/main.o $(patsubst %.m,%.o,$(wildcard src/EEPixelViewer/*.m)) ./src//Impl_EEPixelViewerGitHub.o
all: $(objs2)
	$(CCC) -g $(objs2) -o $(OUT) $(LFLAGS)
	#$(CC) -g $(OBJS) -o $(OUT) $(LFLAGS)

./src//ui/ui_manager.o: ./src//ui/ui_manager.cpp
	$(CC) $(FLAGS) ./src//ui/ui_manager.cpp -o $@

./src//ui/checkbox.o: ./src//ui/checkbox.cpp
	$(CC) $(FLAGS) ./src//ui/checkbox.cpp -o $@

./src//ui/button.o: ./src//ui/button.cpp
	$(CC) $(FLAGS) ./src//ui/button.cpp -o $@

./src//ui/component.o: ./src//ui/component.cpp
	$(CC) $(FLAGS) ./src//ui/component.cpp -o $@

./src//ui/panel.o: ./src//ui/panel.cpp
	$(CC) $(FLAGS) ./src//ui/panel.cpp -o $@

./src//ui/label.o: ./src//ui/label.cpp
	$(CC) $(FLAGS) ./src//ui/label.cpp -o $@

./src//ui/font_renderer.o: ./src//ui/font_renderer.cpp
	$(CC) $(FLAGS) ./src//ui/font_renderer.cpp -o $@

./src//ui/rectangle.o: ./src//ui/rectangle.cpp
	$(CC) $(FLAGS) ./src//ui/rectangle.cpp -o $@

./src//ui/container.o: ./src//ui/container.cpp
	$(CC) $(FLAGS) ./src//ui/container.cpp -o $@

./src//ui/text_field.o: ./src//ui/text_field.cpp
	$(CC) $(FLAGS) ./src//ui/text_field.cpp -o $@

./src//rendering/color.o: ./src//rendering/color.cpp
	$(CC) $(FLAGS) ./src//rendering/color.cpp -o $@

./src//rendering/render_model.o: ./src//rendering/render_model.cpp
	$(CC) $(FLAGS) ./src//rendering/render_model.cpp -o $@

./src//rendering/baseModels/star_sphere.o: ./src//rendering/baseModels/star_sphere.cpp
	$(CC) $(FLAGS) ./src//rendering/baseModels/star_sphere.cpp -o $@

./src//rendering/baseModels/sphere.o: ./src//rendering/baseModels/sphere.cpp
	$(CC) $(FLAGS) ./src//rendering/baseModels/sphere.cpp -o $@

./src//rendering/baseModels/cube.o: ./src//rendering/baseModels/cube.cpp
	$(CC) $(FLAGS) ./src//rendering/baseModels/cube.cpp -o $@

./src//rendering/renderer.o: ./src//rendering/renderer.cpp
	$(CC) $(FLAGS) ./src//rendering/renderer.cpp -o $@

./src//universe/scene_loader.o: ./src//universe/scene_loader.cpp
	$(CC) $(FLAGS) ./src//universe/scene_loader.cpp -o $@

./src//universe/mass_body.o: ./src//universe/mass_body.cpp
	$(CC) $(FLAGS) ./src//universe/mass_body.cpp -o $@

./src//universe/universe.o: ./src//universe/universe.cpp
	$(CC) $(FLAGS) ./src//universe/universe.cpp -o $@

# ./src//main.o: ./src//main.cpp
# 	$(CC) $(FLAGS) ./src//main.cpp -o $@

./src//main.o: ./src//main.m
	@echo hi4
	$(CCC) $(FLAGS) $(OBJCFLAGS) ./src//main.m -o $@
./src//MyOpenGLView.o: ./src//MyOpenGLView.m
	@echo hi3
	$(CCC) $(FLAGS) $(OBJCFLAGS) ./src//MyOpenGLView.m -o $@
./src//Impl_EEPixelViewerGitHub.o: ./src//Impl_EEPixelViewerGitHub.m
	@echo hi2
	$(CCC) $(FLAGS) $(OBJCFLAGS) ./src//Impl_EEPixelViewerGitHub.m -o $@
%.o: %.m
	@echo hi
	$(CCC) $(FLAGS) $(OBJCFLAGS) $< -o $@


clean:
	rm -f $(OBJS) $(OUT)
