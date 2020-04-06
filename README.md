# Emacs Lisp REPL with Readline support

This is an Emacs Lisp REPL built with the GNU Readline library via
[Emacs Dynamic Modules API](https://www.gnu.org/software/emacs/manual/html_node/elisp/Writing-Dynamic-Modules.html).

## Features

- Some standard Readline features such as key bindings and history
- Pretty-print and syntax highlight output via `pp.el` and `e2ansi.el`

## Prerequisites

- Emacs with dynamic module support
- GNU Readline

## Get started

Compile module:

``` shell
# change .so to the value of your module-file-suffix
cc -shared -fpic -lreadline elisp-repl-readline.c -o elisp-repl-readline.so
```

Install [`e2ansi`](https://github.com/Lindydancer/e2ansi):

    M-x package-install e2ansi

Prepare `load-path`:

``` emacs-lisp
(push "~/src/elisp-repl/" load-path)
```

Load `elisp-repl.el`:

    M-x load-library elisp-repl

Get the shell command to to run the REPL:

    M-x elisp-repl-emacs-batch-command

Goto your terminal, paste the shell command, and run it.

## Customization

The following user options are available, `C-h f` to see more info.

- `elisp-repl-prompt`
- `elisp-repl-lexical-binding`
- `elisp-repl-history-file`
- `elisp-init-file`

## Caveats

### Code Completion doesn't work

Code completion is the primary feature I want to add. Unfortunately, now I'm NOT
sure if it is even possible. Emacs can call module function anytime, but the
reverse is not true. Thus I can't get completion items in Readline from Emacs.

Maybe https://nullprogram.com/blog/2017/02/14/ is related, but this post is far
beyond my knowledge.

### Readline history doesn't multiline

The history file is read and wrote via Readline's `read_history` and
`write_history`, they don't support multiline.

### No backtrace

There is no way to get backtrace in batch mode. When you get one, Emacs will
exit.

## Alternatives

- https://github.com/tetracat/emacsrepl
