{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeSynonymInstances #-}
module Data.Swagger.Internal.ParamSchema where

import Control.Lens
import Data.Aeson
import Data.Proxy
import GHC.Generics

import Data.Int
import Data.Monoid
import Data.Scientific
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import Data.Time
import Data.Word

import Data.Swagger.Internal
import Data.Swagger.Lens
import Data.Swagger.SchemaOptions

-- | Convert a type into a plain @'ParamSchema'@.
--
-- An example type and instance:
--
-- @
-- {-\# LANGUAGE OverloadedStrings \#-}   -- allows to write 'T.Text' literals
--
-- import Control.Lens
--
-- data Direction = Up | Down
--
-- instance ToParamSchema Direction where
--   toParamSchema = mempty
--      & schemaType .~ SwaggerString
--      & schemaEnum .~ [ \"Up\", \"Down\" ]
-- @
--
-- Instead of manually writing your @'ToParamSchema'@ instance you can
-- use a default generic implementation of @'toParamSchema'@.
--
-- To do that, simply add @deriving 'Generic'@ clause to your datatype
-- and declare a @'ToParamSchema'@ instance for your datatype without
-- giving definition for @'toParamSchema'@.
--
-- For instance, the previous example can be simplified into this:
--
-- @
-- {-\# LANGUAGE DeriveGeneric \#-}
--
-- import GHC.Generics (Generic)
--
-- data Direction = Up | Down deriving Generic
--
-- instance ToParamSchema Direction
-- @
class ToParamSchema a where
  -- | Convert a type into a plain parameter schema.
  --
  -- >>> encode $ toParamSchema (Proxy :: Proxy Integer)
  -- "{\"type\":\"integer\"}"
  toParamSchema :: proxy a -> ParamSchema t
  default toParamSchema :: (Generic a, GToParamSchema (Rep a)) => proxy a -> ParamSchema t
  toParamSchema = genericToParamSchema defaultSchemaOptions

instance {-# OVERLAPPING #-} ToParamSchema String where
  toParamSchema _ = mempty & schemaType .~ SwaggerString

instance ToParamSchema Bool where
  toParamSchema _ = mempty & schemaType .~ SwaggerBoolean

instance ToParamSchema Integer where
  toParamSchema _ = mempty & schemaType .~ SwaggerInteger

instance ToParamSchema Int    where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Int8   where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Int16  where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Int32  where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Int64  where toParamSchema = toParamSchemaBoundedIntegral

instance ToParamSchema Word   where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Word8  where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Word16 where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Word32 where toParamSchema = toParamSchemaBoundedIntegral
instance ToParamSchema Word64 where toParamSchema = toParamSchemaBoundedIntegral

-- | Default plain schema for @'Bounded'@, @'Integral'@ types.
--
-- >>> encode $ toParamSchemaBoundedIntegral (Proxy :: Proxy Int8)
-- "{\"maximum\":127,\"minimum\":-128,\"type\":\"integer\"}"
toParamSchemaBoundedIntegral :: forall proxy a t. (Bounded a, Integral a) => proxy a -> ParamSchema t
toParamSchemaBoundedIntegral _ = mempty
  & schemaType .~ SwaggerInteger
  & schemaMinimum ?~ fromInteger (toInteger (minBound :: a))
  & schemaMaximum ?~ fromInteger (toInteger (maxBound :: a))

instance ToParamSchema Char where
  toParamSchema _ = mempty
    & schemaType .~ SwaggerString
    & schemaMaxLength ?~ 1
    & schemaMinLength ?~ 1

instance ToParamSchema Scientific where
  toParamSchema _ = mempty & schemaType .~ SwaggerNumber

instance ToParamSchema Double where
  toParamSchema _ = mempty & schemaType .~ SwaggerNumber

instance ToParamSchema Float where
  toParamSchema _ = mempty & schemaType .~ SwaggerNumber

timeParamSchema :: String -> ParamSchema t
timeParamSchema format = mempty
  & schemaType      .~ SwaggerString
  & schemaFormat    ?~ T.pack format
  & schemaMinLength ?~ toInteger (length format)

-- |
-- >>> toParamSchema (Proxy :: Proxy Day) ^. schemaFormat
-- Just "yyyy-mm-dd"
instance ToParamSchema Day where
  toParamSchema _ = timeParamSchema "yyyy-mm-dd"

-- |
-- >>> toParamSchema (Proxy :: Proxy LocalTime) ^. schemaFormat
-- Just "yyyy-mm-ddThh:MM:ss"
instance ToParamSchema LocalTime where
  toParamSchema _ = timeParamSchema "yyyy-mm-ddThh:MM:ss"

-- |
-- >>> toParamSchema (Proxy :: Proxy ZonedTime) ^. schemaFormat
-- Just "yyyy-mm-ddThh:MM:ss+hhMM"
instance ToParamSchema ZonedTime where
  toParamSchema _ = timeParamSchema "yyyy-mm-ddThh:MM:ss+hhMM"

-- |
-- >>> toParamSchema (Proxy :: Proxy UTCTime) ^. schemaFormat
-- Just "yyyy-mm-ddThh:MM:ssZ"
instance ToParamSchema UTCTime where
  toParamSchema _ = timeParamSchema "yyyy-mm-ddThh:MM:ssZ"

instance ToParamSchema NominalDiffTime where
  toParamSchema _ = toParamSchema (Proxy :: Proxy Integer)

instance ToParamSchema T.Text where
  toParamSchema _ = toParamSchema (Proxy :: Proxy String)

instance ToParamSchema TL.Text where
  toParamSchema _ = toParamSchema (Proxy :: Proxy String)

instance ToParamSchema All where toParamSchema _ = toParamSchema (Proxy :: Proxy Bool)
instance ToParamSchema Any where toParamSchema _ = toParamSchema (Proxy :: Proxy Bool)
instance ToParamSchema a => ToParamSchema (Sum a)     where toParamSchema _ = toParamSchema (Proxy :: Proxy a)
instance ToParamSchema a => ToParamSchema (Product a) where toParamSchema _ = toParamSchema (Proxy :: Proxy a)
instance ToParamSchema a => ToParamSchema (First a)   where toParamSchema _ = toParamSchema (Proxy :: Proxy a)
instance ToParamSchema a => ToParamSchema (Last a)    where toParamSchema _ = toParamSchema (Proxy :: Proxy a)
instance ToParamSchema a => ToParamSchema (Dual a)    where toParamSchema _ = toParamSchema (Proxy :: Proxy a)

-- |
-- >>> encode $ toParamSchema (Proxy :: Proxy ())
-- "{\"type\":\"string\",\"enum\":[\"_\"]}"
instance ToParamSchema () where
  toParamSchema _ = mempty
    & schemaType .~ SwaggerString
    & schemaEnum ?~ ["_"]

-- | A configurable generic @'ParamSchema'@ creator.
--
-- >>> data Color = Red | Blue deriving Generic
-- >>> encode $ genericToParamSchema defaultSchemaOptions (Proxy :: Proxy Color)
-- "{\"type\":\"string\",\"enum\":[\"Red\",\"Blue\"]}"
genericToParamSchema :: forall proxy a t. (Generic a, GToParamSchema (Rep a)) => SchemaOptions -> proxy a -> ParamSchema t
genericToParamSchema opts _ = gtoParamSchema opts (Proxy :: Proxy (Rep a)) mempty

class GToParamSchema (f :: * -> *) where
  gtoParamSchema :: SchemaOptions -> proxy f -> ParamSchema t -> ParamSchema t

instance GToParamSchema f => GToParamSchema (D1 d f) where
  gtoParamSchema opts _ = gtoParamSchema opts (Proxy :: Proxy f)

instance GToParamSchema f => GToParamSchema (C1 c (S1 s f)) where
  gtoParamSchema opts _ = gtoParamSchema opts (Proxy :: Proxy f)

instance ToParamSchema c => GToParamSchema (K1 i c) where
  gtoParamSchema _ _ _ = toParamSchema (Proxy :: Proxy c)

instance (GEnumParamSchema f, GEnumParamSchema g) => GToParamSchema (f :+: g) where
  gtoParamSchema opts _ = genumParamSchema opts (Proxy :: Proxy (f :+: g))

class GEnumParamSchema (f :: * -> *) where
  genumParamSchema :: SchemaOptions -> proxy f -> ParamSchema t -> ParamSchema t

instance (GEnumParamSchema f, GEnumParamSchema g) => GEnumParamSchema (f :+: g) where
  genumParamSchema opts _ = genumParamSchema opts (Proxy :: Proxy f) . genumParamSchema opts (Proxy :: Proxy g)

instance Constructor c => GEnumParamSchema (C1 c U1) where
  genumParamSchema opts _ s = s
    & schemaType .~ SwaggerString
    & schemaEnum %~ addEnumValue tag
    where
      tag = toJSON (constructorTagModifier opts (conName (Proxy3 :: Proxy3 c f p)))

      addEnumValue x Nothing    = Just [x]
      addEnumValue x (Just xs)  = Just (x:xs)

data Proxy3 a b c = Proxy3

