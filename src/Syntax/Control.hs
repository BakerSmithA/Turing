module Syntax.Control where

import Syntax.Common
import Syntax.Bexp

-- Parses if-else statement, the EBNF syntax of which is:
--  If     : 'if' { Stm } ElseIf
--  ElseIf : 'else if' { Stm } ElseIf | Else
--  Else   : 'else' { Stm } | ε
ifStm :: ParserM Stm -> ParserM Stm
ifStm stm = If <$ lTok "if" <*> bexp <*> block (braces stm) <*> many elseIfClause <*> elseClause where
    elseIfClause = do
        bool <- lTok "else if" *> bexp
        statement <- block (braces stm)
        return (bool, statement)
    elseClause = optional (lTok "else" *> block (braces stm))

whileStm :: ParserM Stm -> ParserM Stm
whileStm stm = While <$ lTok "while" <*> bexp <*> block (braces stm)
