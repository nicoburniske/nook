from os.path import basename

from kittens.tui.handler import result_handler
from kitty.launch import launch, parse_launch_args

commands = [[], ['lazygit'], [], []]


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    source = boss.window_id_map.get(target_window_id)
    if source is None or (tab := source.tabref()) is None:
        return

    windows = [group.windows[0] for group in tab.windows.groups]
    root = windows[0]
    if args[1] == 'open':
        location = args[2] if len(args) == 3 else f'{args[2]}:{args[3]}'
        root.send_key('escape')
        root.write_to_child(f':open {location}')
        root.send_key('enter')
        tab.set_active_window(root)
        return

    index = int(args[1]) - 1
    if not 0 <= index < len(commands):
        raise ValueError('slot must be between 1 and 4')
    extra = args[2:]
    replace = bool(extra and extra[0] == '--replace')
    if replace:
        extra = extra[1:]
    if extra and extra[0] == '--':
        extra = extra[1:]
    command = commands[index]
    target = windows[index] if index < len(windows) else None

    if command:
        matches = [
            window
            for window in windows
            if any(
                process['cmdline'] and basename(process['cmdline'][0]) == command[0]
                for process in window.child.foreground_processes
            )
        ]
        if target not in matches:
            target = matches[0] if matches else None

    if target is not None:
        tab.set_active_window(target)
        if command and (position := windows.index(target)) != index:
            tab.move_window(index - position)
        if not replace:
            return

    opts, _ = parse_launch_args([
        '--cwd=current', '--copy-env', '--source-window', f'id:{root.id}',
    ])
    if target is not None:
        opts.location = 'before'
        opts.next_to = f'id:{target.id}'
    elif command:
        opts.location = 'after'
        opts.next_to = f'id:{root.id}'
    else:
        opts.location = 'last'

    for slot in range(index if target is not None or command else len(windows), index + 1):
        created = launch(
            boss, opts, commands[slot] + (extra if slot == index else []),
            target_tab=tab, rc_from_window=source,
        )
        if created is not None and target is not None:
            boss.close_windows_no_confirm([target])
            tab.set_active_window(created)


def main(args):
    pass
