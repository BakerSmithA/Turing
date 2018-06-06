module Semantics.Stm (evalStm) where

import Control.Exception
import Data.Maybe (maybeToList)
import Semantics.Bexp
import Semantics.DerivedValue
import Semantics.Helpers
import State.App
import State.Config
import State.Error
import State.MachineClass
import State.Output
import State.Tape as Tape
import Syntax.Tree

-- Attempt to modify the tape, and throw if the tape does not exist.
modify :: (Monad m) => (Tape -> Tape) -> VarName -> Config -> App m Config
modify f tapeName c = tryMaybe (modifyTape tapeName f c) (UndefTape tapeName)

-- Evaluates moving the read-write head one cell to the left.
evalLeft :: (Monad m) => VarName -> Config -> App m Config
evalLeft = modify left

-- Evaluates moving the read-write head one cell to the right.
evalRight :: (Monad m) => VarName -> Config -> App m Config
evalRight = modify right

-- Evaluates writing to the tape.
evalWrite :: (Monad m) => VarName -> DerivedValue -> Config -> App m Config
evalWrite tapeName sym c = do
    val <- derivedVal sym c
    modify (setSym val) tapeName c

-- Evalutes writing a string to the tape. This is the same as individually
-- writing many symbols to the tape, and moving right in between writes.
evalWriteStr :: (Monad m) => VarName -> [TapeSymbol] -> Config -> App m Config
evalWriteStr _        []       config = return config
evalWriteStr tapeName [s]      config = evalWrite tapeName (Literal s) config
evalWriteStr tapeName (s:rest) config = do
    c'  <- evalWrite tapeName (Literal s) config
    c'' <- evalRight tapeName c'
    evalWriteStr tapeName rest c''

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
evalVarDecl :: (Monad m) => VarName -> DerivedValue -> Config -> App m Config
evalVarDecl name sym config = do
    val <- derivedVal sym config
    return (putSym name val config)

-- Evalutes a tape declaration.
evalTapeDecl :: (Monad m) => VarName -> String -> Config -> App m Config
evalTapeDecl name cs config = return (newTape name tape config) where
    tape = Tape.fromString cs

-- Evaluates a function declaration.
evalFuncDecl :: (Monad m) => FuncName -> FuncDeclArgs -> Stm -> Config -> App m Config
evalFuncDecl name args body config = return (putFunc name args body config)

-- Checks that the number of arguments to a function is the same as the number
-- of arguments the function declaration specified.
checkNumArgs :: (Monad m) => FuncName -> FuncDeclArgs -> FuncCallArgs -> Config -> App m Config
checkNumArgs name ds cs config | (length ds) == (length cs) = return config
                               | otherwise = throw err where
                                   err = WrongNumArgs name ds cs

-- Binds function arguments to values supplied to the function.
bindFuncArg :: (Monad m) => FuncName -> (FuncDeclArg, FuncCallArg) -> App m Config -> App m Config
bindFuncArg _ ((FuncDeclArg name    SymType),  Derived sym)            app = app >>= evalVarDecl name sym
bindFuncArg _ ((FuncDeclArg newName TapeType), Derived (Var tapeName)) app = do
    config <- app
    tryMaybe (putTapeRef newName tapeName config) (UndefTape tapeName)
bindFuncArg _ ((FuncDeclArg name TapeType), TapeLiteral cs) app = do
    config <- app
    return $ newTape name (Tape.fromString cs) config
bindFuncArg fName ((FuncDeclArg name dataType), arg) _ = throw (MismatchedTypes name fName dataType arg)

-- Evaluates the body of a function, after adding any arguments to the variable
-- environment. The variable and function environments are reset after executing
-- the body.
evalFuncBody :: (MonadOutput m) => FuncName -> FuncDeclArgs -> FuncCallArgs -> Stm -> Config -> App m Config
evalFuncBody name ds cs body config = do
    -- Check the number of arguments to the function is the correct.
    let app = checkNumArgs name ds cs config
    let zippedArgs = zip ds cs
    -- A config where the arguments have been added to the environment.
    addedVarsConfig <- foldr (bindFuncArg name) app zippedArgs
    newConfig <- block (evalStm body) addedVarsConfig
    oldConfig <- app
    -- Reset the environment so variables declared as function arguments do not
    -- 'leak' out.
    return (revertEnv oldConfig newConfig)

-- Evaluates a function call.
evalCall :: (MonadOutput m) => FuncName -> FuncCallArgs -> Config -> App m Config
evalCall name args config = do
    let fMaybe = getFunc name config
    maybe err eval fMaybe where
        err                   = throw (UndefFunc name)
        eval (argNames, body) = evalFuncBody name argNames args body config

-- Evaluates the composition of two statements.
evalComp :: (MonadOutput m) => Stm -> Stm -> Config -> App m Config
evalComp stm1 stm2 config = (evalStm stm1 config) >>= (evalStm stm2)

-- Evaluates printing the current symbol.
evalPrintRead :: (MonadOutput m) => VarName -> Config -> App m Config
evalPrintRead tapeName c = do
    sym <- derivedVal (Read tapeName) c
    output' [sym] c

-- Evaluates printing a string.
evalPrintStr :: (MonadOutput m) => String -> Config -> App m Config
evalPrintStr = output'

-- Evalutes debug printing the contents of a tape.
evalDebugPrintTape :: (MonadOutput m) => VarName -> Config -> App m Config
evalDebugPrintTape name c = do
    tape <- tryMaybe (getTape name c) (UndefTape name)
    c' <- output' (toString tape) c
    return c'

-- Evalautes a statement in a configuration of a Turing machine.
evalStm :: (MonadOutput m) => Stm -> Config -> App m Config
evalStm (MoveLeft tapeName)       = evalLeft tapeName
evalStm (MoveRight tapeName)      = evalRight tapeName
evalStm (Write tapeName sym)      = evalWrite tapeName sym
evalStm (WriteStr tapeName str)   = evalWriteStr tapeName str
evalStm (Accept)                  = const accept
evalStm (Reject)                  = const reject
evalStm (If b stm elseIf elseStm) = evalIf b stm elseIf elseStm
evalStm (While b stm)             = evalWhile b stm
evalStm (VarDecl name sym)        = evalVarDecl name sym
evalStm (TapeDecl name cs)        = evalTapeDecl name cs
evalStm (FuncDecl name args body) = evalFuncDecl name args body
evalStm (Call name args)          = evalCall name args
evalStm (Comp stm1 stm2)          = evalComp stm1 stm2
evalStm (PrintRead tapeName)      = evalPrintRead tapeName
evalStm (PrintStr str)            = evalPrintStr str
evalStm (DebugPrintTape tapeName) = evalDebugPrintTape tapeName
