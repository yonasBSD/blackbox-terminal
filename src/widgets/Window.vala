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

  Adw.HeaderBar   header_bar;
  Adw.TabBar      tab_bar;
  Gtk.Button      new_tab_button;
  Gtk.MenuButton  menu_button;
  Gtk.Revealer    header_bar_revealer;

  Gtk.HeaderBar   floating_bar;
  Gtk.Box         floating_controls;
  Gtk.Button      show_headerbar_button;
  Gtk.Button      fullscreen_button;
  Gtk.Revealer    floating_header_bar_revealer;

  Settings        settings = Settings.get_default ();

  const uint header_bar_revealer_duration_ms = 250;

  construct {
    if (DEVEL) {
      this.add_css_class ("devel");
    }

    var layout_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

    this.header_bar = new Adw.HeaderBar () {
      show_start_title_buttons = true,
      show_end_title_buttons = true,

      css_classes = { "flat" },
    };

    this.header_bar_revealer = new Gtk.Revealer () {
      transition_duration = Window.header_bar_revealer_duration_ms,
      child = this.header_bar,
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

    var more_menu = new GLib.Menu ();
    var section1 = new GLib.Menu ();
    var section2 = new GLib.Menu ();
    section1.append ("Preferences", "win.edit_preferences");
    section2.append ("Help", "win.show-help-overlay");
    section2.append ("About", "app.about");
    more_menu.append_section (null, section1);
    more_menu.append_section (null, section2);
    this.menu_button = new Gtk.MenuButton () {
      can_focus = false,
      menu_model = more_menu,
      icon_name = "open-menu-symbolic",

      hexpand = false,
      halign = Gtk.Align.END,
    };

    var title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
      hexpand = true,
      halign = Gtk.Align.FILL,
    };

    title_box.append (this.tab_bar);
    title_box.append (this.new_tab_button);
    title_box.append (this.menu_button);

    this.header_bar.title_widget = title_box;

    // Floating controls bar  ===============

    this.fullscreen_button = new Gtk.Button.from_icon_name (
      "com.raggesilver.BlackBox-fullscreen-symbolic"
    );
    this.show_headerbar_button = new Gtk.Button.from_icon_name (
      "com.raggesilver.BlackBox-show-headerbar-symbolic"
    );
    var btn_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
      css_classes = { "floating-btn-box" },
      overflow = Gtk.Overflow.HIDDEN,
      valign = Gtk.Align.CENTER,
    };
    btn_box.append (this.fullscreen_button);
    btn_box.append (new Gtk.Separator(Gtk.Orientation.VERTICAL));
    btn_box.append (this.show_headerbar_button);

    this.floating_controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
      hexpand = true,
      valign = Gtk.Align.CENTER,
      halign = Gtk.Align.START
    };
    this.floating_controls.append (new Gtk.MenuButton () {
      menu_model = more_menu,
      icon_name = "open-menu-symbolic",
      css_classes = { "circular" },
      valign = Gtk.Align.CENTER,
      can_focus = false,
    });
    this.floating_controls.append (btn_box);

    this.floating_bar = new Gtk.HeaderBar () {
      css_classes = {"flat" },
      title_widget = new Gtk.Label ("") { hexpand = true },
    };

    this.floating_header_bar_revealer = new Gtk.Revealer () {
      transition_duration = Window.header_bar_revealer_duration_ms,
      transition_type = Gtk.RevealerTransitionType.CROSSFADE,

      valign = Gtk.Align.START,
      vexpand = false,
      child = floating_bar,
      visible = false,

      css_classes = { "floating-revealer" },
    };

    this.on_decoration_layout_changed ();

    layout_box.append (this.header_bar_revealer);
    layout_box.append (this.tab_view);

    var overlay = new Gtk.Overlay ();
    overlay.child = layout_box;
    overlay.add_overlay (this.floating_header_bar_revealer);

    this.content = overlay;
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
      "/com/raggesilver/BlackBox/resources/style.css"
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

    this.settings.schema.bind (
      "show-menu-button",
      this.menu_button,
      "visible",
      SettingsBindFlags.GET
    );

    settings.notify["floating-controls"].connect(() => {
      if (!settings.floating_controls) {
        this.floating_header_bar_revealer.reveal_child = false;
      }
    });

    settings.notify["show-headerbar"].connect(() => {
      if (settings.show_headerbar) {
        this.floating_header_bar_revealer.reveal_child = false;
      }
    });

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

    this.fullscreen_button.clicked.connect (() => {
      if (this.fullscreened) {
        this.unfullscreen ();
      } else {
        this.fullscreen ();
      }
    });

    this.show_headerbar_button.clicked.connect (() => {
      this.settings.show_headerbar = true;
      this.floating_header_bar_revealer.reveal_child = false;
    });

    this.floating_header_bar_revealer.notify["reveal-child"].connect (() => {
      if (this.floating_header_bar_revealer.reveal_child) {
        this.floating_header_bar_revealer.visible = true;
      }
    });

    this.floating_header_bar_revealer.notify["child-revealed"].connect (() => {
      if (!this.floating_header_bar_revealer.reveal_child) {
        this.floating_header_bar_revealer.visible = false;
      }
    });

    var s = Gtk.Settings.get_default ();
    s.notify["gtk-decoration-layout"].connect(this.on_decoration_layout_changed);

    var c = new Gtk.EventControllerMotion ();
    c.motion.connect ((_, x, y) => {
      if (this.settings.show_headerbar) {
        return;
      }
      if (!this.settings.floating_controls) {
        return;
      }

      var h = this.floating_bar.get_height ();
      var is_showing = this.floating_header_bar_revealer.reveal_child;

      var to_show_erea = settings.emit_height;

      // When float headerbar is hiding, just leave a small erea to
      // show it
      var v = (y >= 0) && y <= (is_showing ? h : to_show_erea);

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
          this.waiting_for_floating_hb_animation = Timeout.add (
            settings.delay_before_showing_floating_controls,
            () => {
              this.floating_header_bar_revealer.reveal_child = v;
              this.waiting_for_floating_hb_animation = 0;
              this.floating_bar.focus (Gtk.DirectionType.UP);
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
      w.set_transient_for (this);
      w.set_modal (true);
      w.present ();
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

    sa = new SimpleAction ("switch-headerbar-mode", null);
    sa.activate.connect (() => {
      this.settings.show_headerbar = !this.settings.show_headerbar;
    });
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

  private void on_decoration_layout_changed () {
    var layout = Gtk.Settings.get_default ().gtk_decoration_layout;

    debug ("Decoration layout: %s", layout);

    var window_controls_in_end = layout.split (":", 2)[0].contains ("menu");
    this.floating_bar.remove (this.floating_controls);
    if (window_controls_in_end) {
      this.floating_bar.pack_start (this.floating_controls);
    } else {
      this.floating_bar.pack_end (this.floating_controls);
    }
    this.floating_bar.title_widget.halign
      = window_controls_in_end ? Gtk.Align.START : Gtk.Align.END;
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
}
