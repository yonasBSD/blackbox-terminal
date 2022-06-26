/* Application.vala
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

public class Terminal.Application : Adw.Application {
  private ActionEntry[] ACTIONS = {
    { "focus-next-tab", on_focus_next_tab },
    { "focus-previous-tab", on_focus_previous_tab },
    { "new-window", on_new_window },
    { "about", on_about },
    { "quit", on_app_quit },
  };

  public Application () {
    Object (
      application_id: "com.raggesilver.BlackBox",
      flags: ApplicationFlags.HANDLES_COMMAND_LINE
    );

    this.add_action_entries (ACTIONS, this);

    this.set_accels_for_action ("app.focus-next-tab", { "<primary>Tab" });
    this.set_accels_for_action ("app.focus-previous-tab", { "<primary><shift>Tab" });
    this.set_accels_for_action ("app.new-window", { "<primary><shift>n" });
    this.set_accels_for_action ("app.quit", { "<primary>q" });

    this.set_accels_for_action ("win.switch-headerbar-mode", { "<primary><shift>h" });
    this.set_accels_for_action ("win.new_tab", { "<primary><shift>t" });
    this.set_accels_for_action ("win.edit_preferences", { "<primary>comma" });
    this.set_accels_for_action ("win.copy", { "<primary><shift>c" });
    this.set_accels_for_action ("win.paste", { "<primary><shift>p" });
    this.set_accels_for_action ("win.fullscreen", { "F11" });
  }

  public override void activate () {
    message ("Called activate");
    new Window (this).show ();
  }

  public override int command_line (GLib.ApplicationCommandLine cmd) {
    CommandLineOptions options;

    this.hold ();

    if (!CommandLine.parse_command_line (cmd, out options)) {
      this.release ();
      return -1;
    }
    else if (options.version) {
      cmd.print ("%s version %s\n", APP_NAME, VERSION);
    }
    else {
      new Window (
        this,
        options.command,
        options.current_working_dir,
        false
      ).show ();
    }
    this.release ();
    return 0;
  }

  private void on_app_quit () {
    // This involves confirming before closing tabs/windows
    warning ("App quit is not implemented yet.");
  }

  private void on_about () {
    var win = create_about_dialog ();
    win.set_transient_for (this.get_active_window ());
    win.show ();
  }

  private void on_new_window () {
    new Window (this, null, null, false).show ();
  }

  private void on_focus_next_tab () {
    (this.get_active_window () as Window)?.focus_next_tab ();
  }

  private void on_focus_previous_tab () {
    (this.get_active_window () as Window)?.focus_previous_tab ();
  }
}
