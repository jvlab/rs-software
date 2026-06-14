from pathlib import Path

import pathspec

DOCS_ROOT = Path(__file__).parent

with open(DOCS_ROOT / ".ignore") as file:
    GITIGNORE = pathspec.PathSpec.from_lines(
        "gitignore", file
    )


def on_serve(server, config, builder):
    # This hook is a hack since mkdocs doesn't allow to exclude files from triggering
    # a rebuild while being watched. We need this behavior, because we otherwise get
    # stuck in an infinite loop whenever something triggers a rebuild: our other hooks
    # create files inside the watched directory, which triggers the hooks again, which
    # creates the files again ...

    #print('[IGNORE] ***************')
    # Iterate through the patterns to see them
    #print("\nPatterns in IGNORE:")
    #for pattern in GITIGNORE.patterns:
    #    print(pattern)

    def callback_wrapper(callback):
        def wrapper(event):
            #print("source path of event:", event.src_path)
            #print('config.docs_dir', config.docs_dir)
            if GITIGNORE.match_file(
                Path(event.src_path).relative_to(config.docs_dir).as_posix()
            ):
                #print('matched')
                return

            return callback(event)

        return wrapper

    handler = (
        next(
            handler
            for watch, handler in server.observer._handlers.items()
            if watch.path == config.docs_dir
        )
        .copy()
        .pop()
    )

    # The callback getting wrapped can be found at
    # https://github.com/mkdocs/mkdocs/blob/828f4685f29dd9e986f18306d58d1cb383d00222/mkdocs/livereload/__init__.py#L142-L148
    handler.on_any_event = callback_wrapper(handler.on_any_event)
