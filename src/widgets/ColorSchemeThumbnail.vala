/* ColorSchemeThumbnail.vala
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

/**
 * Used to load contents of "color-scheme-thumbnail.svg" as a color scheme
 * thumbnail template. It can convert {@link Terminal.Scheme} to string that
 * contains an edited version of "color-scheme-thumbnail.svg".
 */
public class Terminal.ColorSchemeThumbnailProvider {
  private static string svg_content = null;

  public static void init_resource () {
    if (svg_content == null) {
      try {
        uint8[] data;

        GLib.File.new_for_uri (
          "resource:///com/raggesilver/BlackBox/resources/svg/color-scheme-thumbnail.svg"
        ).load_contents (null, out data, null);

        svg_content = (string) data;
      }
      catch (Error e) {
        error ("%s", e.message);
      }
    }
  }

  private static void process_node (Xml.Node *node, Scheme scheme) {
    if (node == null) {
      return ;
    }

    Gdk.RGBA? color = null;

    if (node->get_prop ("label") == "palette") {
      int len = (int) scheme.palette.length;
      color = scheme.palette.index (Random.int_range (7, len));
    }

    if (node->get_prop ("label") == "fg") {
      color = scheme.foreground_color;
    }

    if (color != null) {
      node->set_prop (
        "style",
        "stroke:%s;stroke-width:3;stroke-linecap:round;".printf (
          color.to_string ()
        )
      );
    }

    for (
      var child = node->children;
      child != null;
      child = child->next_element_sibling ()
    ) {
      process_node (child, scheme);
    }
  }

  public static uint8[]? apply_scheme (Scheme scheme) {
    // Parse svg_content into XML document
    var doc = Xml.Parser.parse_memory (svg_content, svg_content.data.length);

    // Edit XML document according to color scheme
    process_node (doc->get_root_element (), scheme);

    // Convert edited XML document to string
    string str;
    doc->dump_memory (out str, null);

    var data = str.data.copy ();

    delete doc;
    return data;
  }
}

public class Terminal.ColorSchemePreviewPaintable : GLib.Object, Gdk.Paintable {
  private Rsvg.Handle? handler;
  private Scheme       scheme;

  public ColorSchemePreviewPaintable (Scheme scheme) {
    this.scheme = scheme;
    this.load_image.begin ();
  }

  public void snapshot (Gdk.Snapshot snapshot, double width, double height) {
    var cr = (snapshot as Gtk.Snapshot)?.append_cairo (
      Graphene.Rect ().init (0, 0, (float) width, (float) height)
    );
    try {
      this.handler.render_document (cr, Rsvg.Rectangle () {
        x = 0,
        y = 0,
        width = width,
        height = height
      });
    }
    catch (Error e) {
      // TODO: should we make this a warning? It seems a bit overkill to crash
      // the app because we can't render a thumbnail
      error ("%s", e.message);
    }
  }

  // Methods

  private async void load_image () {
    var file_content = ColorSchemeThumbnailProvider.apply_scheme (this.scheme);
    return_if_fail (file_content != null);

    try {
      this.handler = new Rsvg.Handle.from_data (file_content);
    }
    catch (Error e) {
      error ("%s", e.message);
    }
  }
}

/**
 * Thumbnail of color scheme
 * Base on GtkSourceStyleSchemePreview:
 * https://gitlab.gnome.org/GNOME/gtksourceview/-/blob/master/gtksourceview/gtksourcestyleschemepreview.c
 */
public class Terminal.ColorSchemeThumbnail : Gtk.FlowBoxChild {
  public bool   selected    { get; set; }
  public Scheme scheme      { get; set; }

  public ColorSchemeThumbnail (Scheme scheme) {
    Object (has_tooltip: true, scheme: scheme);

    this.tooltip_text = scheme.name;
    this.add_css_class ("thumbnail");

    // The color scheme thumbnail
    var img = new Gtk.Picture () {
      paintable = new ColorSchemePreviewPaintable (scheme),
      width_request = 110,
      height_request = 70,
      //  height_request = 90,
      css_classes = { "card" },
      cursor = new Gdk.Cursor.from_name ("pointer", null),
    };

    var css_provider = Marble.get_css_provider_for_data (
      //  "picture { background-color: %s; padding-bottom: 2em; }".printf (
      "picture { background-color: %s; }".printf (
        scheme.background_color.to_string ()
      )
    );

    img.get_style_context ().add_provider (
      css_provider,
      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );

    // Icon will show when this.selected is true
    var checkicon = new Gtk.Image () {
      icon_name = "object-select-symbolic",
      pixel_size = 14,
      vexpand = true,
      valign = Gtk.Align.END,
      halign = Gtk.Align.END,
      visible = false,
    };

    img.set_parent (this);
    checkicon.set_parent (this);

    //  var lbl = new Gtk.Label (scheme.name) {
    //    ellipsize = Pango.EllipsizeMode.END,
    //    halign = Gtk.Align.CENTER,
    //    hexpand = true,
    //    justify = Gtk.Justification.CENTER,
    //    valign = Gtk.Align.END,
    //    wrap = false,
    //    xalign = 0.5f,
    //  };

    //  Marble.set_theming_for_data (lbl, "label { color: %s; margin: 0.5em 8px; }".printf(scheme.foreground_color.to_string ()), null, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

    //  lbl.set_parent (this);

    this.notify["selected"].connect (() => {
      if (this.selected) {
        img.add_css_class ("selected");
      }
      else {
        img.remove_css_class ("selected");
      }
      checkicon.visible = this.selected;
    });

    // Emit activate signal when thumbnail is chicked.
    var mouse_control = new Gtk.GestureClick ();
    mouse_control.pressed.connect (() => {
      if (!this.selected) {
        this.selected = true;
        this.activate ();
      }
    });
    img.add_controller (mouse_control);
  }
}
