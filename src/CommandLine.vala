/* CommandLine.vala
 *
 * Copyright 2022 Paulo Queiroz <pvaqueiroz@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public struct Terminal.CommandLineOptions {
  string? command;
  string? current_working_dir;
  bool    version;
  bool    help;
}

//  Usage:
//    blackbox [OPTION…] [-- COMMAND ...]
//
//  Options:
//    -v, --version               Show app version
//    -w, --working-directory     Set current working directory
//    -c, --command               Execute command in a terminal
//    -h, --help                  Show help

public class Terminal.CommandLine {
  public static bool parse_command_line (GLib.ApplicationCommandLine cmd,
                                         out CommandLineOptions options)
  {
    options = {};

    OptionEntry[] option_entries = {
      OptionEntry () {
        long_name       = "version",
        short_name      = 'v',
        description     = _("Show app version"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.NONE,
        arg_data        = &options.version,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "working-directory",
        short_name      = 'w',
        description     = _("Set current working directory"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.FILENAME,
        arg_data        = &options.current_working_dir,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "command",
        short_name      = 'c',
        description     = _("Execute command in a terminal"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.STRING,
        arg_data        = &options.command,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "help",
        short_name      = 'h',
        description     = _("Show help"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.NONE,
        arg_data        = &options.help,
        arg_description = null,
      },
    };

    var ctx = new OptionContext ("[-- COMMAND ...]");
    // If this is set to true and the user launches blackbox with --help, the
    // entire GTK application will close (with exit(0)), even if there are other
    // windows open
    ctx.set_help_enabled (false);
    ctx.add_main_entries (option_entries, null);

    var original_argv = cmd.get_arguments ();
    string[] real_argv = {};
    string[] commandv = {};
    bool dd = false;

    // Check if "--" is present. If so, everything after it will be appended to
    // `commandv` and fed as a single command to the terminal.
    foreach (unowned string s in original_argv) {
      if (dd) {
        commandv += s;
      }
      else if (s == "--") {
        dd = true;
      }
      else {
        real_argv += s;
      }
    }

    try {
      ctx.parse_strv (ref real_argv);

      if (options.help) {
        cmd.print_literal (ctx.get_help (true, null));
      }
      // If "--" was present and "-c" wasn't set
      if (dd && options.command == null) {
        options.command = string.joinv (" ", commandv);
      }
    }
    catch (Error e) {
      cmd.printerr ("%s\n", e.message);
      cmd.printerr (_("Run %s --help to get help\n"), original_argv[0]);
      return false;
    }

    return true;
  }
}
