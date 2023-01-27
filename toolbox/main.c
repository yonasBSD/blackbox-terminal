#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pwd.h>
#include <sys/types.h>
#include <stdarg.h>

/**
 * This is a simple program meant to be launched with flatpak-spawn --host to
 * retrieve host information Flatpak'ed apps don't have access to. The original
 * idea for this program came from
 * https://github.com/gnunn1/tilix/blob/master/experimental/flatpak/tilix-flatpak-toolbox.c
 */

int die (int code, char *fmt, ...) __attribute__((format(printf,2,0)));

int die (int code, char *fmt, ...) {
  va_list list;
  va_start (list, fmt);
  vfprintf (stderr, fmt, list);
  return code;
}

int main (int argc, const char *argv[]) {
  if (argc < 2) {
    return die (1, "Not enough arguments.\n");
  }

  if (strcmp (argv[1], "tcgetpgrp") == 0) {
    // This is not needed
    if (argc != 3) {
      return die (1, "Missing argument `fd` for tcgetpgrp.\n");
    }

    // This is 3 because we create an array of fds that will be passed to this
    // program via a Flatpak DBus call, and the vte pty we need is in the 4th
    // slot in that array.
    pid_t pid = tcgetpgrp (3);

    printf ("%d\n", pid);

    return 0;
  }
  else {
    return die (1, "Unknown command '%s'.\n", argv[1]);
  }

  return 0;
}
