/* Window.vala
 *
 * Copyright 2020-2022 Paulo Queiroz
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

public struct Terminal.Padding {
  uint top;
  uint right;
  uint bottom;
  uint left;

  public Variant to_variant () {
    return new Variant (
      "(uuuu)",
      this.top,
      this.right,
      this.bottom,
      this.left
    );
  }

  public static Padding zero () {
    return { 0 };
  }

  public static Padding from_variant (Variant vari) {
    return_val_if_fail (
      vari.check_format_string ("(uuuu)", false),
      Padding.zero ()
    );

    var iter = vari.iterator ();
    uint top = 0, right = 0, bottom = 0, left = 0;

    iter.next ("u", &top);
    iter.next ("u", &right);
    iter.next ("u", &bottom);
    iter.next ("u", &left);

    return Padding () {
      top = top,
      right = right,
      bottom = bottom,
      left = left,
    };
  }

  public string to_string () {
    return "Padding { %u, %u, %u, %u }".printf (
      this.top,
      this.right,
      this.bottom,
      this.left
    );
  }

  /**
   * Whether padding on all sides is the same.
   */
  public bool is_equilateral () {
    return (
      this.top == this.right &&
      this.right == this.bottom &&
      this.bottom == this.left
    );
  }
}

public class Terminal.Window : Adw.ApplicationWindow {

  public ThemeProvider  theme_provider  { get; private set; }
  public Adw.TabView    tab_view        { get; private set; }

  Adw.HeaderBar header_bar;
  Adw.TabBar    tab_bar;
  Gtk.Box       layout_box;
  Gtk.Button    new_tab_button;
  Gtk.Overlay   overlay;
  Gtk.Revealer  header_bar_revealer;
  Gtk.Revealer  floating_header_bar_revealer;
  Settings      settings = Settings.get_default ();

  const uint header_bar_revealer_duration_ms = 250;

  construct {
    if (DEVEL) {
      this.add_css_class ("devel");
    }

    this.layout_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

    this.header_bar = new Adw.HeaderBar () {
      show_start_title_buttons = true,
      show_end_title_buttons = true,

      css_classes = { "flat" },
    };

    this.header_bar_revealer = new Gtk.Revealer () {
      transition_duration = Window.header_bar_revealer_duration_ms,
      child = this.header_bar,
    };

    this.floating_header_bar_revealer = new Gtk.Revealer () {
      transition_duration = Window.header_bar_revealer_duration_ms,
      //  transition_type = Gtk.RevealerTransitionType.CROSSFADE,

      valign = Gtk.Align.START,
      vexpand = false,

      css_classes = { "floating-revealer" },
    };

    this.tab_view = new Adw.TabView ();

    this.tab_bar = new Adw.TabBar () {
      autohide = false,
      view = this.tab_view,

      hexpand = true,
      halign = Gtk.Align.FILL,

      css_classes = { "inline" },

      can_focus = false,
    };

    this.new_tab_button = new Gtk.Button.from_icon_name ("list-add-symbolic") {
      can_focus = false,
    };

    var title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
      hexpand = true,
      halign = Gtk.Align.FILL,
    };

    title_box.append (this.tab_bar);
    title_box.append (this.new_tab_button);

    this.header_bar.title_widget = title_box;

    this.layout_box.append (this.header_bar_revealer);
    this.layout_box.append (this.tab_view);

    this.overlay = new Gtk.Overlay ();
    this.overlay.child = this.layout_box;
    this.overlay.add_overlay (this.floating_header_bar_revealer);

    this.content = this.overlay;
  }

  public Window (
    Gtk.Application app,
    string? cwd = null,
    bool skip_initial_tab = false
  ) {
    var sett = Settings.get_default ();
    var wwidth = (int) (sett.remember_window_size ? sett.window_width : 700);
    var wheight = (int) (sett.remember_window_size ? sett.window_height : 450);

    Object (
      application: app,
      default_width: wwidth,
      default_height: wheight
    );

    Marble.add_css_provider_from_resource (
      "/com/raggesilver/Terminal/resources/style.css"
    );

    this.theme_provider = new ThemeProvider (this.settings);

    this.new_tab_button.clicked.connect (() => {
      this.new_tab ();
    });

    this.add_actions ();
    this.connect_signals ();

    if (!skip_initial_tab) {
      this.new_tab ();
    }
  }

  private void connect_signals () {
    this.settings.schema.bind (
      "fill-tabs",
      this.tab_bar,
      "expand-tabs",
      SettingsBindFlags.GET
    );

    this.settings.schema.bind (
      "show-headerbar",
      this.header_bar_revealer,
      "reveal-child",
      SettingsBindFlags.GET
    );

    this.tab_view.create_window.connect (() => {
      var w = this.new_window (null, true);
      return w.tab_view;
    });

    // Close the window if all tabs were closed
    this.tab_view.notify["n-pages"].connect (() => {
      if (this.tab_view.n_pages < 1) {
        this.close ();
      }
    });

    this.tab_view.notify["selected-page"].connect (() => {
      this.on_tab_selected ();
    });

    this.notify["default-width"].connect (() => {
      this.settings.window_width = this.default_width;
    });

    this.notify["default-height"].connect (() => {
      this.settings.window_height = this.default_height;
    });

    this.settings.notify["show-headerbar"].connect (() => {
      this.on_headerbar_toggled ();
    });
    this.on_headerbar_toggled ();

    var c = new Gtk.EventControllerMotion ();
    c.motion.connect ((_, x, y) => {
      if (this.settings.show_headerbar) {
        return;
      }

      var h = this.header_bar.get_height ();
      var is_showing = this.floating_header_bar_revealer.reveal_child;

      // TODO: Make to_show_erea be configurable in Preferences
      var to_show_erea = 3;

      // When float headerbar is hiding, just leave a small erea to
      // show it
      var v = y <= (is_showing ? h : to_show_erea);

      if (v != is_showing) {
        if (is_showing) {
          // when leave the area, clear source of timeout and
          // hide floating headerbar
          Source.remove (this.waiting_for_floating_hb_animation);
          this.waiting_for_floating_hb_animation = 0;
          this.floating_header_bar_revealer.reveal_child = v;
        } else {
          // Add timeout when show float headerbar, then show
          // floating headerbar

          // TODO: Make timeout time can be configureable in Preferences
          this.waiting_for_floating_hb_animation = Timeout.add (
            500,
            () => {
              this.floating_header_bar_revealer.reveal_child = v;
              this.waiting_for_floating_hb_animation = 0;
              return false;
            }
          );
        }
      }
    });

    (this as Gtk.Widget)?.add_controller (c);
  }

  private uint waiting_for_floating_hb_animation = 0;

  private void add_actions () {
    var sa = new SimpleAction ("new_tab", null);
    sa.activate.connect (() => {
      this.new_tab ();
    });
    this.add_action (sa);

    sa = new SimpleAction ("edit_preferences", null);
    sa.activate.connect (() => {
      var w = new PreferencesWindow (this.application, this);
      w.show ();
    });
    this.add_action (sa);

    sa = new SimpleAction ("paste", null);
    sa.activate.connect (() => {
      this.on_paste_activated ();
    });
    this.add_action (sa);

    sa = new SimpleAction ("copy", null);
    sa.activate.connect (() => {
      this.on_copy_activated ();
    });
    // TODO: this will stay disabled until copying actually works in Vte-Gtk4
    sa.set_enabled (false);
    this.add_action (sa);
  }

  public void new_tab () {
    var tab = new TerminalTab (this, null);
    var page = this.tab_view.add_page (tab, null);

    page.title = @"tab $(this.tab_view.n_pages)";
    tab.notify["title"].connect (() => {
      page.title = tab.title;
    });
    tab.close_request.connect (() => {
      this.tab_view.close_page (page);
    });
    this.tab_view.set_selected_page (page);
  }

  private void on_paste_activated () {
    (this.tab_view.selected_page?.child as TerminalTab)?.terminal
      .do_paste_clipboard ();
  }

  private void on_copy_activated () {
    (this.tab_view.selected_page?.child as TerminalTab)?.terminal
      .do_copy_clipboard ();
  }

  private void on_tab_selected () {
    (this.tab_view.selected_page?.child as TerminalTab)?.terminal.grab_focus ();
  }

  public Window new_window (
    string? cwd = null,
    bool skip_initial_tab = false
  ) {
    var w = new Window (this.application, cwd, skip_initial_tab);
    w.show ();
    w.close_request.connect (() => {
      return false;
    });
    return w;
  }

  public Terminal? get_active_terminal () {
    return (this.tab_view.selected_page?.child as TerminalTab)?.terminal;
  }

  public void focus_next_tab () {
    if (!this.tab_view.select_next_page ()) {
      this.tab_view.set_selected_page (this.tab_view.get_nth_page (0));
    }
  }

  public void focus_previous_tab () {
    if (!this.tab_view.select_previous_page ()) {
      this.tab_view.set_selected_page (this.tab_view.get_nth_page (this.tab_view.n_pages - 1));
    }
  }

  public void focus_nth_tab (int index) {
    if (this.tab_view.n_pages <= 1) {
      return;
    }
    if (index == 9) {
      // Go to last tab
      this.tab_view.set_selected_page (
        this.tab_view.get_nth_page (this.tab_view.n_pages - 1)
      );
      return;
    }
    if (index > this.tab_view.n_pages) {
      return;
    }
    else {
      this.tab_view.set_selected_page (this.tab_view.get_nth_page (index - 1));
      return;
    }
  }

  // SYNC: we're currently moving the revealer to the overlay. We should
  // probably leave the revealer as is (so that we don't have to mess with it's
  // reveal-child prop, cuz it's bound to GSettings) and have another revealer
  // exclusive for the overlay. One issue atm is that we can't right click if
  // the Overlay has an overlay-child.

  private void on_headerbar_toggled () {
    //  Timeout.add
    var show_headerbar = this.settings.show_headerbar;

    //  // If the user just disabled the header bar, we need to wait for the
    //  // revealer animation to end to only then move the headerbar to the floating
    //  // revealer
    //  var needs_to_wait_for_animation = (
    //    !show_headerbar && this.header_bar.parent == this.header_bar_revealer
    //  );

    //  if (needs_to_wait_for_animation) {
    //    GLib.Timeout.add (
    //      Window.header_bar_revealer_duration_ms,
    //      () => {
    //        return this.on_headerbar_toggled_after_animation ();
    //      },
    //      Priority.DEFAULT
    //    );
    //  }
    //  else {
    //    this.on_headerbar_toggled_after_animation ();
    //  }

    if (show_headerbar) {
      this.move_headerbar_to_regular ();
    }
    else {
      this.move_headerbar_to_floating ();
    }
  }

  // In case the user spams the "Show headerbar" toggle, we might need to keep
  // track of the Timeout we set to wait for the headerbar animation to end.
  private uint waiting_for_hb_animation = 0;

  private void move_headerbar_to_floating () {
    //  this.header_bar_revealer.child = null;

    //  var prev_duration = this.floating_header_bar_revealer.transition_duration;
    //  var prev_reveal = this.floating_header_bar_revealer.reveal_child;
    //  var prev_ttype = this.floating_header_bar_revealer.transition_type;

    //  this.floating_header_bar_revealer.transition_type = this.header_bar_revealer.transition_type;
    //  this.floating_header_bar_revealer.transition_duration = 0;
    //  this.floating_header_bar_revealer.reveal_child = true;

    //  this.floating_header_bar_revealer.child = this.header_bar;

    //  this.floating_header_bar_revealer.transition_duration = prev_duration;
    //  this.floating_header_bar_revealer.reveal_child = prev_reveal;

    this.waiting_for_hb_animation = Timeout.add (
      Window.header_bar_revealer_duration_ms,
      () => {
        this.header_bar_revealer.child = null;
        this.floating_header_bar_revealer.child = this.header_bar;
        this.waiting_for_hb_animation = 0;
        return false;
      },
      Priority.DEFAULT
    );
  }

  private void move_headerbar_to_regular () {
    if (this.waiting_for_hb_animation > 0) {
      Source.remove (this.waiting_for_hb_animation);
      this.waiting_for_hb_animation = 0;
    }

    this.floating_header_bar_revealer.child = null;
    this.header_bar_revealer.child = this.header_bar;
  }
}
