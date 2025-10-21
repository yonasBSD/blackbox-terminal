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
  private Gtk.PopoverMenu popover;

  public Terminal terminal       { get; protected set; }
  public string?  title_override { get; private set; default = null; }

  // Scroll handling state
  private Gtk.EventControllerScroll? scroll_controller = null;
  // Tuned constants for touchpad scrolling (keep minimal config)
  private const double TOUCHPAD_SCROLL_SCALE = 0.1; // live finger motion scaling
  private const double TOUCHPAD_KINETIC_SCALE = 2.0; // initial inertia multiplier
  private const double TOUCHPAD_DAMPING = 12.0; // exponential damping

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
    this.popover = build_popover();

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

    // Ensure default kinetic scrolling is disabled; we'll implement our own gentle inertia
    this.scrolled.kinetic_scrolling = false;

    // Add scroll event controller to handle touchpad sensitivity and custom kinetic inertia
    this.scroll_controller = new Gtk.EventControllerScroll (
      Gtk.EventControllerScrollFlags.VERTICAL | Gtk.EventControllerScrollFlags.KINETIC
    );
    // Capture before GtkScrolledWindow/VTE handle it
    this.scroll_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
    this.scroll_controller.scroll.connect (this.on_scroll_event);
    this.scroll_controller.decelerate.connect (this.on_scroll_decelerate);
    // Attach to the scrolled window to reliably get all scroll events (including inertia)
    this.scrolled.add_controller (this.scroll_controller);
    // refocus terminal after closing context menu, otherwise the focus will go on the header buttons
    this.popover.closed.connect_after (pop_close);
  }

  private bool on_scroll_event (double dx, double dy) {
    // Detect touchpad vs mouse wheel using scroll unit
    var unit = this.scroll_controller != null ? this.scroll_controller.get_unit () : Gdk.ScrollUnit.WHEEL;
    bool is_touchpad = (unit != Gdk.ScrollUnit.WHEEL);
    if (!is_touchpad) {
      // Mouse wheel: let default handling take over
      return false;
    }

    // Touchpad: scale delta using tuned constant to reduce speed
    dy *= TOUCHPAD_SCROLL_SCALE;

    var adjustment = this.scrolled.vadjustment;
    // Scroll by the adjusted delta
    adjustment.value += dy * adjustment.step_increment;

    // Clamp to valid range
    adjustment.value = Math.fmax (adjustment.lower,
                                  Math.fmin (adjustment.upper - adjustment.page_size,
                                             adjustment.value));

    return true; // Event handled for touchpad
  }

  // --- Custom kinetic inertia for touchpad scrolling ---
  private uint   kinetic_tick_id = 0;
  private double kinetic_velocity_y = 0.0; // pixels per second (as provided by GTK)
  private int64  kinetic_last_time_us = 0;

  private void on_scroll_decelerate (double vx, double vy) {
    // This signal is only emitted for smooth/gesture scrolling (i.e., touchpads)
    // Scale down initial velocity to avoid too-fast inertia
    // smaller -> slower inertia
    this.kinetic_velocity_y = vy * TOUCHPAD_KINETIC_SCALE;
    this.kinetic_last_time_us = 0; // reset for next tick

    // Start/restart tick
    if (this.kinetic_tick_id != 0) {
      this.remove_tick_callback (this.kinetic_tick_id);
      this.kinetic_tick_id = 0;
    }

    this.kinetic_tick_id = this.add_tick_callback ((w, clock) => {
      // Compute delta time in seconds
      int64 now_us = clock.get_frame_time (); // microseconds
      if (this.kinetic_last_time_us == 0) {
        this.kinetic_last_time_us = now_us;
        return true; // wait for next frame to have dt
      }
      double dt = (now_us - this.kinetic_last_time_us) / 1000000.0;
      this.kinetic_last_time_us = now_us;

      var adj = this.scrolled.vadjustment;

      // Advance by current velocity
      double new_value = adj.value + this.kinetic_velocity_y * dt;

      // Clamp within bounds
      double min_v = adj.lower;
      double max_v = adj.upper - adj.page_size;
      if (new_value < min_v) new_value = min_v;
      if (new_value > max_v) new_value = max_v;
      adj.value = new_value;

      // Apply stronger damping so inertia quickly but smoothly fades
      // Exponential decay: v = v * exp(-k * dt)
      // larger -> faster slowdown
      this.kinetic_velocity_y *= Math.exp (-TOUCHPAD_DAMPING * dt);

      // Stop when velocity is negligible or we've hit bounds
      if (Math.fabs (this.kinetic_velocity_y) < 5.0 || new_value == min_v || new_value == max_v) {
        if (this.kinetic_tick_id != 0) {
          this.remove_tick_callback (this.kinetic_tick_id);
          this.kinetic_tick_id = 0;
        }
        return false; // stop ticking
      }

      return true; // continue ticking
    });
  }

  // no reload function: constants are compiled-in for minimal change set

  private void on_show_scrollbars_updated () {
    var settings = Settings.get_default ();
    var show_scrollbars = settings.show_scrollbars;

    // Always keep terminal inside the scrolled window so custom scrolling works
    if (this.terminal.parent != this.scrolled) {
      if (this == this.terminal.parent) this.remove (this.terminal);
      this.scrolled.child = this.terminal;
    }

    // Never hide the scrolled window itself; instead toggle a CSS class to hide bars
    if (show_scrollbars) {
      this.scrolled.remove_css_class ("hide-scrollbars");
    } else {
      this.scrolled.add_css_class ("hide-scrollbars");
    }
  }

  public Gtk.PopoverMenu build_popover () {
    var builder = new Gtk.Builder.from_resource ("/com/raggesilver/BlackBox/gtk/terminal-menu.ui");
    var pop = builder.get_object ("popover") as Gtk.PopoverMenu;

    pop.set_parent (this);
    pop.set_has_arrow (false);
    pop.set_halign (Gtk.Align.START);

    return pop;
  }

  public void pop_close() {
    this.terminal.grab_focus();
  }

  public void show_menu (int n_pressed, double x, double y) {
    if (this.terminal.hyperlink_hover_uri != null) {
      this.terminal.window.link = this.terminal.hyperlink_hover_uri;
    } else {
      this.terminal.window.link = this.terminal.check_match_at (x, y, null);
    }

    double x_in_view, y_in_view;
    this.terminal.translate_coordinates (this, x, y, out x_in_view, out y_in_view);

    var r = Gdk.Rectangle () {
      x = (int) x_in_view,
      y = (int) y_in_view
    };

    this.popover.set_pointing_to (r);
    this.popover.popup ();
  }

  public void search () {
    this.search_toolbar.open ();
  }

  public void override_title (string? _title) {
    this.title_override = _title;
  }

  public uint get_id () {
    return terminal.id;
  }

  public void on_before_close () {
    terminal.on_before_close ();
  }
}
