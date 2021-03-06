module Unison.NamePrinter where

import Unison.Prelude

import qualified Unison.HashQualified as HQ
import qualified Unison.HashQualified' as HQ'
import           Unison.Name          (Name)
import qualified Unison.Name          as Name
import           Unison.Reference     (Reference)
import           Unison.Referent      (Referent)
import           Unison.ShortHash     (ShortHash)
import qualified Unison.ShortHash     as SH
import           Unison.Util.SyntaxText (SyntaxText)
import qualified Unison.Util.SyntaxText as S
import           Unison.Util.Pretty   (Pretty)
import qualified Unison.Util.Pretty   as PP

prettyName :: IsString s => Name -> Pretty s
prettyName = PP.text . Name.toText

prettyHashQualified :: HQ.HashQualified -> Pretty SyntaxText
prettyHashQualified = styleHashQualified' id (fmt S.HashQualifier)

prettyHashQualified' :: HQ'.HashQualified -> Pretty SyntaxText
prettyHashQualified' = prettyHashQualified . HQ'.toHQ

prettyHashQualified0 :: IsString s => HQ.HashQualified -> Pretty s
prettyHashQualified0 = PP.text . HQ.toText

-- | Pretty-print a reference as a name and the given number of characters of
-- its hash.
prettyNamedReference :: Int -> Name -> Reference -> Pretty SyntaxText
prettyNamedReference len name =
  prettyHashQualified . HQ.take len . HQ.fromNamedReference name

-- | Pretty-print a referent as a name and the given number of characters of its
-- hash.
prettyNamedReferent :: Int -> Name -> Referent -> Pretty SyntaxText
prettyNamedReferent len name =
  prettyHashQualified . HQ.take len . HQ.fromNamedReferent name

-- | Pretty-print a reference as the given number of characters of its hash.
prettyReference :: Int -> Reference -> Pretty SyntaxText
prettyReference len =
  prettyHashQualified . HQ.take len . HQ.fromReference

-- | Pretty-print a referent as the given number of characters of its hash.
prettyReferent :: Int -> Referent -> Pretty SyntaxText
prettyReferent len =
  prettyHashQualified . HQ.take len . HQ.fromReferent

prettyShortHash :: IsString s => ShortHash -> Pretty s
prettyShortHash = fromString . SH.toString

styleHashQualified ::
  IsString s => (Pretty s -> Pretty s) -> HQ.HashQualified -> Pretty s
styleHashQualified style hq = styleHashQualified' style id hq

styleHashQualified' ::
  IsString s => (Pretty s -> Pretty s)
             -> (Pretty s -> Pretty s)
             -> HQ.HashQualified
             -> Pretty s
styleHashQualified' nameStyle hashStyle = \case
  HQ.NameOnly n -> nameStyle (prettyName n)
  HQ.HashOnly h -> hashStyle (prettyShortHash h)
  HQ.HashQualified n h ->
    PP.group $ nameStyle (prettyName n) <> hashStyle (prettyShortHash h)

styleHashQualified'' :: (Pretty SyntaxText -> Pretty SyntaxText)
                     -> HQ.HashQualified
                     -> Pretty SyntaxText
styleHashQualified'' nameStyle = styleHashQualified' nameStyle (fmt S.HashQualifier)

fmt :: S.Element -> Pretty S.SyntaxText -> Pretty S.SyntaxText
fmt = PP.withSyntax
