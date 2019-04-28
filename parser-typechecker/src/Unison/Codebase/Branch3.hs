{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TemplateHaskell #-}

module Unison.Codebase.Branch3 where

import           Prelude                  hiding (head,subtract)

import           Control.Lens             hiding (children)
-- import           Control.Monad            (join)
-- import           Data.GUID                (genText)
import           Data.List                (intercalate)
import qualified Data.Map                 as Map
import           Data.Map                 (Map)
import           Data.Text                (Text)
import qualified Data.Text as Text

import qualified Unison.Codebase.Causal3       as Causal
import           Unison.Codebase.Causal3        ( Causal )
import           Unison.Codebase.TermEdit       ( TermEdit )
import           Unison.Codebase.TypeEdit       ( TypeEdit )
import           Unison.Codebase.Path           ( NameSegment
                                                , Path(Path)
                                                )
import qualified Unison.Codebase.Path          as Path
import           Unison.Hash                    ( Hash )
import           Unison.Hashable                ( Hashable )
import qualified Unison.Hashable               as H
import           Unison.Reference               ( Reference )
import           Unison.Referent                ( Referent )
import qualified Unison.Util.Relation          as R
import           Unison.Util.Relation           ( Relation )

data RepoRef
  = Local
  | Github { username :: Text, repo :: Text, commit :: Text }
  deriving (Eq, Ord, Show)

-- type EditGuid = Text

data RepoLink a = RepoLink RepoRef a
  deriving (Eq, Ord, Show)

-- type Link = RepoLink Hash
-- type EditLink = RepoLink EditGuid
--
-- data UnisonRepo = UnisonRepo
--   { _rootNamespace :: Link
--   , _editMap :: EditMap
--   , _editNames :: Relation Text EditGuid
--   } deriving (Eq, Ord, Show)
--
-- data Edits = Edits
--   { _termEdits :: Relation Reference TermEdit
--   , _typeEdits :: Relation Reference TypeEdit
--   } deriving (Eq, Ord, Show)

-- newtype EditMap =
--   EditMap { toMap :: Map EditGuid (Causal Edits) }
--   deriving (Eq, Ord, Show)
--
-- type FriendlyEditNames = Relation Text EditGuid

-- data Codebase' = Codebase'
--   { namespaceRoot :: Branch
--   , edits :: ???
--   }

newtype Branch = Branch { _history :: Causal Branch0 }

head :: Branch -> Branch0
head (Branch c) = Causal.head c

headHash :: Branch -> Hash
headHash (Branch c) = error "todo" -- Causal.currentHash c

data Branch0 = Branch0
  { _terms :: Relation NameSegment Reference
  , _types :: Relation NameSegment Reference
  -- Q: How will we handle merges and conflicts for `children`?
  --    Should this be a relation?
  --    What is the UX to resolve conflicts?
  -- The hash we use to identify branches is the hash of their Causal node.
  , _children :: Map NameSegment Hash
  }

-- type Loader m = Hash -> m (Maybe (Branch m))
-- type Saver m = Branch m ->

makeLenses ''Branch0
makeLenses ''Branch

instance Eq Branch0 where
  a == b = view terms a == view terms b
        && view types a == view types b
        && view children a == view children b

data ForkFailure = SrcNotFound | DestExists
--
-- -- copy a path to another path
-- fork
--   :: Monad m
--   => Loader m
--   -> Branch m
--   -> Path
--   -> Path
--   -> m (Either ForkFailure (Branch m))
-- fork load root src dest = do
--   -- descend from root to src to get a Branch srcBranch
--   getAt load root src >>= \case
--     Nothing -> pure $ Left SrcNotFound
--     Just src' -> setIfNotExists load root dest src' >>= \case
--       Nothing -> pure $ Left DestExists
--       Just root' -> pure $ Right root'
--
-- -- Move the node at src to dest.
-- -- It's okay if `dest` is inside `src`, just create empty levels.
-- -- Try not to `step` more than once at each node.
-- move :: Monad m
--      => Loader m
--      -> Branch m
--      -> Path
--      -> Path
--      -> m (Either ForkFailure (Branch m))
-- move load root src dest = do
--   getAt load root src >>= \case
--     Nothing -> pure $ Left SrcNotFound
--     Just src' ->
--       -- make sure dest doesn't already exist
--       getAt load root dest >>= \case
--         Just _destExists -> pure $ Left DestExists
--         Nothing ->
--         -- find and update common ancestor of `src` and `dest`:
--           Right <$> modifyAtM root ancestor go
--           where
--           (ancestor, relSrc, relDest) = Path.relativeToAncestor src dest
--           go b = do
--             b <- setAt b relDest src'
--             deleteAt b relSrc
--             -- todo: can we combine these into one update?
--
-- setIfNotExists
--   :: Monad m
--   => Loader m -> Branch m -> Path -> Branch m -> m (Maybe (Branch m))
-- setIfNotExists load root dest b =
--   getAt load root dest >>= \case
--     Just _destExists -> pure Nothing
--     Nothing -> Just <$> setAt root dest b
--
-- setAt :: Monad m => Branch m -> Path -> Branch m -> m (Branch m)
-- setAt root dest b = modifyAt root dest (const b)
--
-- deleteAt :: Monad m => Branch m -> Path -> m (Branch m)
-- deleteAt root path = modifyAt root path $ const empty
--
-- getAt :: Monad m
--       => Loader m
--       -> Branch m
--       -> Path
--       -> m (Maybe (Branch m))
-- -- todo: return Nothing if exists but is empty
-- getAt load root path = case Path.toList path of
--   [] -> pure $ Just root
--   seg : path -> case Map.lookup seg (_children $ head root) of
--     Nothing -> pure Nothing
--     Just h -> do
--       root <- load h
--       case root of
--         Nothing -> pure Nothing
--         Just root -> getAt load root (Path path)
-- -- todo: can we simplify the above?
-- -- e.g.     for (Map.lookup seg (_children $ head root)) $ \h ->
-- --            for (load h) $ \root -> getAt load root (Path path)
--
--
--
-- empty :: Branch m
-- empty = Branch $ Causal.one empty0
--
-- empty0 :: Branch0
-- empty0 = Branch0 mempty mempty mempty
--
-- isEmpty :: Branch0 -> Bool
-- isEmpty = (== empty0)
--
-- -- Modify the branch0 at the head of at `path` with `f`,
-- -- after creating it if necessary.  Preserves history.
-- stepAt :: Monad m
--        => Branch m
--        -> Path
--        -> (Branch0 -> Branch0)
--        -> m (Branch m)
-- stepAt b path f = stepAtM b path (pure . f)
--
-- -- Modify the branch0 at the head of at `path` with `f`,
-- -- after creating it if necessary.  Preserves history.
-- stepAtM
--   :: Monad m => Branch m -> Path -> (Branch0 -> m Branch0) -> m (Branch m)
-- stepAtM b path f =
--   modifyAtM b path (fmap Branch . Causal.stepM f . view history)
--
-- -- Modify the Branch at `path` with `f`, after creating it if necessary.
-- -- Because it's a `Branch`, it overwrites the history at `path`.
-- modifyAt :: Monad m
--   => Branch m -> Path -> (Branch m -> Branch m) -> m (Branch m)
-- modifyAt b path f = modifyAtM b path (pure . f)
--
-- -- Modify the Branch at `path` with `f`, after creating it if necessary.
-- -- Because it's a `Branch`, it overwrites the history at `path`.
-- modifyAtM
--   :: Monad m
--   => Loader m
--   -> Saver m
--   -> Branch m
--   -> Path
--   -> (Branch m -> m (Branch m))
--   -> m (Branch m)
-- modifyAtM load save b path f = case Path.toList path of
--   [] -> f b
--   seg : path ->
--     let recurse b@(Branch c) = do
--           b' <- modifyAtM load save b (Path path) f
--           let c' = flip Causal.step c . over children $ if isEmpty (head b')
--                 then Map.delete seg
--                 else Map.insert seg (headHash b', pure b')
--           pure (Branch c')
--     in  case Map.lookup seg (_children $ head b) of
--           Nothing      -> recurse empty
--           Just (_h, m) -> m >>= recurse
--
-- instance Hashable Branch0 where
--   tokens b =
--     [ H.accumulateToken . R.toList $ (_terms b)
--     , H.accumulateToken . R.toList $ (_types b)
--     , H.accumulateToken (fst <$> _children b)
--     ]

-- getLocalBranch :: Hash -> IO Branch
-- getGithubBranch :: RemotePath -> IO Branch
-- getLocalEdit :: GUID -> IO Edits

-- makeLenses ''Namespace
-- makeLenses ''Edits
-- makeLenses ''Causal
