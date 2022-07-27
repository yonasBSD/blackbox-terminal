/* SearchToolbar.vala
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

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/search-toolbar.ui")]
public class Terminal.SearchToolbar : Gtk.Widget {

  [GtkChild] private unowned Gtk.Button       next_button;
  [GtkChild] private unowned Gtk.Button       previous_button;
  [GtkChild] private unowned Gtk.CheckButton  match_case_sensitive_check_button;
  [GtkChild] private unowned Gtk.CheckButton  match_regex_check_button;
  [GtkChild] private unowned Gtk.CheckButton  match_whole_words_check_button;
  [GtkChild] private unowned Gtk.CheckButton  wrap_around_check_button;
  [GtkChild] private unowned Gtk.Revealer     revealer;
  [GtkChild] private unowned Gtk.SearchEntry  search_entry;

  public weak Terminal terminal { get; set; }

  public SearchToolbar (Terminal terminal) {
    Object (terminal: terminal);

    this.set_layout_manager (new Gtk.BinLayout ());

    this.search_entry.set_key_capture_widget (this);

    this.bind_data ();
    this.connect_signals ();
  }

  public void open () {
    this.revealer.reveal_child = true;
    this.search_entry.grab_focus ();

    if (this.terminal.get_has_selection ()) {
      var text = this.terminal.get_text_selected (
        Vte.Format.TEXT
      );
      this.terminal.unselect_all ();
      this.search_entry.text = text;
    }
  }

  public void close () {
    this.revealer.reveal_child = false;
    this.search_entry.text = "";
    this.terminal.unselect_all ();
    this.terminal.match_remove_all ();
    this.terminal.search_set_regex (null, 0);
  }

  private bool on_key_pressed (uint keyval, uint _kc, Gdk.ModifierType _mod) {
    if (keyval == Gdk.Key.Escape) {
      this.close ();
      return Gdk.EVENT_STOP;
    }
    return Gdk.EVENT_PROPAGATE;
  }

  private void bind_data () {
    var ssetings = SearchSettings.get_default ();

    ssetings.schema.bind (
      "wrap-around",
      this.wrap_around_check_button,
      "active",
      SettingsBindFlags.DEFAULT
    );

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
  }

  private void connect_signals () {
    var ssettings = SearchSettings.get_default ();

    this.search_entry.search_changed.connect (this.do_search);
    this.search_entry.activate.connect (this.search_previous);
    this.search_entry.search_started.connect (() => {
      if (!this.search_entry.has_focus) {
        this.search_entry.grab_focus ();
      }
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

  [GtkCallback]
  private void on_close_button_pressed () {
    this.close ();
  }
}
