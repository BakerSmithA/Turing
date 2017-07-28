module Semantics.Stm (evalStm) where

import Control.Exception
import Data.Maybe (maybeToList)
import Semantics.Bexp
import Semantics.DerivedSymbol
import Semantics.Helpers
import State.App
import State.Config
import State.Error
import State.MachineClass
import State.Output
import Syntax.Tree

-- Evaluates moving the read-write head one cell to the left.
evalLeft :: (MonadOutput m) => Config -> App m Config
evalLeft = return . left

-- Evaluates moving the read-write head one cell to the right.
evalRight :: (MonadOutput m) => Config -> App m Config
evalRight = return . right

-- Evaluates writing to the tape.
evalWrite :: (MonadOutput m) => DerivedSymbol -> Config -> App m Config
evalWrite sym config = do
    val <- derivedSymbolVal sym config
    return (setCurr val config)

-- Evaluates an if-else statement.
evalIf :: (MonadOutput m) => Bexp -> Stm -> [(Bexp, Stm)] -> Maybe Stm -> Config -> App m Config
evalIf bexp ifStm elseIfClauses elseStm = cond branches where
    branches   = map (\(b, stm) -> (bexpVal b, block (evalStm stm))) allClauses
    allClauses = ((bexp, ifStm):elseIfClauses) ++ (maybeToList elseClause)
    elseClause = fmap (\stm -> (TRUE, stm)) elseStm

-- Evaluates a while loop.
evalWhile :: (MonadOutput m) => Bexp -> Stm -> Config -> App m Config
evalWhile b body = fix f where
    f loop = cond [(bexpVal b, evalLoop)] where
        evalLoop c = block (evalStm body) c >>= loop

-- Evaluates a variable declaration.
evalVarDecl :: (MonadOutput m) => VarName -> DerivedSymbol -> Config -> App m Config
evalVarDecl name sym config = do
    val <- derivedSymbolVal sym config
    return (addVar name val config)

-- Evaluates a function declaration.
evalFuncDecl :: (MonadOutput m) => FuncName -> FuncDeclArgs -> Stm -> Config -> App m Config
evalFuncDecl name args body config = return (addFunc name args body config)

-- Checks that the number of arguments to a function is the same as the number
-- of arguments the function declaration specified.
checkNumArgs :: (MonadOutput m) => FuncName -> FuncDeclArgs -> FuncCallArgs -> Config -> App m Config
checkNumArgs name ds cs config | (length ds) == (length cs) = return config
                               | otherwise = throw err where
                                   err = WrongNumArgs name ds cs

-- Evaluates the body of a function, after adding any arguments to the variable
-- environment. The variable and function environments are reset after executing
-- the body.
evalFuncBody :: (MonadOutput m) => FuncName -> FuncDeclArgs -> FuncCallArgs -> Stm -> Config -> App m Config
evalFuncBody name ds cs body config = do
    -- Check the number of arguments to the function is the correct.
    let app = checkNumArgs name ds cs config
    let zippedArgs = zip ds cs
    let f (name', sym) app' = evalVarDecl name' sym =<< app'
    -- A config where the arguments have been added to the environment.
    addedVarsConfig <- foldr f app zippedArgs
    block (evalStm body) addedVarsConfig

-- Evaluates a function call.
evalCall :: (MonadOutput m) => FuncName -> FuncCallArgs -> Config -> App m Config
evalCall name args config = do
    let fMaybe = lookupFunc name config
    maybe err eval fMaybe where
        err                   = throw (UndefFunc name)
        eval (argNames, body) = evalFuncBody name argNames args body config

-- Evaluates the composition of two statements.
evalComp :: (MonadOutput m) => Stm -> Stm -> Config -> App m Config
evalComp stm1 stm2 config = (evalStm stm1 config) >>= (evalStm stm2)

-- Evaluates printing the current symbol.
evalPrintRead :: (MonadOutput m) => Config -> App m Config
evalPrintRead config = output' [(getCurr config)] config

-- Evaluates printing a string.
evalPrintStr :: (MonadOutput m) => String -> Config -> App m Config
evalPrintStr = output'

-- Evalautes a statement in a configuration of a Turing machine.
evalStm :: (MonadOutput m) => Stm -> Config -> App m Config
evalStm (MoveLeft)                = evalLeft
evalStm (MoveRight)               = evalRight
evalStm (Write sym)               = evalWrite sym
evalStm (Accept)                  = const accept
evalStm (Reject)                  = const reject
evalStm (If b stm elseIf elseStm) = evalIf b stm elseIf elseStm
evalStm (While b stm)             = evalWhile b stm
evalStm (VarDecl name sym)        = evalVarDecl name sym
evalStm (FuncDecl name args body) = evalFuncDecl name args body
evalStm (Call name args)          = evalCall name args
evalStm (Comp stm1 stm2)          = evalComp stm1 stm2
evalStm (PrintRead)               = evalPrintRead
evalStm (PrintStr str)            = evalPrintStr str
