# Contribute to Black Box

Thank you for considering contributing to Black Box!

This guide aims to make it easier for us to communicate and further develop
Black Box.

You can contribute in many ways: reporting bugs, providing feedback, translating
the app, or writing code.

## Plan ahead

If you plan to develop a new feature for Black Box,
[open a feature request first.](https://gitlab.gnome.org/raggesilver/blackbox/-/issues/new?issuable_template=feature_request&issue[issue_type]=issue)
This ensures we can discuss the idea and the implementation beforehand. Remember
that not all feature requests will be accepted, as some might diverge from Black
Box's philosophy.

## Bugs and Feature Requests

Black Box has templates for bugs and feature requests. Please use them!

- [Feature request](https://gitlab.gnome.org/raggesilver/blackbox/-/issues/new?issuable_template=feature_request&issue[issue_type]=issue)
- [Bug report](https://gitlab.gnome.org/raggesilver/blackbox/-/issues/new?issuable_template=bug&issue[issue_type]=issue)
- [Security issue](https://gitlab.gnome.org/raggesilver/blackbox/-/issues/new?issuable_template=bug&issue[issue_type]=issue&issue[confidential]=true) - make
  sure "confidential" is checked

## Translating

Black Box is accepting translations through Weblate! If you'd like to
contribute with translations, visit the
[Weblate project](https://hosted.weblate.org/projects/blackbox/).

<a href="https://hosted.weblate.org/projects/blackbox/blackbox/">
  <img src="https://hosted.weblate.org/widgets/blackbox/-/blackbox/multi-auto.svg" alt="Translation status" />
</a>

## Writing Code

Before writing code, make sure you have followed [these instructions](#plan-ahead).

### Setup

I recommend using [Visual Studio Code](https://code.visualstudio.com/) with the
following extensions:

- [Vala](https://marketplace.visualstudio.com/items?itemName=prince781.vala)
- [Editorconfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)
- [Flatpak](https://marketplace.visualstudio.com/items?itemName=bilelmoussaoui.flatpak-vscode)

### Code Style

Black Box follows the Prettier code style as much as possible. With one
exception: brace style.

```vala
public class Terminal.YourClass : YourParent {
  construct {
    // ...
  }

  public YourClass () {
    Object ();

    this.notify ["my-change"].connect (this.my_callback);
  }

  private void my_callback (
    int x,
    int y,
    int n_times
  ) {
    if (x < 0) {
      // ...
    }
    else if (x > 9) {
      // ...
    }
    else {
      // ...
      try {
        // ...
      }
      catch (Error e) {
        // ...
      }
    }
  }
}
```

### Reactivity

Avoid using `notify` to update the UI as much as possible. Using
[GLib.Settings.bind](https://valadoc.org/gio-2.0/GLib.Settings.bind.html),
[GLib.Settings.bind_with_mapping](https://valadoc.org/gio-2.0/GLib.Settings.bind_with_mapping.html),
or [GLib.Object.bind_property](https://valadoc.org/gobject-2.0/GLib.Object.bind_property.html)
is preferred.

### Warnings

Do your best not to introduce new compilation or runtime warnings to the app.
Warnings make it harder to debug errors and give users the impression that the
app is not working as it should.
