defmodule PhoenixKitHelloWorld.Gettext do
  @moduledoc """
  Gettext backend for `phoenix_kit_hello_world`.

  A module owns its translations: the catalogue lives in this package's
  `priv/gettext` and ships with it, so a host gets the module's strings
  translated without touching core's catalogue or its own.

  Call sites opt in with `use Gettext, backend: PhoenixKitHelloWorld.Gettext`
  and then use the macros (`gettext/1`, `ngettext/3`, `gettext_noop/1`, …).
  Always the macro form with a literal msgid — `mix gettext.extract` reads the
  macros at compile time, so a runtime `Gettext.gettext(Backend, msgid)` call
  never reaches the `.pot` and its string silently stays untranslated.

  After `use PhoenixKitWeb, :live_view` (which wires core's backend) a second
  `use Gettext, backend: PhoenixKitHelloWorld.Gettext` re-points the macros at
  this backend; the later `use` wins.

  Refresh the catalogue with `mix gettext.extract --merge` after adding or
  changing a string, then fill the new `msgstr` in every shipped locale.
  """
  use Gettext.Backend, otp_app: :phoenix_kit_hello_world
end
