module Semantics.ProgramSpec (programSpec) where

import Control.Monad.Identity
import Semantics.Program
import Syntax.Tree
import State.Config as Config
import TestHelper.Denotational
import TestHelper.Output
import Test.Hspec

-- Simulates a file structure, returning the contents of a file given the file
-- path.
-- testTree1 :: (Monad m) => ImportPath -> m ([ImportPath], Stm)
-- testTree1 "File1" = return (["File2", "File3"], PrintStr "1")
-- testTree1 "File2" = return (["File4"], PrintStr "2")
-- testTree1 "File3" = return ([], PrintStr "3")
-- testTree1 "File4" = return ([], PrintStr "4")
-- testTree1 _       = error "No file"
--
-- -- Simulates a file structure, returning the contents of a file given the file
-- -- path. The first file overwrites the definition of a variable.
-- testTree2 :: (Monad m) => ImportPath -> m ([ImportPath], Stm)
-- testTree2 "File1" = return (["File2"], VarDecl "x" (Literal '1'))
-- testTree2 "File2" = return ([], VarDecl "x" (Literal '2'))
-- testTree2 _       = error "No file"

programSpec :: Spec
programSpec = undefined

-- programSpec :: Spec
-- programSpec = do
--     importStmsSpec
--     evalProgSpec
--
-- evalProgSpec :: Spec
-- evalProgSpec = do
--     describe "evalProg" $ do
--         it "evalutes a program" $ do
--             let testConfig = Config.fromString "tape" "abc"
--                 tree = testTree2 :: ImportPath -> IO ([ImportPath], Stm)
--                 prog = Program [] Reject
--             shouldReject $ evalProgram tree prog testConfig
--
--         it "defaults to accepting" $ do
--             let testConfig = Config.fromString "tape" "abc"
--                 tree = testTree2 :: ImportPath -> IO ([ImportPath], Stm)
--                 prog = Program [] (MoveLeft "tape")
--             shouldAccept $ evalProgram tree prog testConfig
--
--         it "works with no imports" $ do
--             let testConfig = Config.fromString "tape" "a"
--                 tree = testTree1 :: ImportPath -> TestM ([ImportPath], Stm)
--                 prog = Program [] (Comp (Write "tape" (Literal '1')) (PrintRead "tape"))
--                 result = evalProgram tree prog testConfig
--             result `shouldOutput` ["1"]
--
--         -- Files 1 and Files 2 both define a constant "x", with the value '1'
--         -- and '2' respectively.
--         it "imports files in correct order" $ do
--             let testConfig = Config.fromString "tape" "a"
--                 tree = testTree2 :: ImportPath -> TestM ([ImportPath], Stm)
--                 prog = Program ["File1"] (Comp (Write "tape" (Var "x")) (PrintRead "tape"))
--                 result = evalProgram tree prog testConfig
--             result `shouldOutput` ["1"]
--
--         it "prints" $ do
--             let testConfig = Config.fromString "tape" "a"
--                 tree = testTree1 :: ImportPath -> TestM ([ImportPath], Stm)
--                 prog = Program [] (PrintRead "tape")
--                 result = evalProgram tree prog testConfig
--             result `shouldOutput` ["a"]
