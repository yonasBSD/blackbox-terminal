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

  public string             title     { get; protected set; }
  public Terminal           terminal  { get; protected set; }

  static construct {
    typeof (SearchToolbar).class_ref ();
  }

  public TerminalTab (Window window, string? command, string? cwd) {
    Object (
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 0
    );

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

    this.terminal.bind_property ("window-title",
                                 this,
                                 "title",
                                 GLib.BindingFlags.DEFAULT,
                                 null, null);

    this.terminal.exit.connect (() => {
      this.close_request ();
    });

    this.terminal.spawn_failed.connect ((message) => {
      this.title = _("Error");
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
    var menu = new Menu ();
    var edit_section = new Menu ();
    var preferences_section = new Menu ();
    var bottom_section = new Menu ();

    menu.append (_("New Tab"), "win.new_tab");
    menu.append (_("New Window"), "app.new-window");

    edit_section.append (_("Copy"), "win.copy");
    edit_section.append (_("Paste"), "win.paste");

    menu.append_section (null, edit_section);

    preferences_section.append (_("Preferences"), "win.edit_preferences");
    menu.append_section (null, preferences_section);

    bottom_section.append (_("Keyboard Shortcuts"), "win.show-help-overlay");
    bottom_section.append (_("About Black Box"), "app.about");
    menu.append_section (null, bottom_section);

    var pop = new Gtk.PopoverMenu.from_model (menu) {
      has_arrow = false,
    };

    double xx, yy;
    this.terminal.translate_coordinates (this, 0, 0, out xx, out yy);

    Gdk.Rectangle r = {0};
    r.x = (int) (x + xx);
    r.y = (int) (y + yy + 12);

    pop.closed.connect_after (() => {
      pop.destroy ();
    });

    pop.set_parent (this);
    pop.set_pointing_to (r);
    pop.set_position (Gtk.PositionType.BOTTOM);
    pop.popup ();
  }

  public void search () {
    this.search_toolbar.open ();
  }
}
