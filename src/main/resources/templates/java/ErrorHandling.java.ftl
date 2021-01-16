[#ftl strict_vars=true]
[#--
/* Copyright (c) 2020 Jonathan Revusky, revusky@javacc.com
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright notices,
 *       this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name Jonathan Revusky, Sun Microsystems, Inc.
 *       nor the names of any contributors may be used to endorse 
 *       or promote products derived from this software without specific prior written 
 *       permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */
 --]
 [#if grammar.debugParser]
  private boolean trace_enabled = true;
 [#else]
  private boolean trace_enabled = false;
 [/#if]
 
  public void setTracingEnabled(boolean tracingEnabled) {trace_enabled = tracingEnabled;}
  
 /**
 * @deprecated Use #setTracingEnabled
 */
   @Deprecated
  public void enable_tracing() {
    setTracingEnabled(true);
  }

/**
 * @deprecated Use #setTracingEnabled
 */
@Deprecated
 public void disable_tracing() {
    setTracingEnabled(false);
  }
 
ArrayList<NonTerminalCall> parsingStack = new ArrayList<>();
private ArrayList<NonTerminalCall> lookaheadStack = new ArrayList<>();


private EnumSet<TokenType> currentFollowSet;

/**
 * Inner class that represents entering a grammar production
 */
class NonTerminalCall {
    final String sourceFile;
    final String productionName;
    final int line, column;

    // We actually only use this when we're working with the LookaheadStack
    final boolean stopAtScanLimit;

    NonTerminalCall(String sourceFile, String productionName, int line, int column) {
        this.sourceFile = sourceFile;
        this.productionName = productionName;
        this.line = line;
        this.column = column;
        this.stopAtScanLimit = ${grammar.parserClassName}.this.stopAtScanLimit;
    }

    StackTraceElement createStackTraceElement() {
        return new StackTraceElement("${grammar.parserClassName}", productionName, sourceFile, line);
    }

    void dump(PrintStream ps) {
        ps.println(productionName + ":" + line + ":" + column);
    }
}

private final void pushOntoCallStack(String methodName, String fileName, int line, int column) {
   parsingStack.add(new NonTerminalCall(fileName, methodName, line, column));
}

private final void popCallStack() {
    parsingStack.remove(parsingStack.size() -1);
}

private final void restoreCallStack(int prevSize) {
    while (parsingStack.size() > prevSize) {
       popCallStack();
    }
}

private ListIterator<NonTerminalCall> stackIteratorForward() {
    final ListIterator<NonTerminalCall> parseStackIterator = parsingStack.listIterator();
    final ListIterator<NonTerminalCall> lookaheadStackIterator = lookaheadStack.listIterator();
    return new ListIterator<NonTerminalCall>() {
        public boolean hasNext() {
            return parseStackIterator.hasNext() || lookaheadStackIterator.hasNext();
        }
        public NonTerminalCall next() {
            return parseStackIterator.hasNext() ? parseStackIterator.next() : lookaheadStackIterator.next();
        }
        public NonTerminalCall previous() {
           return lookaheadStackIterator.hasPrevious() ? lookaheadStackIterator.previous() : parseStackIterator.previous(); 
        }
        public boolean hasPrevious() {
            return lookaheadStackIterator.hasPrevious() || parseStackIterator.hasPrevious();
        }
        public void add(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void set(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void remove() {throw new UnsupportedOperationException();}
        public int previousIndex() {throw new UnsupportedOperationException();}
        public int nextIndex() {throw new UnsupportedOperationException();}
    };
}

private ListIterator<NonTerminalCall> stackIteratorBackward() {
    final ListIterator<NonTerminalCall> parseStackIterator = parsingStack.listIterator(parsingStack.size());
    final ListIterator<NonTerminalCall> lookaheadStackIterator = lookaheadStack.listIterator(lookaheadStack.size());
    return new ListIterator<NonTerminalCall>() {
        public boolean hasNext() {
            return parseStackIterator.hasPrevious() || lookaheadStackIterator.hasPrevious();
        }
        public NonTerminalCall next() {
            return lookaheadStackIterator.hasPrevious() ? lookaheadStackIterator.previous() : parseStackIterator.previous();
        }
        public NonTerminalCall previous() {
           return lookaheadStackIterator.hasNext() ? lookaheadStackIterator.next() : parseStackIterator.next();
        }
        public boolean hasPrevious() {
            return lookaheadStackIterator.hasNext() || parseStackIterator.hasNext();
        }
        public void add(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void set(NonTerminalCall ntc) {throw new UnsupportedOperationException();}
        public void remove() {throw new UnsupportedOperationException();}
        public int previousIndex() {throw new UnsupportedOperationException();}
        public int nextIndex() {throw new UnsupportedOperationException();}
    };
}


private final void pushOntoLookaheadStack(String methodName, String fileName, int line, int column) {
    lookaheadStack.add(new NonTerminalCall(fileName, methodName, line, column));
}

private final void popLookaheadStack() {
    NonTerminalCall ntc = lookaheadStack.remove(lookaheadStack.size() -1);
    this.stopAtScanLimit = ntc.stopAtScanLimit;
}

void dumpLookaheadStack(PrintStream ps) {
    ListIterator<NonTerminalCall> it = lookaheadStack.listIterator(lookaheadStack.size());
    while (it.hasPrevious()) {
        it.previous().dump(ps);
    }
}

void dumpCallStack(PrintStream ps) {
    ListIterator<NonTerminalCall> it = parsingStack.listIterator(parsingStack.size());
    while (it.hasPrevious()) {
        it.previous().dump(ps);
    }
}

void dumpLookaheadCallStack(PrintStream ps) {
    ps.println("Current Parser Production is: " + currentlyParsedProduction);
    ps.println("Current Lookahead Production is: " + currentLookaheadProduction);
    ps.println("---Lookahead Stack---");
    dumpLookaheadStack(ps);
    ps.println("---Call Stack---");
    dumpCallStack(ps);
}

[#if grammar.faultTolerant] 
    private boolean tolerantParsing = true;
[/#if]    

    public boolean isParserTolerant() {
       [#if grammar.faultTolerant] 
        return tolerantParsing;
       [#else]
        return false;
       [/#if]
    }
    
    public void setParserTolerant(boolean tolerantParsing) {
        [#if grammar.faultTolerant]
          this.tolerantParsing = tolerantParsing;
        [#else]
          if (tolerantParsing) {
            throw new UnsupportedOperationException("This parser was not built with that feature!");
          }
        [/#if]
    }

      private Token consumeToken(TokenType expectedType 
        [#if grammar.faultTolerant], boolean tolerant [/#if]
      ) throws ParseException {
        Token oldToken = lastConsumedToken;
        Token nextToken = nextToken(lastConsumedToken);
        if (nextToken.getType() != expectedType) {
            handleUnexpectedTokenType(expectedType, nextToken
            [#if grammar.faultTolerant], tolerant[/#if]
            ) ;
        }
        this.lastConsumedToken = nextToken;
        this.nextTokenType = null;
[#if grammar.treeBuildingEnabled]
      if (buildTree && tokensAreNodes) {
  [#if grammar.userDefinedLexer]
          lastConsumedToken.setInputSource(getInputSource());
  [/#if]
  [#list grammar.openNodeScopeHooks as hook]
     ${hook}(lastConsumedToken);
  [/#list]
          pushNode(lastConsumedToken);
  [#list grammar.closeNodeScopeHooks as hook]
     ${hook}(lastConsumedToken);
  [/#list]
      }
[/#if]
      if (trace_enabled) LOGGER.info("Consumed token of type " + lastConsumedToken.getType() + " from " + lastConsumedToken.getLocation());
      return lastConsumedToken;
  }
 
  private Token handleUnexpectedTokenType(TokenType expectedType, Token nextToken
      [#if grammar.faultTolerant], boolean tolerant[/#if]
      ) throws ParseException {
      [#if !grammar.faultTolerant]
       throw new ParseException(nextToken, EnumSet.of(expectedType), parsingStack);
      [#else]
       if (!tolerant || !this.tolerantParsing) {
          throw new ParseException(nextToken, EnumSet.of(expectedType), parsingStack);
       }
         Token nextNext = nextToken(nextToken);
         if (nextNext.getType() == expectedType) {
             [#--] REVISIT. Here we skip one token (as well as any InvalidToken) but maybe (probably!) this behavior
             should be configurable. But we need to experiment, because this is really a heuristic question, no?--]
             nextToken.setSkipped(true);
             return nextNext;
         } 
         [#-- Since skipping the next token did not work, we will insert a virtual token --]
            Token virtualToken = Token.newToken(expectedType, "VIRTUAL", lastConsumedToken);
            virtualToken.setVirtual(true);
//            nextToken.copyLocationInfo(virtualToken);
            virtualToken.copyLocationInfo(nextToken);
            virtualToken.setNext(nextToken);
            lastConsumedToken.setNext(virtualToken);
            return virtualToken;
      [/#if]
  }
  
 [#if !grammar.hugeFileSupport && !grammar.userDefinedLexer]
 
  private class ParseState {
       Token lastConsumed;
       ArrayList<NonTerminalCall> parsingStack;
  [#if grammar.treeBuildingEnabled]
       NodeScope nodeScope;
 [/#if]       
       ParseState() {
           this.lastConsumed = ${grammar.parserClassName}.this.lastConsumedToken;
           this.parsingStack = (ArrayList<NonTerminalCall>) ${grammar.parserClassName}.this.parsingStack.clone();
[#if grammar.treeBuildingEnabled]            
           this.nodeScope = (NodeScope) currentNodeScope.clone();
[/#if]           
       } 
  }

 private ArrayList<ParseState> parseStateStack = new ArrayList<>();
 
  private void stashParseState() {
      parseStateStack.add(new ParseState());
  }
  
  private ParseState popParseState() {
      return parseStateStack.remove(parseStateStack.size() -1);
  }
  
  private void restoreStashedParseState() {
     ParseState state = popParseState();
[#if grammar.treeBuildingEnabled]
     currentNodeScope = state.nodeScope;
     ${grammar.parserClassName}.this.parsingStack = state.parsingStack;
[/#if]
    if (state.lastConsumed != null) {
        //REVISIT
         lastConsumedToken = state.lastConsumed;
    }
[#if grammar.lexerData.numLexicalStates > 1]     
     token_source.switchTo(lastConsumedToken.getFollowingLexicalState());
     if (token_source.doLexicalStateSwitch(lastConsumedToken.getType())) {
         token_source.reset(lastConsumedToken);
         lastConsumedToken.setNext(null);
         lastConsumedToken.setNextToken(null);
     }
[/#if]          
  } 
  
[/#if] 