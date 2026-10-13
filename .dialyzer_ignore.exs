# Dialyzer warnings to ignore (matched by dialyxir).
#
# Gettext 1.0 + Expo 1.1 generate a `Gettext.Plural.plural/2` call against Expo's
# *opaque* `PluralForms` struct inside the generated backend (`use Gettext.Backend`),
# which Dialyzer reports as `call_without_opaque` at `gettext.ex:1`. It is an
# upstream false positive in code this module does not author — scoped to the
# backend module and that one warning type, so real issues elsewhere still
# surface. Every `phoenix_kit_*` package with its own Gettext backend carries the
# same skip; copy it along with the backend.
[
  {"lib/phoenix_kit_hello_world/gettext.ex", :call_without_opaque}
]
