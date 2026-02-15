from kitty.boss import get_boss
from kitty.fast_data_types import Screen, get_options
from kitty.utils import color_as_int
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_tab_with_powerline,
)


def _draw_mode(screen: Screen, index: int) -> int:
    opts = get_options()
    if index != 1:
        return 0
    fg, bg = screen.cursor.fg, screen.cursor.bg
    orig_bold = screen.cursor.bold

    mode = get_boss().mappings.current_keyboard_mode_name
    if mode and mode == "unlocked":
        mode_text = " UNLOCKED "
        screen.cursor.fg = as_rgb(color_as_int(opts.background))
        screen.cursor.bg = as_rgb(color_as_int(opts.color1))
    else:
        mode_text = "  LOCKED  "
        screen.cursor.fg = as_rgb(color_as_int(opts.foreground))
        screen.cursor.bg = as_rgb(color_as_int(opts.color0))

    screen.cursor.bold = False
    screen.draw(mode_text)
    screen.cursor.fg, screen.cursor.bg = fg, bg
    screen.cursor.bold = orig_bold
    screen.cursor.x = len(mode_text)
    return screen.cursor.x


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    screen.cursor.italic = False

    if index == 1:
        _draw_mode(screen, index)
        screen.draw(" ")
        before = screen.cursor.x

    return draw_tab_with_powerline(
        draw_data,
        screen,
        tab,
        before,
        max_title_length,
        index,
        is_last,
        extra_data,
    )
