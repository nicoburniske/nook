from os.path import basename

from kitty.boss import get_boss
from kitty.child import cached_process_data
from kitty.fast_data_types import Screen, add_timer, get_options, remove_timer
from kitty.utils import color_as_int
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_tab_with_powerline,
)

titles = {}
timer = None


def draw_title(data: dict) -> str:
    global timer
    boss = get_boss()
    if timer is None:
        previous = getattr(boss, '_title_refresh_timer', None)
        if previous is not None:
            remove_timer(previous)
        timer = boss._title_refresh_timer = add_timer(refresh_titles, 0.5, True)
    tab = boss.tab_for_id(data['tab_id'])
    window = tab.active_window if tab else None
    return titles.get(window.id, data['title']) if window else data['title']


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


def refresh_titles(timer_id: int) -> None:
    boss = get_boss()
    updated = {}
    with cached_process_data():
        for window in boss.window_id_map.values():
            directory = (window.get_cwd_of_child(oldest=True) or '/').rpartition('/')[2] or '/'
            executable = basename(window.get_exe_of_child(oldest=True))
            suffix = '' if executable in ('', 'bash', 'zsh') else f' [{executable}]'
            updated[window.id] = directory + suffix
    if updated != titles:
        titles.clear()
        titles.update(updated)
        for manager in boss.os_window_map.values():
            manager.mark_tab_bar_dirty()
