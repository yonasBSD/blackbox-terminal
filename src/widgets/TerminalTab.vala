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

public class Terminal.TerminalTab : Gtk.Box {

  public signal void close_request ();

  public string             title     { get; protected set; }
  public Terminal           terminal  { get; protected set; }
  public Gtk.ScrolledWindow scrolled  { get; protected set; }

  public weak Window window;

  public TerminalTab (Window window, string? cwd) {
    Object (
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 0
    );

    this.window = window;
    this.terminal = new Terminal (this.window, null, cwd);

    // Hack to stop vala-language-server from complaining
    var twig = this.terminal as Gtk.Widget;
    //  this.set_child(twig);
    this.scrolled = new Gtk.ScrolledWindow ();
    this.scrolled.child = twig;

    this.append (this.scrolled);
    twig.grab_focus ();

    var click = new Gtk.GestureClick () {
      button = Gdk.BUTTON_SECONDARY,
    };

    click.pressed.connect (this.show_menu);

    this.terminal.add_controller (click);

    this.connect_signals ();
  }

  private void connect_signals () {
    var settings = Settings.get_default ();

    this.terminal.notify["window-title"].connect (() => {
      this.title = this.terminal.window_title;
    });

    this.terminal.exit.connect (() => {
      this.close_request ();
    });

    settings.notify["show-scrollbars"].connect (() => {
      var show_scrollbars = settings.show_scrollbars;
      var is_scrollbar_being_used = this.scrolled.child == this.terminal;

      if (show_scrollbars && !is_scrollbar_being_used) {
        this.remove (this.terminal);
        this.scrolled.child = this.terminal;
        this.append (this.scrolled);
      }
      else if (!show_scrollbars && is_scrollbar_being_used) {
        this.remove (this.scrolled);
        this.scrolled.child = null;
        this.append (this.terminal);
      }
      // Pixel scrolling depends on this, so we'll notify it to trigger any
      // listeners
      settings.notify_property ("pixel-scrolling");
    });
    settings.notify_property ("show-scrollbars");

    settings.schema.bind (
      "use-overlay-scrolling",
      this.scrolled,
      "overlay-scrolling",
      SettingsBindFlags.GET
    );

    settings.bind_property (
      "pixel-scrolling",
      // Make vala-language-server stop complaining
      this.terminal as Object,
      "scroll-unit-is-pixels",
      BindingFlags.DEFAULT,
      (_, from, ref to) => {
        to = Settings.get_default ().show_scrollbars && from.get_boolean ();
        return true;
      },
      null
    );
  }

  public void show_menu (int n_pressed, double x, double y) {
    var menu = new Menu ();
    var edit_section = new Menu ();
    var preferences_section = new Menu ();

    edit_section.append ("Copy", "win.copy");
    edit_section.append ("Paste", "win.paste");

    menu.append ("New tab", "win.new_tab");
    menu.append ("New window", "win.new_window");
    menu.append_section (null, edit_section);

    preferences_section.append ("Preferences", "win.edit_preferences");
    preferences_section.append ("About", "win.about");
    menu.append_section (null, preferences_section);

    var pop = new Gtk.PopoverMenu.from_model (menu);

    Gdk.Rectangle r = {0};
    r.x = (int) x;
    r.y = (int) y;

    pop.closed.connect_after (() => {
      pop.destroy ();
    });

    pop.set_parent (this);
    pop.set_pointing_to (r);
    pop.popup ();
  }
}