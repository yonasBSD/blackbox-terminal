/* TerminalTab.vala
 *
 * Copyright 2021-2022 Paulo Queiroz
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
 */

[GtkTemplate (ui = "/com/raggesilver/BlackBox/gtk/terminal-tab.ui")]
public class Terminal.TerminalTab : Gtk.Box {

  // This signal is emitted when the TerminalTab is asking to be closed.
  public signal void close_request ();

  [GtkChild] unowned Adw.Banner banner;
  [GtkChild] unowned Gtk.ScrolledWindow scrolled;
  [GtkChild] unowned SearchToolbar search_toolbar;

  private string default_title;

  public Terminal terminal       { get; protected set; }
  public string?  title_override { get; private set; default = null; }

  public string title {
    get {
      if (this.title_override != null) return this.title_override;
      if (this.terminal.window_title != "") return this.terminal.window_title;

      return this.default_title;
    }
  }

  static construct {
    typeof (SearchToolbar).class_ref ();
  }

  public TerminalTab (Window  window,
                      uint    tab_id,
                      string? command,
                      string? cwd)
  {
    Object (
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 0
    );

    this.default_title = command ?? "%s %u".printf (_("tab"), tab_id);

    this.terminal = new Terminal (window, command, cwd);
    // TODO: Can't we use a property for this? Has default or something?
    this.terminal.grab_focus ();

    var click = new Gtk.GestureClick () {
      button = Gdk.BUTTON_SECONDARY,
    };

    click.pressed.connect (this.show_menu);

    this.terminal.add_controller (click);

    this.connect_signals ();
  }

#if BLACKBOX_DEBUG_MEMORY
  ~TerminalTab () {
    message ("TerminalTab destroyed");
  }

  public override void dispose () {
    message ("TerminalTab dispose");
    base.dispose ();
  }
#endif

  private void connect_signals () {
    var settings = Settings.get_default ();

    //  this.terminal.bind_property ("window-title",
    //                               this,
    //                               "title",
    //                               GLib.BindingFlags.DEFAULT,
    //                               null, null);

    this.terminal.notify ["window-title"].connect (() => {
      this.notify_property ("title");
    });

    this.notify ["title-override"].connect (() => {
      this.notify_property ("title");
    });

    this.terminal.exit.connect (() => {
      this.close_request ();
    });

    this.terminal.spawn_failed.connect ((message) => {
      this.override_title (_("Error"));
      this.banner.title = message;
      this.banner.revealed = true;
    });

    settings.notify ["show-scrollbars"]
      .connect (this.on_show_scrollbars_updated);

    settings.notify_property ("show-scrollbars");

    settings.schema.bind (
      "use-overlay-scrolling",
      this.scrolled,
      "overlay-scrolling",
      SettingsBindFlags.GET
    );

    settings.bind_property (
      "use-sixel",
      this.terminal,
      "enable-sixel",
      BindingFlags.SYNC_CREATE
    );
  }

  private void on_show_scrollbars_updated () {
    var settings = Settings.get_default ();
    var show_scrollbars = settings.show_scrollbars;
    var is_scrollbar_being_used = this.terminal.parent == this.scrolled;

    this.scrolled.visible = show_scrollbars;

    if (show_scrollbars != is_scrollbar_being_used) {
      if (this == this.terminal.parent) {
        this.remove (this.terminal);
      }
      else if (this.scrolled == this.terminal.parent) {
        this.scrolled.child = null;
      }
    }

    if (
      show_scrollbars != is_scrollbar_being_used ||
      this.terminal.parent == null
    ) {
      if (show_scrollbars) {
        this.scrolled.child = this.terminal;
      }
      else {
        this.insert_child_after (this.terminal, null);
      }
    }
  }

  public void show_menu (int n_pressed, double x, double y) {
    if (this.terminal.hyperlink_hover_uri != null) {
      this.terminal.window.link = this.terminal.hyperlink_hover_uri;
    } else {
      this.terminal.window.link = this.terminal.check_match_at (x, y, null);
    }

    var builder = new Gtk.Builder.from_resource ("/com/raggesilver/BlackBox/gtk/terminal-menu.ui");
    var pop = builder.get_object ("popover") as Gtk.PopoverMenu;

    double x_in_view, y_in_view;
    this.terminal.translate_coordinates (this, x, y, out x_in_view, out y_in_view);

    var r = Gdk.Rectangle () {
      x = (int) x_in_view,
      y = (int) y_in_view
    };

    pop.closed.connect_after (() => {
      pop.destroy ();
    });

    pop.set_parent (this);
    pop.set_has_arrow (false);
    pop.set_halign (Gtk.Align.START);
    pop.set_pointing_to (r);
    pop.popup ();
  }

  public void search () {
    this.search_toolbar.open ();
  }

  public void override_title (string? _title) {
    this.title_override = _title;
  }
}
