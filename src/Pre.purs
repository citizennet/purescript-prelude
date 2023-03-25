module Pre
  ( module Control.Alt
  , module Control.Monad.Error.Class
  , module Control.Monad.Except.Trans
  , module Control.Monad.Maybe.Trans
  , module Control.Monad.Trans.Class
  , module Control.Parallel
  , module Data.Array.NonEmpty.Internal
  , module Data.Bifunctor
  , module Data.DateTime
  , module Data.Either
  , module Data.Enum
  , module Data.Foldable
  , module Data.Lens
  , module Data.Map
  , module Data.Maybe
  , module Data.Newtype
  , module Data.Set
  , module Data.Symbol
  , module Data.Traversable
  , module Data.Tuple
  , module Data.Tuple.Nested
  , module Effect
  , module Effect.Aff
  , module Effect.Aff.Class
  , module Effect.Class
  , module Data.FoldableWithIndex
  , module Prelude
  , module Type.Proxy
  , class GetOptional
  , class GetRequired
  , Option
  , OptionRecord
  , Variant
  , (.?)
  , (.!)
  , foldMapFirst
  , foldMapWithIndexFirst
  , getOptional
  , getOptionalFlipped
  , getRequired
  , getRequiredFlipped
  , inj
  , match
  , nonEmptyArray
  , option
  , optionRecord
  , symbol
  , throw
  , variant
  ) where

import Prelude

import Control.Alt ((<|>))
import Control.Monad.Error.Class (class MonadThrow, throwError)
import Control.Monad.Except.Trans (ExceptT(..), except, runExceptT)
import Control.Monad.Maybe.Trans (MaybeT(..), runMaybeT)
import Control.Monad.Trans.Class (lift)
import Control.Parallel (class Parallel, parallel, sequential)
import Data.Array.NonEmpty as Data.Array.NonEmpty
import Data.Array.NonEmpty.Internal (NonEmptyArray)
import Data.Bifunctor (lmap)
import Data.DateTime (DateTime(..))
import Data.Either (Either(..), hush, note)
import Data.Enum (class BoundedEnum, class Enum)
import Data.Foldable (class Foldable, find, findMap, fold, foldM, foldMap, foldl, for_)
import Data.FoldableWithIndex (class FoldableWithIndex, foldMapWithIndex)
import Data.Lens (Lens, Lens', lens)
import Data.Map (Map, SemigroupMap(..))
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Newtype (class Newtype, over, un)
import Data.Semigroup.First as Data.Semigroup.First
import Data.Set (Set)
import Data.Symbol (class IsSymbol)
import Data.Traversable (for, for_, traverse, traverse_)
import Data.Tuple (Tuple(..))
import Data.Tuple.Nested (type (/\), (/\))
import Data.Variant as Data.Variant
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (liftEffect)
import Option as Option
import Prim.Row as Prim.Row
import Prim.RowList as Prim.RowList
import Record as Record
import Safe.Coerce as Safe.Coerce
import Type.Proxy (Proxy(..))

type Option =
  Option.Option

type OptionRecord =
  Option.Record

type Variant =
  Data.Variant.Variant

-- | A helper for accessing optional properties
-- |
-- | example:
-- | given
-- | ```
-- | record :: Option.Record () ( int :: Int )
-- | record = optionRecord { int: 42 }
-- | ```
-- | ```
-- | int :: Maybe Int
-- | int = record .? { int: _ }
-- | ```
-- | is equivalent to:
-- | ```
-- | int :: Maybe Int
-- | int = getOptional { int: _ } record
-- | ```
-- | is equivalent to:
-- | ```
-- | int :: Maybe Int
-- | int = Option.get (Proxy :: Proxy "int") (Option.optional record)
-- | ```
-- | There is also an instance for `Option.Option`
class GetOptional option label value | option label -> value where
  getOptional ::
    forall row.
    Prim.RowList.RowToList row (Prim.RowList.Cons label value Prim.RowList.Nil) =>
    (value -> Record row) ->
    option ->
    Maybe value

instance getOptionalOption ::
  ( IsSymbol label
  , Prim.Row.Cons label value optional' optional
  ) =>
  GetOptional (Option optional) label value where
  getOptional f = Option.get (symbol f)

instance getOptionalOptionRecord ::
  ( IsSymbol label
  , Prim.Row.Cons label value optional' optional
  , Option.ToRecord required optional record
  ) =>
  GetOptional (OptionRecord required optional) label value where
  getOptional f = getOptional f <<< Option.optional

instance getOptionalVariant ::
  ( IsSymbol label
  , Prim.Row.Cons label value variant' variant
  ) =>
  GetOptional (Variant variant) label value where
  getOptional f = Data.Variant.prj (symbol f)

-- | A helper for accessing required properties
-- |
-- | example:
-- | given
-- | ```
-- | record :: Option.Record ( int :: Int ) ()
-- | record = optionRecord { int: 42 }
-- | ```
-- | ```
-- | int :: Int
-- | int = record .! { int: _ }
-- | ```
-- | is equivalent to:
-- | ```
-- | int :: Int
-- | int = getRequired { int: _ } record
-- | ```
-- | is equivalent to:
-- | ```
-- | int :: Int
-- | int = (Option.required record).int
-- | ```
class GetRequired record label value | record label -> value where
  getRequired ::
    forall row.
    Prim.RowList.RowToList row (Prim.RowList.Cons label value Prim.RowList.Nil) =>
    (value -> Record row) ->
    record ->
    value

instance getRequiredRecord ::
  ( IsSymbol label
  , Prim.Row.Cons label value required' required
  ) =>
  GetRequired (Record required) label value where
  getRequired f = Record.get (symbol f)

instance getRequiredOptionRecord ::
  ( IsSymbol label
  , Prim.Row.Cons label value required' required
  , Option.ToRecord required optional record
  ) =>
  GetRequired (OptionRecord required optional) label value where
  getRequired f = getRequired f <<< Option.required

foldMapFirst ::
  forall a f k v.
  Ord k =>
  Foldable f =>
  (a -> Map k v) ->
  f a ->
  Map k v
foldMapFirst f xs = Safe.Coerce.coerce (foldMap coercedF xs)
  where
  coercedF :: a -> SemigroupMap k (Data.Semigroup.First.First v)
  coercedF = Safe.Coerce.coerce f

foldMapWithIndexFirst ::
  forall a f i k v.
  Ord k =>
  FoldableWithIndex i f =>
  (i -> a -> Map k v) ->
  f a ->
  Map k v
foldMapWithIndexFirst f xs = Safe.Coerce.coerce (foldMapWithIndex coercedF xs)
  where
  coercedF :: i -> a -> SemigroupMap k (Data.Semigroup.First.First v)
  coercedF = Safe.Coerce.coerce f

getOptionalFlipped ::
  forall label option row value.
  GetOptional option label value =>
  IsSymbol label =>
  Prim.RowList.RowToList row (Prim.RowList.Cons label value Prim.RowList.Nil) =>
  option ->
  (value -> Record row) ->
  Maybe value
getOptionalFlipped = flip getOptional

infixl 9 getOptionalFlipped as .?

getRequiredFlipped ::
  forall label record row value.
  GetRequired record label value =>
  IsSymbol label =>
  Prim.RowList.RowToList row (Prim.RowList.Cons label value Prim.RowList.Nil) =>
  record ->
  (value -> Record row) ->
  value
getRequiredFlipped = flip getRequired

infixl 9 getRequiredFlipped as .!

inj ::
  forall proxy sym a r1 r2.
  Prim.Row.Cons sym a r1 r2 =>
  IsSymbol sym =>
  proxy sym ->
  a ->
  Data.Variant.Variant r2
inj = Data.Variant.inj

match ::
  forall rl r r1 r2 b.
  Prim.RowList.RowToList r rl =>
  Data.Variant.VariantMatchCases rl r1 b =>
  Prim.Row.Union r1 () r2 =>
  Record r ->
  Data.Variant.Variant r2 ->
  b
match = Data.Variant.match

-- | A helper for construction NonEmptyArray
-- |
-- | example:
-- | ```
-- | nonEmptyArray
-- |   { head: 1
-- |   , tail: [2, 3]
-- |   }
-- | ```
-- | is equivalent to:
-- | ```
-- | Data.Array.NonEmpty.cons'
-- |   1
-- |   [2, 3]
-- | ```
nonEmptyArray ::
  forall a.
  { head :: a
  , tail :: Array a
  } ->
  NonEmptyArray a
nonEmptyArray record = Data.Array.NonEmpty.cons' record.head record.tail

-- | An alias for `Option.fromRecord`
-- |
-- | https://github.com/joneshf/purescript-option/blob/8506cbf1fd5d5465a9dc990dfe6f2960ae51c1ab/src/Option.purs#L2552-L2556
option ::
  forall optional record.
  Option.FromRecord record () optional =>
  Record record ->
  Option optional
option = Option.fromRecord

-- | An alias for `Option.recordFromRecord`
-- |
-- | https://github.com/joneshf/purescript-option/blob/8506cbf1fd5d5465a9dc990dfe6f2960ae51c1ab/src/Option.purs#L2942-L2947
optionRecord ::
  forall optional record required.
  Option.FromRecord record required optional =>
  Record record ->
  OptionRecord required optional
optionRecord = Option.recordFromRecord

-- | A helper for constructing Proxy carrying a Symbol
-- |
-- | example:
-- | `symbol { foo: _ }` is equivalent to `Proxy :: _ "foo"`
symbol ::
  forall a row sym.
  IsSymbol sym =>
  Prim.RowList.RowToList row (Prim.RowList.Cons sym a Prim.RowList.Nil) =>
  (a -> Record row) ->
  Proxy sym
symbol _ = Proxy

-- | Helper for throwing `Variant` errors in a `MonadThrow` monad.
-- | This is a shorthand for `throwError <<< variant`.
throw ::
  forall a error label m record variant variant'.
  IsSymbol label =>
  Prim.Row.Cons label error () record =>
  Prim.Row.Cons label error variant' variant =>
  Prim.RowList.RowToList record (Prim.RowList.Cons label error Prim.RowList.Nil) =>
  MonadThrow (Variant variant) m =>
  Record record ->
  m a
throw = throwError <<< variant

-- | A helper for constructing `Variant` values
-- |
-- | example:
-- | `variant { foo: "foo" }` is equivalent to `Data.Variant.inj (symbol { foo: _ }) "foo"`
variant ::
  forall anything label record value variant.
  IsSymbol label =>
  Prim.Row.Cons label value () record =>
  Prim.Row.Cons label value anything variant =>
  Prim.RowList.RowToList record (Prim.RowList.Cons label value Prim.RowList.Nil) =>
  Record record ->
  Variant variant
variant record =
  inj
    (Proxy :: Proxy label)
    (Record.get (Proxy :: Proxy label) record)
