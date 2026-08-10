#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p source/module
mkdir -p include/module include/module/pygame_sdl2 include/module/src

link_file() {
    local src="$1"
    local dst="$2"
    local abs_src

    abs_src="$(realpath "$src")"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$abs_src" "$dst"

    # Older runs could leave forwarding links in the project root. Only remove
    # those links when they point back at the destination we just created.
    local root_link="$(basename "$dst")"
    if [ "$root_link" != "$dst" ] && [ -L "$root_link" ]; then
        local target
        target="$(readlink "$root_link")"
        if [ "$target" = "$dst" ] || [ "$target" = "$SCRIPT_DIR/$dst" ]; then
            rm -f "$root_link"
        fi
    fi
}

link_file pygame_sdl2-source/gen3-static/pygame_sdl2.color.c source/module/pygame_sdl2.color.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.controller.c source/module/pygame_sdl2.controller.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.display.c source/module/pygame_sdl2.display.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.draw.c source/module/pygame_sdl2.draw.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.error.c source/module/pygame_sdl2.error.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.event.c source/module/pygame_sdl2.event.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.font.c source/module/pygame_sdl2.font.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.gfxdraw.c source/module/pygame_sdl2.gfxdraw.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.image.c source/module/pygame_sdl2.image.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.joystick.c source/module/pygame_sdl2.joystick.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.key.c source/module/pygame_sdl2.key.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.locals.c source/module/pygame_sdl2.locals.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.mixer.c source/module/pygame_sdl2.mixer.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.mixer_music.c source/module/pygame_sdl2.mixer_music.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.mouse.c source/module/pygame_sdl2.mouse.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.power.c source/module/pygame_sdl2.power.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.pygame_time.c source/module/pygame_sdl2.pygame_time.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.rect.c source/module/pygame_sdl2.rect.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.render.c source/module/pygame_sdl2.render.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.rwobject.c source/module/pygame_sdl2.rwobject.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.scrap.c source/module/pygame_sdl2.scrap.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.surface.c source/module/pygame_sdl2.surface.c
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.transform.c source/module/pygame_sdl2.transform.c

link_file pygame_sdl2-source/src/SDL2_rotozoom.c source/module/SDL2_rotozoom.c
link_file pygame_sdl2-source/src/SDL_gfxPrimitives.c source/module/SDL_gfxPrimitives.c
link_file pygame_sdl2-source/src/alphablit.c source/module/alphablit.c
link_file pygame_sdl2-source/src/write_jpeg.c source/module/write_jpeg.c
link_file pygame_sdl2-source/src/write_png.c source/module/write_png.c

link_file renpy-source/module/IMG_savepng.c source/module/IMG_savepng.c
link_file renpy-source/module/core.c source/module/core.c
link_file renpy-source/module/egl_none.c source/module/egl_none.c
link_file renpy-source/module/ffmedia.c source/module/ffmedia.c
link_file renpy-source/module/ftsupport.c source/module/ftsupport.c

link_file renpy-source/module/gen3-static/_renpy.c source/module/_renpy.c
link_file renpy-source/module/gen3-static/_renpybidi.c source/module/_renpybidi.c
link_file renpy-source/module/gen3-static/renpy.audio.renpysound.c source/module/renpy.audio.renpysound.c
link_file renpy-source/module/gen3-static/renpy.display.accelerator.c source/module/renpy.display.accelerator.c
link_file renpy-source/module/gen3-static/renpy.display.matrix.c source/module/renpy.display.matrix.c
link_file renpy-source/module/gen3-static/renpy.display.render.c source/module/renpy.display.render.c
link_file renpy-source/module/gen3-static/renpy.gl.gl.c source/module/renpy.gl.gl.c
link_file renpy-source/module/gen3-static/renpy.gl.gldraw.c source/module/renpy.gl.gldraw.c
link_file renpy-source/module/gen3-static/renpy.gl.glenviron_shader.c source/module/renpy.gl.glenviron_shader.c
link_file renpy-source/module/gen3-static/renpy.gl.glrtt_copy.c source/module/renpy.gl.glrtt_copy.c
link_file renpy-source/module/gen3-static/renpy.gl.glrtt_fbo.c source/module/renpy.gl.glrtt_fbo.c
link_file renpy-source/module/gen3-static/renpy.gl.gltexture.c source/module/renpy.gl.gltexture.c
link_file renpy-source/module/gen3-static/renpy.parsersupport.c source/module/renpy.parsersupport.c
link_file renpy-source/module/gen3-static/renpy.pydict.c source/module/renpy.pydict.c
link_file renpy-source/module/gen3-static/renpy.style.c source/module/renpy.style.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_activate_functions.c source/module/renpy.styledata.style_activate_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_functions.c source/module/renpy.styledata.style_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_hover_functions.c source/module/renpy.styledata.style_hover_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_idle_functions.c source/module/renpy.styledata.style_idle_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_insensitive_functions.c source/module/renpy.styledata.style_insensitive_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_selected_activate_functions.c source/module/renpy.styledata.style_selected_activate_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_selected_functions.c source/module/renpy.styledata.style_selected_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_selected_hover_functions.c source/module/renpy.styledata.style_selected_hover_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_selected_idle_functions.c source/module/renpy.styledata.style_selected_idle_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.style_selected_insensitive_functions.c source/module/renpy.styledata.style_selected_insensitive_functions.c
link_file renpy-source/module/gen3-static/renpy.styledata.styleclass.c source/module/renpy.styledata.styleclass.c
link_file renpy-source/module/gen3-static/renpy.styledata.stylesets.c source/module/renpy.styledata.stylesets.c
link_file renpy-source/module/gen3-static/renpy.text.ftfont.c source/module/renpy.text.ftfont.c
link_file renpy-source/module/gen3-static/renpy.text.hbfont.c source/module/renpy.text.hbfont.c
link_file renpy-source/module/gen3-static/renpy.audio.filter.c source/module/renpy.audio.filter.c
link_file renpy-source/module/gen3-static/renpy.text.textsupport.c source/module/renpy.text.textsupport.c
link_file renpy-source/module/gen3-static/renpy.text.texwrap.c source/module/renpy.text.texwrap.c

link_file renpy-source/module/renpybidicore.c source/module/renpybidicore.c
link_file renpy-source/module/renpysound_core.c source/module/renpysound_core.c
link_file renpy-source/module/subpixel.c source/module/subpixel.c
link_file renpy-source/module/ttgsubtable.c source/module/ttgsubtable.c


link_file pygame_sdl2-source/gen3-static/pygame_sdl2.display_api.h include/module/pygame_sdl2/pygame_sdl2.display_api.h
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.event.h include/module/pygame_sdl2/pygame_sdl2.event.h
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.rwobject_api.h include/module/pygame_sdl2/pygame_sdl2.rwobject_api.h
link_file pygame_sdl2-source/gen3-static/pygame_sdl2.surface_api.h include/module/pygame_sdl2/pygame_sdl2.surface_api.h
link_file pygame_sdl2-source/src/SDL2_rotozoom.h include/module/SDL2_rotozoom.h
link_file pygame_sdl2-source/src/SDL_gfxPrimitives.h include/module/SDL_gfxPrimitives.h
link_file pygame_sdl2-source/src/SDL_gfxPrimitives_font.h include/module/SDL_gfxPrimitives_font.h
link_file pygame_sdl2-source/src/pygame_sdl2/pygame_sdl2.h include/module/pygame_sdl2/pygame_sdl2.h
link_file pygame_sdl2-source/src/python_threads.h include/module/python_threads.h
link_file pygame_sdl2-source/src/surface.h include/module/src/surface.h
link_file pygame_sdl2-source/src/write_jpeg.h include/module/write_jpeg.h
link_file pygame_sdl2-source/src/write_png.h include/module/write_png.h
link_file pygame_sdl2-source/src/sdl_image_compat.h include/module/sdl_image_compat.h

link_file renpy-source/module/IMG_savepng.h include/module/IMG_savepng.h
link_file renpy-source/module/eglsupport.h include/module/eglsupport.h
link_file renpy-source/module/ftsupport.h include/module/ftsupport.h
link_file renpy-source/module/gl2debug.h include/module/gl2debug.h
link_file renpy-source/module/glcompat.h include/module/glcompat.h
link_file renpy-source/module/mmx.h include/module/mmx.h
link_file renpy-source/module/pyfreetype.h include/module/pyfreetype.h
link_file renpy-source/module/renpy.h include/module/renpy.h
link_file renpy-source/module/renpybidicore.h include/module/renpybidicore.h
link_file renpy-source/module/renpygl.h include/module/renpygl.h
link_file renpy-source/module/renpysound_core.h include/module/renpysound_core.h
link_file renpy-source/module/steamcallbacks.h include/module/steamcallbacks.h
link_file renpy-source/module/ttgsubtable.h include/module/ttgsubtable.h

link_file renpy-source/module/gen3-static/renpy.gl2.gl2draw.c source/module/renpy.gl2.gl2draw.c
link_file renpy-source/module/gen3-static/renpy.gl2.gl2mesh.c source/module/renpy.gl2.gl2mesh.c
link_file renpy-source/module/gen3-static/renpy.gl2.gl2mesh2.c source/module/renpy.gl2.gl2mesh2.c
link_file renpy-source/module/gen3-static/renpy.gl2.gl2mesh3.c source/module/renpy.gl2.gl2mesh3.c
link_file renpy-source/module/gen3-static/renpy.gl2.gl2model.c source/module/renpy.gl2.gl2model.c
link_file renpy-source/module/gen3-static/renpy.gl2.gl2polygon.c source/module/renpy.gl2.gl2polygon.c
link_file renpy-source/module/gen3-static/renpy.gl2.gl2shader.c source/module/renpy.gl2.gl2shader.c
link_file renpy-source/module/gen3-static/renpy.gl2.gl2texture.c source/module/renpy.gl2.gl2texture.c
link_file renpy-source/module/gen3-static/renpy.uguu.gl.c source/module/renpy.uguu.gl.c
link_file renpy-source/module/gen3-static/renpy.uguu.uguu.c source/module/renpy.uguu.uguu.c

link_file renpy-source/module/gen3-static/renpy.encryption.c source/module/renpy.encryption.c
link_file renpy-source/module/gen3-static/renpy.lexersupport.c source/module/renpy.lexersupport.c
link_file renpy-source/module/gen3-static/renpy.display.quaternion.c source/module/renpy.display.quaternion.c
