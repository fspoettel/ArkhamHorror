module Arkham.Projection (module Arkham.Projection, module X) where

import Arkham.Classes.Entity
import Arkham.Classes.HasGame
import Arkham.Field as X
import Arkham.Id
import Arkham.Prelude

class Projection a where
  getAttrs :: (HasCallStack, HasGame m) => EntityId a -> m (EntityAttrs a)
  field :: (HasCallStack, HasGame m) => Field a typ -> EntityId a -> m typ
  project :: (HasCallStack, HasGame m) => EntityId a -> m (Maybe a)

fieldMay :: forall a typ m. (HasGame m, Projection a) => Field a typ -> EntityId a -> m (Maybe typ)
fieldMay fld eid = do
  hasEntity <- isJust <$> project @a eid
  if hasEntity then fieldMap fld Just eid else pure Nothing

fieldMayJoin
  :: forall a typ m. (HasGame m, Projection a) => Field a (Maybe typ) -> EntityId a -> m (Maybe typ)
fieldMayJoin fld eid = do
  hasEntity <- isJust <$> project @a eid
  if hasEntity then field fld eid else pure Nothing

withMaybeField
  :: (Projection a, HasGame m) => Field a (Maybe typ) -> EntityId a -> (typ -> m ()) -> m ()
withMaybeField fld eid f = fieldMayJoin fld eid >>= traverse_ f

fieldWithDefault
  :: (Projection a, HasGame m, AsId b, IdOf b ~ EntityId a)
  => typ
  -> Field a (Maybe typ)
  -> b
  -> m typ
fieldWithDefault def fld (asId -> entityId) = fromMaybe def <$> field fld entityId

fieldJust
  :: (HasCallStack, Projection a, HasGame m, Show (Field a (Maybe typ)), AsId b, IdOf b ~ EntityId a)
  => Field a (Maybe typ)
  -> b
  -> m typ
fieldJust fld (asId -> entityId) = fromJustNote missingField <$> field fld entityId
 where
  missingField = "Maybe field " <> show fld <> " was Nothing"

fieldP
  :: (HasCallStack, HasGame m, Projection a)
  => Field a typ
  -> (typ -> Bool)
  -> EntityId a
  -> m Bool
fieldP = fieldMap

fieldPM
  :: (HasCallStack, HasGame m, Projection a)
  => Field a typ
  -> (typ -> m Bool)
  -> EntityId a
  -> m Bool
fieldPM = fieldMapM

fieldMap
  :: forall a b typ m
   . (HasCallStack, HasGame m, Projection a)
  => Field a typ
  -> (typ -> b)
  -> EntityId a
  -> m b
fieldMap f g = fieldMapM f (pure . g)

fieldMapM
  :: (HasCallStack, HasGame m, Projection a)
  => Field a typ
  -> (typ -> m b)
  -> EntityId a
  -> m b
fieldMapM f g eid = g =<< field f eid

forField
  :: (HasCallStack, HasGame m, Projection a, typ ~ Element (t typ), MonoFoldable (t typ))
  => Field a (t typ)
  -> EntityId a
  -> (typ -> m ())
  -> m ()
forField f eid g = flip for_ g =<< field f eid

filterByFieldM
  :: (EntityId a ~ Element seq, IsSequence seq, HasGame m, Projection a)
  => Field a typ
  -> (typ -> m Bool)
  -> seq
  -> m seq
filterByFieldM fld f = filterM (fieldPM fld f)

filterByField
  :: (EntityId a ~ Element seq, IsSequence seq, HasGame m, Projection a)
  => Field a typ
  -> (typ -> Bool)
  -> seq
  -> m seq
filterByField fld f = filterByFieldM fld (pure . f)

fieldSome :: (HasGame m, Projection a) => Field a Int -> EntityId a -> m Bool
fieldSome fld = fieldP fld (> 0)

fieldNone :: (HasGame m, Projection a) => Field a Int -> EntityId a -> m Bool
fieldNone fld = fieldP fld (== 0)

fieldLength :: (HasGame m, Projection a) => Field a [b] -> EntityId a -> m Int
fieldLength fld = fieldMap fld length

fieldAny :: (HasGame m, Projection a) => Field a [b] -> (b -> Bool) -> EntityId a -> m Bool
fieldAny fld f eid = fieldP fld (any f) eid
