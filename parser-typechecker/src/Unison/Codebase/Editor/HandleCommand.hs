{-# OPTIONS_GHC -Wno-partial-type-signatures #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}
-- {-# OPTIONS_GHC -Wno-unused-matches #-}

-- {-# LANGUAGE DeriveAnyClass,StandaloneDeriving #-}
-- {-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE RecordWildCards #-}
-- {-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
-- {-# LANGUAGE TupleSections #-}
{-# LANGUAGE ViewPatterns #-}

module Unison.Codebase.Editor.HandleCommand where

import Unison.Codebase.Editor.Output
import Unison.Codebase.Editor.Command
import Unison.Codebase.Editor.RemoteRepo

import qualified Unison.Codebase.Branch2       as Branch
import qualified Unison.Builtin2               as B
import           Unison.Symbol                  ( Symbol )

-- import Debug.Trace

import           Control.Monad.Except           ( runExceptT )
import           Data.Functor                   ( void )
import           Data.Foldable                  ( traverse_ )
import qualified Data.Map                      as Map
import           Data.Text                      ( Text )
import qualified Data.Text                     as Text
import           System.Directory               ( getXdgDirectory
                                                , XdgDirectory(..)
                                                )
import           System.FilePath                ( (</>) )

import           Unison.Codebase2               ( Codebase, Decl )
import qualified Unison.Codebase2              as Codebase
import           Unison.Codebase.Branch2        ( Branch
                                                , Branch0
                                                )
import qualified Unison.Codebase.BranchUtil    as BranchUtil
import qualified Unison.Codebase.Editor.Git    as Git
import qualified Unison.Codebase.Path          as Path
import qualified Unison.Codebase.SearchResult  as SR
import qualified Unison.Names                  as OldNames
import           Unison.Parser                  ( Ann )
import qualified Unison.Parser                 as Parser
import qualified Unison.Reference              as Reference
import qualified Unison.Referent               as Referent
import qualified Unison.Runtime.IOSource       as IOSource
import qualified Unison.Codebase.Runtime       as Runtime
import           Unison.Codebase.Runtime       (Runtime)
import qualified Unison.Type                   as Type
import qualified Unison.UnisonFile             as UF
import           Unison.Util.Free               ( Free )
import qualified Unison.Util.Free              as Free
import           Unison.Var                     ( Var )
import qualified Unison.Result as Result
import           Unison.FileParsers             ( parseAndSynthesizeFile )

typecheck
  :: (Monad m, Var v)
  => [Type.AnnotatedType v Ann]
  -> Codebase m v Ann
  -> Parser.ParsingEnv
  -> SourceName
  -> Text
  -> m (TypecheckingResult v)
typecheck ambient codebase names sourceName src =
  Result.getResult $ parseAndSynthesizeFile ambient
    (((<> B.typeLookup) <$>) . Codebase.typeLookupForDependencies codebase)
    names
    (Text.unpack sourceName)
    src

commandLine
  :: forall i v a
   . Var v
  => IO i
  -> (Branch IO -> IO ())
  -> Runtime v
  -> (Output v -> IO ())
  -> Codebase IO v Ann
  -> Free (Command IO i v) a
  -> IO a
commandLine awaitInput setBranchRef rt notifyUser codebase command =
 Free.fold go command
 where
  go :: forall x . Command IO i v x -> IO x
  go = \case
    -- Wait until we get either user input or a unison file update
    Eval m        -> m
    Input         -> awaitInput
    Notify output -> notifyUser output
    --    AddDefsToCodebase handler branch unisonFile -> error "todo"
    --      fileToBranch handler codebase branch unisonFile
    Typecheck ambient names sourceName source -> do
      -- todo: if guids are being shown to users,
      -- not ideal to generate new guid every time
      namegen <- Parser.uniqueBase58Namegen
      typecheck ambient
                codebase
                (namegen, OldNames.fromNames2 names)
                sourceName
                source
    Evaluate unisonFile        -> evalUnisonFile unisonFile
    LoadLocalRootBranch        -> Codebase.getRootBranch codebase
    SyncLocalRootBranch branch -> do
      setBranchRef branch
      Codebase.putRootBranch codebase branch
    LoadRemoteRootBranch Github {..} -> do
      tmp <- getXdgDirectory XdgCache $ "unisonlanguage" </> "gitfiles"
      runExceptT $ Git.pullGithubRootBranch tmp codebase username repo commit
    SyncRemoteRootBranch Github {..} _branch -> error "todo"
    RetrieveHashes Github {..} _types _terms -> error "todo"
    LoadTerm r -> Codebase.getTerm codebase r
    LoadType r -> Codebase.getTypeDeclaration codebase r
    LoadTypeOfTerm r -> Codebase.getTypeOfTerm codebase r
    GetDependents r -> Codebase.dependents codebase r
    AddDefsToCodebase _unisonFile -> error "todo"

--    Todo b -> doTodo codebase (Branch.head b)
--    Propagate b -> do
--      b0 <- Codebase.propagate codebase (Branch.head b)
--      pure $ Branch.append b0 b
    Execute uf -> void $ evalUnisonFile uf
  evalUnisonFile :: UF.TypecheckedUnisonFile v Ann -> _
  evalUnisonFile (UF.discardTypes -> unisonFile) = do
    let codeLookup = Codebase.toCodeLookup codebase
    selfContained <- Codebase.makeSelfContained' codeLookup unisonFile
    let noCache = const (pure Nothing)
    Runtime.evaluateWatches codeLookup noCache rt selfContained

-- doTodo :: Monad m => Codebase m v a -> Branch0 -> m (TodoOutput v a)
-- doTodo code b = do
--   -- traceM $ "edited terms: " ++ show (Branch.editedTerms b)
--   f <- Codebase.frontier code b
--   let dirty = R.dom f
--       frontier = R.ran f
--       ppe = Branch.prettyPrintEnv b
--   (frontierTerms, frontierTypes) <- loadDefinitions code frontier
--   (dirtyTerms, dirtyTypes) <- loadDefinitions code dirty
--   -- todo: something more intelligent here?
--   scoreFn <- pure $ const 1
--   remainingTransitive <- Codebase.frontierTransitiveDependents code b frontier
--   let
--     addTermNames terms = [(PPE.termName ppe (Referent.Ref r), r, t) | (r,t) <- terms ]
--     addTypeNames types = [(PPE.typeName ppe r, r, d) | (r,d) <- types ]
--     frontierTermsNamed = addTermNames frontierTerms
--     frontierTypesNamed = addTypeNames frontierTypes
--     dirtyTermsNamed = sortOn (\(s,_,_,_) -> s) $
--       [ (scoreFn r, n, r, t) | (n,r,t) <- addTermNames dirtyTerms ]
--     dirtyTypesNamed = sortOn (\(s,_,_,_) -> s) $
--       [ (scoreFn r, n, r, t) | (n,r,t) <- addTypeNames dirtyTypes ]
--   pure $
--     TodoOutput_
--       (Set.size remainingTransitive)
--       (frontierTermsNamed, frontierTypesNamed)
--       (dirtyTermsNamed, dirtyTypesNamed)
--       (Branch.conflicts' b)

-- loadDefinitions :: Monad m => Codebase m v a -> Set Reference
--                 -> m ( [(Reference, Maybe (Type v a))],
--                        [(Reference, DisplayThing (Decl v a))] )
-- loadDefinitions code refs = do
--   termRefs <- filterM (Codebase.isTerm code) (toList refs)
--   terms <- forM termRefs $ \r -> (r,) <$> Codebase.getTypeOfTerm code r
--   typeRefs <- filterM (Codebase.isType code) (toList refs)
--   types <- forM typeRefs $ \r -> do
--     case r of
--       Reference.Builtin _ -> pure (r, BuiltinThing)
--       Reference.DerivedId id -> do
--         decl <- Codebase.getTypeDeclaration code id
--         case decl of
--           Nothing -> pure (r, MissingThing id)
--           Just d -> pure (r, RegularThing d)
--   pure (terms, types)
--
-- -- | Write all of the builtins into the codebase
-- initializeCodebase :: forall m . Monad m => Codebase m Symbol Ann -> m ()
-- initializeCodebase c = do
--   traverse_ (go Right) B.builtinDataDecls
--   traverse_ (go Left)  B.builtinEffectDecls
--   void $ fileToBranch updateCollisionHandler c mempty IOSource.typecheckedFile
--  where
--   go :: (t -> Decl Symbol Ann) -> (a, (Reference.Reference, t)) -> m ()
--   go f (_, (ref, decl)) = case ref of
--     Reference.DerivedId id -> Codebase.putTypeDeclaration c id (f decl)
--     _                      -> pure ()
--
-- -- todo: probably don't use this anywhere
-- nameDistance :: Name -> Name -> Maybe Int
-- nameDistance (Name.toString -> q) (Name.toString -> n) =
--   if q == n                              then Just 0-- exact match is top choice
--   else if map toLower q == map toLower n then Just 1-- ignore case
--   else if q `isSuffixOf` n               then Just 2-- matching suffix is p.good
--   else if q `isPrefixOf` n               then Just 3-- matching prefix
--   else Nothing