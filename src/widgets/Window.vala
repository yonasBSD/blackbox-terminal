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
  Gtk.Button    new_tab_button;
  Gtk.Revealer  header_bar_revealer;
  Settings      settings = Settings.get_default ();

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

    this.header_bar_revealer = new Gtk.Revealer ();
    this.header_bar_revealer.child = this.header_bar;

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

    layout_box.append (this.header_bar_revealer);
    layout_box.append (this.tab_view);

    this.content = layout_box;
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
  }

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
}

//  [GtkTemplate (ui = "/com/raggesilver/Terminal/layouts/window.ui")]
//  public class Terminal.Window : Adw.ApplicationWindow {
//    private PreferencesWindow? pref_window = null;
//    private Adw.TabView tab_view;

//    [GtkChild] unowned Gtk.Box content_box;
//    [GtkChild] unowned Gtk.Revealer revealer;
//    [GtkChild] unowned Adw.TabBar tab_bar;

//    public Settings settings { get; private set; }
//    public ThemeProvider theme_provider { get; private set; }

//    public Window(
//      Gtk.Application app,
//      string? cwd = null,
//      bool skip_initial_tab = false
//    ) {
//      Object(application: app);

//      Gtk.Settings.get_default().gtk_application_prefer_dark_theme = true;
//      Marble.add_css_provider_from_resource(
//        "/com/raggesilver/Terminal/resources/style.css"
//      );

//      this.settings = new Settings();
//      this.get_style_context().add_class("ragged-terminal");

//      this.settings.schema.bind("show-headerbar", this.revealer,
//        "reveal-child", SettingsBindFlags.GET);

//      this.settings.schema.bind("fill-tabs", this.tab_bar,
//        "expand-tabs", SettingsBindFlags.DEFAULT);

//      this.theme_provider = new ThemeProvider(this.settings);

//      var sa = new SimpleAction("new_window", null);
//      sa.activate.connect(() => {
//        var w = new Window(this.application);
//        w.show();
//      });
//      this.add_action(sa);

//      sa = new SimpleAction("new_tab", null);
//      sa.activate.connect(() => {
//        this.new_tab();
//      });
//      this.add_action(sa);

//      sa = new SimpleAction("edit_preferences", null);
//      sa.activate.connect(() => {
//        if (this.pref_window == null) {
//          this.pref_window = new PreferencesWindow(this.application, this);
//          //  this.pref_window.destroy.connect(() => {
//          //    this.pref_window = null;
//          //  });
//        }
//        this.pref_window.present();
//      });
//      this.add_action(sa);

//      sa = new SimpleAction("about", null);
//      sa.activate.connect(() => {
//        var win = new Gtk.AboutDialog();
//        win.set_transient_for(this);
//        win.present();
//      });
//      this.add_action(sa);

//      this.tab_view = new Adw.TabView() {
//        halign = Gtk.Align.FILL,
//        hexpand = true,
//      };

//      this.content_box.append(this.tab_viewthis.settings = new Settings();
//      this.tab_view.notify["n-pages"].connect(this.on_n_pages_changed);
//      this.tab_view.notify["selected-page"].connect(this.on_page_selected);
//      this.tab_view.create_window.connect(this.on_new_window_requested);

//      if (!skip_initial_tab) {
//        this.new_tab();
//      }
//    }

//    public void on_page_attached(Adw.TabPage page) {
//      var tab = page.get_child() as TerminalTab;
//      tab.window = tab.terminal.window = this;
//    }

//    public unowned Adw.TabView? on_new_window_requested() {
//      var win = new Window(this.application, null, true);
//      win.present();
//      return win.tab_view;
//    }

//    public void on_n_pages_changed() {
//      int count = this.tab_view.n_pages;
//      var context = this.get_style_context();

//      switch (count) {
//        case 0:
//          this.close();
//          break;
//        case 1:
//          context.add_class("single-tab");
//          break;
//        default:
//          context.remove_class("single-tab");
//          break;
//      }
//    }

//    private void on_page_selected() {
//      if (this.tab_view.n_pages < 1) {
//        return;
//      }

//      var tab = this.tab_view.selected_page.get_child() as TerminalTab;
//      if (tab.terminal != null) {
//        tab.terminal.grab_focus();
//      }
//    }

//    public void new_tab() {
//      var tab = new TerminalTab(this, null);
//      var page = this.tab_view.add_page(tab, null);

//      page.title = @"tab $(this.tab_view.n_pages)";
//      tab.notify["title"].connect(() => {
//        page.title = tab.title;
//      });
//      tab.exit.connect(() => {
//        this.tab_view.close_page(page);
//      });
//      this.tab_view.set_selected_page(page);
//    }
//  }
