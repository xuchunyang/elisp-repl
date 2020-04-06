#include <emacs-module.h>

int plugin_is_GPL_compatible;

#include <readline/history.h>
#include <readline/readline.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

static char *
extract_utf8_string (emacs_env *env, emacs_value lisp_str)
{
  ptrdiff_t size = 0;
  char * buf = NULL;

  env->copy_string_contents (env, lisp_str, buf, &size);
  buf = malloc (size);
  env->copy_string_contents (env, lisp_str, buf, &size);
  return buf;
}

static void
signal_system_error (emacs_env *env, int error, const char *function)
{
  const char *message = strerror (error);
  emacs_value message_value = env->make_string (env, message, strlen (message));
  emacs_value symbol = env->intern (env, "error");
  emacs_value elements[2]
    = {env->make_string (env, function, strlen (function)), message_value};
  emacs_value data = env->funcall (env, env->intern (env, "list"), 2, elements);
  env->non_local_exit_signal (env, symbol, data);
}

static void
signal_errno (emacs_env *env, const char *function)
{
  signal_system_error (env, errno, function);
}

static emacs_value
Freadline (emacs_env *env, ptrdiff_t nargs, emacs_value *args,
           void *data)
{
  char *prompt = extract_utf8_string (env, args[0]);
  char *input = readline (prompt);
  emacs_value rtv;
  if (input)
    rtv = env->make_string (env, input, strlen (input));
  else
    rtv = env->intern (env, "nil");
  free (prompt);
  free (input);
  return rtv;
}

static emacs_value
Fadd_history (emacs_env *env, ptrdiff_t nargs, emacs_value *args,
              void *data)
{
  char *input = extract_utf8_string (env, args[0]);
  add_history (input);
  free (input);
  return env->intern (env, "nil");
}

static emacs_value
Fread_history (emacs_env *env, ptrdiff_t nargs, emacs_value *args,
              void *data)
{
  char *filename = extract_utf8_string (env, args[0]);
  int error_code = read_history (filename);
  free (filename);
  if (error_code != 0)
    signal_errno (env, "read_history");
  return env->intern (env, "nil");
}

static emacs_value
Fwrite_history (emacs_env *env, ptrdiff_t nargs, emacs_value *args,
                void *data)
{
  char *filename = extract_utf8_string (env, args[0]);
  int error_code = write_history (filename);
  free (filename);
  if (error_code != 0)
    signal_errno (env, "write_history");
  return env->intern (env, "nil");  
}

/* Lisp utilities for easier readability (simple wrappers).  */

/* Provide FEATURE to Emacs.  */
static void
provide (emacs_env *env, const char *feature)
{
  emacs_value Qfeat = env->intern (env, feature);
  emacs_value Qprovide = env->intern (env, "provide");
  emacs_value args[] = { Qfeat };

  env->funcall (env, Qprovide, 1, args);
}

/* Bind NAME to FUN.  */
static void
bind_function (emacs_env *env, const char *name, emacs_value Sfun)
{
  emacs_value Qdefalias = env->intern (env, "defalias");
  emacs_value Qsym = env->intern (env, name);
  emacs_value args[] = { Qsym, Sfun };

  env->funcall (env, Qdefalias, 2, args);
}

/* IDEA: Check against Emacs 26.3 */

/* Module init function.  */
int
emacs_module_init (struct emacs_runtime *runtime)
{
  /* IDEA: Do Compatibility verification, does it work for Emacs 25? */
  emacs_env *env = runtime->get_environment (runtime);

#define DEFUN(lsym, csym, amin, amax, doc, data)                        \
  bind_function (env, lsym,                                             \
		 env->make_function (env, amin, amax, csym, doc, data))

  /* IDEA: Add docstring */
  DEFUN ("elisp-repl-readline", Freadline, 1, 1, NULL, NULL);
  DEFUN ("elisp-repl-readline-add-history", Fadd_history, 1, 1, NULL, NULL);
  DEFUN ("elisp-repl-readline-read-history", Fread_history, 1, 1, NULL, NULL);
  DEFUN ("elisp-repl-readline-write-history", Fwrite_history, 1, 1, NULL, NULL);
#undef DEFUN

  provide (env, "elisp-repl-readline");
  return 0;
}

/* IDEA: Remove the following, it works for only me (using homebrew on macOS to install readline) */

/* Local Variables: */
/* compile-command: "cc `PKG_CONFIG_PATH='/usr/local/opt/readline/lib/pkgconfig' pkg-config --cflags --libs readline` -shared -fpic elisp-repl-readline.c -o elisp-repl-readline.so" */
/* End: */
