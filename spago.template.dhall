{-
{{GENERATED_DOC}}

A custom prelude that provides a larger collection of standard definitions.
-}
let name = "pre"

in  { name
    , dependencies =
      [ "aff"
      , "arrays"
      , "bifunctors"
      , "control"
      , "datetime"
      , "effect"
      , "either"
      , "enums"
      , "foldable-traversable"
      , "maybe"
      , "newtype"
      , "option"
      , "ordered-collections"
      , "parallel"
      , "prelude"
      , "profunctor-lenses"
      , "record"
      , "safe-coerce"
      , "transformers"
      , "tuples"
      , "variant"
      ]
    -- This path is relative to config file
    , packages = {{PACKAGES_DIR}}/packages.dhall
    -- This path is relative to project root
    -- See https://github.com/purescript/spago/issues/648
    , sources = [ "{{SOURCES_DIR}}/src/**/*.purs" ]
    }
