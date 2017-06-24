module TestHelper.Denotational where

import Control.Monad.Reader
import State.Tape
import Syntax.Tree
import State.Config as Config
import State.Env as Env
import State.Error
import State.Machine
import State.Program
import Semantics.Denotational
import Test.Hspec hiding (shouldContain, shouldSatify, shouldThrow)
import Test.HUnit.Lang
import TestHelper.Tape

type ProgResult a     = IO (Either RuntimeError (Machine a))
type ProgResultConfig = ProgResult Config

-- Runs `derivedSymbolVal` with `sym` in the given config and environment.
evalDerivedSymbol :: DerivedSymbol -> Config -> Env -> ProgResult TapeSymbol
evalDerivedSymbol sym config = runProgram (derivedSymbolVal sym (return config))

-- Runs `bexpVal` with `b` in the given config and environment.
evalBexp :: Bexp -> Config -> Env -> ProgResult Bool
evalBexp b config = runProgram (bexpVal b (return config))

-- Runs `s` in config with the empty environment.
evalSemantics :: Stm -> Config -> ProgResultConfig
evalSemantics s config = runProgram (evalStm s (return config)) Env.empty

-- Asserts that a runtime error was thrown.
shouldThrow :: (Show a) => ProgResult a -> RuntimeError -> Expectation
shouldThrow r expected = do
    x <- r
    case x of
        Left err   -> err `shouldBe` expected
        Right mach -> assertFailure ("Expected err, got machine: " ++ (show mach))

-- Asserts that when the semantics have finished being evaulated, the resulting
-- machine satisfies the given predicate.
machShouldSatify :: (Eq a, Show a) => ProgResult a -> (Machine a -> Bool) -> Expectation
machShouldSatify r predicate = do
     x <- r
     case x of
         Left  err  -> assertFailure ("Expected machine, got error: " ++ (show err))
         Right mach -> mach `shouldSatisfy` predicate

-- Asserts that when the semantics have finished being evaulated, the value
-- wrapped in the machine satisfies the predicate.
shouldSatify :: (Eq a, Show a) => ProgResult a -> (a -> Bool) -> Expectation
shouldSatify r predicate = machShouldSatify r f where
    f = machine False False predicate

-- Asserts that when the semantics have finished being evaulated, the machine
-- contains the given value.
shouldContain :: (Eq a, Show a) => ProgResult a -> a -> Expectation
shouldContain r sym = shouldSatify r (== sym)

-- Asserts that when the semantics have finished being evauluated, the position
-- of the read-write head is in the given position.
shouldBeAt :: ProgResultConfig -> Pos -> Expectation
shouldBeAt r p = shouldSatify r predicate where
    predicate c = pos c == p
    predicate _ = False

-- Asserts that the tape has the string `str` at the start of the tape.
shouldRead :: ProgResultConfig -> [TapeSymbol] -> Expectation
shouldRead r syms = shouldSatify r predicate where
    predicate c = tapeShouldRead (tape c) syms
    predicate _ = False

-- Asserts that the machine halted in the accepting state.
shouldAccept :: ProgResultConfig -> Expectation
shouldAccept r = machShouldSatify r (== HaltA)

-- Asserts that the machine halted in the rejecting state.
shouldReject :: ProgResultConfig -> Expectation
shouldReject r = machShouldSatify r (== HaltR)