/* SearchWindow.vala
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


[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/search-window.ui")]
public class Terminal.SearchWindow : Adw.ApplicationWindow {

  [GtkChild] private unowned Gtk.SearchEntry search_entry;
  [GtkChild] private unowned Gtk.CheckButton wrap_around_check_button;
  [GtkChild] private unowned Gtk.CheckButton match_case_sensitive_check_button;
  [GtkChild] private unowned Gtk.CheckButton match_whole_words_check_button;
  [GtkChild] private unowned Gtk.CheckButton match_regex_check_button;
  [GtkChild] private unowned Gtk.ToggleButton fixed_window_button;
  [GtkChild] private unowned Gtk.Button previous_button;
  [GtkChild] private unowned Gtk.Button next_button;

  private weak Terminal terminal;
  private Window parent_window;

  private ulong active_terminal_handler = 0;

  public uint n_results { get; private set; default = 0; }
  public uint selected_result { get; private set; default = 0; }

  public SearchWindow (Window parent_window, Terminal terminal) {
    Object (
      application: parent_window.application,
      transient_for: parent_window,
      destroy_with_parent: true,
      resizable: false,
      title: _("Search")
    );

    this.terminal = terminal;
    this.parent_window = parent_window;

    this.search_entry.set_key_capture_widget (this);

    var ssetings = SearchSettings.get_default ();

    // These buttons do not update the user's settings. To change these options
    // users must go to the preferences window
    this.wrap_around_check_button.active = ssetings.wrap_around;
    this.fixed_window_button.active = ssetings.fixed;

    ssetings.schema.bind (
      "match-whole-words",
      this.match_whole_words_check_button,
      "active",
      SettingsBindFlags.DEFAULT
    );

    ssetings.schema.bind (
      "match-case-sensitive",
      this.match_case_sensitive_check_button,
      "active",
      SettingsBindFlags.DEFAULT
    );

    ssetings.schema.bind (
      "match-regex",
      this.match_regex_check_button,
      "active",
      SettingsBindFlags.DEFAULT
    );

    this.connect_signals ();

    if (this.terminal.get_has_selection ()) {
      var text = this.terminal.get_text_selected ();
      this.terminal.unselect_all ();
      this.search (text);
    }
  }

  private bool on_key_pressed (uint keyval, uint _kc, Gdk.ModifierType _mod) {
    if (keyval == Gdk.Key.Escape) {
      this.close ();
      return true;
    }
    return false;
  }

  private void on_focus_lost () {
    if (!this.fixed_window_button.active) {
      this.close ();
    }
  }

  private void connect_signals () {
    var ssettings = SearchSettings.get_default ();

    // If the search window is fixed and the user switches to another tab, we
    // need to hide the search window until this tab is opened again
    this.active_terminal_handler = this.parent_window.notify ["active-terminal"]
      .connect (() => {
        if (this.parent_window.active_terminal != this.terminal) {
          this.hide ();
        }
        else {
          this.show ();
        }
      });

    this.close_request.connect (() => {
      if (SearchSettings.get_default ().clear_selection_on_exit) {
        this.terminal.unselect_all ();
      }
      this.terminal.match_remove_all ();
      this.terminal.search_set_regex (null, 0);
      this.parent_window.disconnect (this.active_terminal_handler);
      return false;
    });

    this.parent_window.close_request.connect (() => {
      this.close ();
      return false;
    });

    this.search_entry.search_changed.connect (this.do_search);
    this.search_entry.activate.connect (this.search_previous);
    this.search_entry.search_started.connect (() => {
      this.search_entry.grab_focus ();
    });

    this.previous_button.clicked.connect (this.search_previous);
    this.next_button.clicked.connect (this.search_next);

    this.terminal.search_set_wrap_around (this.wrap_around_check_button.active);
    this.wrap_around_check_button.notify ["active"].connect (() => {
      this.terminal.search_set_wrap_around (
        this.wrap_around_check_button.active
      );
    });

    var kpc = new Gtk.EventControllerKey ();
    kpc.key_pressed.connect (this.on_key_pressed);
    this.search_entry.add_controller (kpc);

    kpc = new Gtk.EventControllerKey ();
    kpc.key_pressed.connect (this.on_key_pressed);
    (this as Gtk.Widget)?.add_controller (kpc);

    var fc = new Gtk.EventControllerFocus ();
    fc.leave.connect (this.on_focus_lost);
    (this as Gtk.Widget)?.add_controller (fc);

    ssettings.notify.connect ((spec) => {
      // If any search match related properties changed call search again
      if (spec.name.has_prefix ("match-")) {
        this.do_search ();
      }
    });
  }

  public void search (string text) {
    this.search_entry.set_text (text);
  }

  private void do_search () {
    var text = this.search_entry.text;

    if (text == null || text == "") {
      this.terminal.unselect_all ();
      this.terminal.match_remove_all ();
      this.terminal.search_set_regex (null, 0);
      return;
    }

    // TODO: return here if the window is not shown

    this.terminal.search_find_next ();

    string search_string = null;
    var ssettings = SearchSettings.get_default ();
    PCRE2.Flags search_flags = PCRE2.Flags.MULTILINE;

    if (ssettings.match_regex) {
      search_string = text;
    }
    else {
      search_string = Regex.escape_string (text);
    }

    if (ssettings.match_whole_words) {
      search_string = "\\b%s\\b".printf (search_string);
    }

    if (!ssettings.match_case_sensitive) {
      search_flags |= PCRE2.Flags.CASELESS;
    }

    try {
      this.terminal.search_set_regex (
        new Vte.Regex.for_search (search_string, -1, search_flags),
        0
      );

      // Auto-select the last (most recent) result
      this.terminal.search_find_previous ();
    }
    catch (Error e) {
      warning ("%s", e.message);
    }
  }

  private void search_next () {
    this.terminal.search_find_next ();
  }

  private void search_previous () {
    this.terminal.search_find_previous ();
  }
}
