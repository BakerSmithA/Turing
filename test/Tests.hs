module Main where

import Test.Hspec
import Syntax.ParserSpec

main :: IO ()
main = hspec specs where
    specs = do
        parserSpec
