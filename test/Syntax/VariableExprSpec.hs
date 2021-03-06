module Syntax.VariableExprSpec (variableExprSpec) where

import Syntax.Tree
import Syntax.Env as Env
import Syntax.ParseState
import Syntax.VariableExpr
import Syntax.Parser
import Test.Hspec
import Test.Hspec.Megaparsec

variableExprSpec :: Spec
variableExprSpec = do
    refVarIdSpec
    tapeSymbolSpec
    symExprSpec
    tapeExprSpec
    objExprSpec
    anyValExprSpec

refVarIdSpec :: Spec
refVarIdSpec = do
    describe "refVarId" $ do
        it "parses existing variables" $ do
            let state = Env.fromList [("x", PVar SymType)]
            parseEvalState state refVarId "" "x" `shouldParse` (["x"], SymType)

        it "accesses variables inside structures" $ do
            let state = Env.fromList [("S", PStruct [("m_x", SymType)]), ("s", PVar (CustomType "S"))]
            parseEvalState state refVarId "" "s.m_x" `shouldParse` (["s", "m_x"], SymType)

        it "allows chaining" $ do
            let struct1 = ("S1", PStruct [("m_s", CustomType "S2")])
                struct2 = ("S2", PStruct [("m_x", TapeType)])
                var     = ("s", PVar (CustomType "S1"))
                state   = Env.fromList [struct1, struct2, var]
            parseEvalState state refVarId "" "s.m_s.m_x" `shouldParse` (["s", "m_s", "m_x"], TapeType)

        it "evaluates to the last access if intermediate types have the required type" $ do
            let struct = ("S", PStruct [("m_s", CustomType "S"), ("m_x", CustomType "S")])
                var    = ("s", PVar (CustomType "S"))
                state  = Env.fromList [struct, var]
            parseEvalState state refVarId "" "s.m_s.m_s.m_x" `shouldParse` (["s", "m_s", "m_s", "m_x"], CustomType "S")

        it "fails if any intermediate member in a chain is not a struct" $ do
            let struct1 = ("S1", PStruct [("m_s", TapeType)])
                struct2 = ("S2", PStruct [("m_x", SymType)])
                var     = ("s", PVar (CustomType "S1"))
                state   = Env.fromList [struct1, struct2, var]
            parseEvalState state refVarId "" "s.m_s.m_x" `shouldParse` (["s", "m_s"], TapeType)

        it "fails to parse if the variable has not been declared" $ do
            parseEmptyState refVarId "" `shouldFailOn` "x"

        it "fails to parse if the identifier does not evaluate to a variable" $ do
            let state = Env.fromList [("f", PFunc [SymType])]
            parseEvalState state refVarId "" `shouldFailOn` "f"

        it "fails if any of the variables are not members" $ do
            let struct1 = ("S1", PStruct [("m_s", TapeType)])
                struct2 = ("S2", PStruct [("m_t", SymType)])
                var1    = ("s1", PVar (CustomType "S1"))
                var2    = ("s2", PVar (CustomType "S1"))
                state   = Env.fromList [struct1, struct2, var1, var2]
            parseEvalState state refVarId "" "s1.s2" `shouldParse` (["s1"], CustomType "S1")

tapeSymbolSpec :: Spec
tapeSymbolSpec = do
    describe "tapeSymbol" $ do
        it "parses lowercase letters" $ do
            parseEmptyState tapeSymbol "" "a" `shouldParse` 'a'

        it "parses uppercase letters" $ do
            parseEmptyState tapeSymbol "" "A" `shouldParse` 'A'

        it "parses digits" $ do
            parseEmptyState tapeSymbol "" "1" `shouldParse` '1'

        it "parses a ASCII symbols" $ do
            parseEmptyState tapeSymbol "" "+" `shouldParse` '+'
            parseEmptyState tapeSymbol "" "#" `shouldParse` '#'
            parseEmptyState tapeSymbol "" "<" `shouldParse` '<'
            parseEmptyState tapeSymbol "" "{" `shouldParse` '{'

        it "does not parse single quotes" $ do
            parseEmptyState tapeSymbol "" `shouldFailOn` "\'"

symExprSpec :: Spec
symExprSpec = do
    describe "symExpr" $ do
        it "parses reading a tape variable" $ do
            let expected = Read (TapeVar ["t"])
                state = Env.fromList [("t", PVar TapeType)]
            parseEvalState state symExpr "" "read t" `shouldParse` expected

        it "parses reading a tape literal" $ do
            let expected = Read (TapeLit "abc")
            parseEmptyState symExpr "" "read \"abc\"" `shouldParse` expected

        it "parses sym variables" $ do
            let expected = SymVar ["x"]
                state = Env.fromList [("x", PVar SymType)]
            parseEvalState state symExpr "" "x" `shouldParse` expected

        it "parses variables in structs" $ do
            let expected = SymVar ["x", "m_s"]
                state = Env.fromList [("S", PStruct [("m_s", SymType)]), ("x", PVar (CustomType "S"))]
            parseEvalState state symExpr "" "x.m_s" `shouldParse` expected

        it "fails if the variable is not a symbol" $ do
            let state = Env.fromList [("t", PVar TapeType)]
            parseEvalState state symExpr "" `shouldFailOn` "t"

        it "fails if the variable is a function" $ do
            let state = Env.fromList [("f", PFunc [])]
            parseEvalState state symExpr "" `shouldFailOn` "f"

tapeExprSpec :: Spec
tapeExprSpec = do
    describe "tapeExpr" $ do
        it "parses tape literals" $ do
            let expected = TapeLit "abc"
            parseEmptyState tapeExpr "" "\"abc\"" `shouldParse` expected

        it "parses tape variables" $ do
            let expected = TapeVar ["t"]
                state = Env.fromList [("t", PVar TapeType)]
            parseEvalState state tapeExpr "" "t" `shouldParse` expected

        it "parses variables in structs" $ do
            let expected = TapeVar ["x", "m_t"]
                state = Env.fromList [("S", PStruct [("m_t", TapeType)]), ("x", PVar (CustomType "S"))]
            parseEvalState state tapeExpr "" "x.m_t" `shouldParse` expected

        it "fails if the variable is not a tape" $ do
            let state = Env.fromList [("x", PVar SymType)]
            parseEvalState state tapeExpr "" `shouldFailOn` "x"

        it "fails reading if the variable is a function" $ do
            let state = Env.fromList [("f", PFunc [])]
            parseEvalState state tapeExpr "" `shouldFailOn` "f"

objExprSpec :: Spec
objExprSpec = do
    describe "objExpr" $ do
        it "parses new objects" $ do
            let expected = NewObj "S" [(S (SymLit 'a')), (T (TapeLit "abc"))]
                state = Env.fromList [("S", PStruct [("x", SymType), ("y", TapeType)]), ("tape", PVar TapeType)]
            parseEvalState state objExpr "" "S 'a' \"abc\"" `shouldParse` expected

        it "parses object variables" $ do
            let expected = ObjVar "S" ["obj"]
                state = Env.fromList [("obj", PVar (CustomType "S"))]
            parseEvalState state objExpr "" "obj" `shouldParse` expected

        it "parses variables in structs" $ do
            let expected = ObjVar "S" ["x", "m_o"]
                state = Env.fromList [("S", PStruct [("m_o", CustomType "S")]), ("x", PVar (CustomType "S"))]
            parseEvalState state objExpr "" "x.m_o" `shouldParse` expected

        it "parses new objects where arguments have parenthesis" $ do
            let expected = NewObj "S" [(S (Read (TapeVar ["tape"])))]
                state = Env.fromList [("S", PStruct [("x", SymType)]), ("tape", PVar TapeType)]
            parseEvalState state objExpr "" "S (read tape)" `shouldParse` expected

        it "fails if the incorrect number of arguments are given to a constructor" $ do
            let state = Env.fromList [("S", PStruct [("x", SymType), ("y", SymType)])]
            parseEvalState state objExpr "" `shouldFailOn` "S 'a'"
            parseEvalState state objExpr "" `shouldFailOn` "S 'a' \"abc\" \"abc\""

        it "fails if the incorrect type is given as an argument" $ do
            let state = Env.fromList [("S", PStruct [("x", SymType)]), ("tape", PVar TapeType)]
            parseEvalState state objExpr "" `shouldFailOn` "S tape"

        it "fails if the variable is not an object" $ do
            let state = Env.fromList [("x", PVar TapeType)]
            parseEvalState state objExpr "" `shouldFailOn` "x"

anyValExprSpec :: Spec
anyValExprSpec = do
    describe "anyValExprSpec" $ do
        let state = Env.fromList [("x", PVar SymType), ("y", PVar TapeType), ("z", PVar (CustomType "S"))]

        it "parses symbols" $ do
            let expected = S (SymVar ["x"])
            parseEvalState state anyValExpr "" "x" `shouldParse` expected

        it "parses tapes" $ do
            let expected = T (TapeVar ["y"])
            parseEvalState state anyValExpr "" "y" `shouldParse` expected

        it "parses objects" $ do
            let expected = C (ObjVar "S" ["z"])
            parseEvalState state anyValExpr "" "z" `shouldParse` expected
