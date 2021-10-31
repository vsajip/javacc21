[#ftl strict_vars=true]
[#--
/* Copyright (c) 2008-2020 Jonathan Revusky, revusky@javacc.com
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

[#-- This template contains the core logic for generating the various parser routines. --]

[#import "CommonUtils.java.ftl" as CU]

[#var nodeNumbering = 0]
[#var NODE_USES_PARSER = grammar.nodeUsesParser]
[#var NODE_PREFIX = grammar.nodePrefix]
[#var currentProduction]

[#macro Productions] 
 //=================================
 // Start of methods for BNF Productions
 //This code is generated by the ParserProductions.java.ftl template. 
 //=================================
  [#list grammar.parserProductions as production]
   [@CU.firstSetVar production.expansion/]
   [#if !production.onlyForLookahead]
    [#set currentProduction = production]
    [@ParserProduction production/]
   [/#if]
  [/#list]
  [#if grammar.faultTolerant]
    [@BuildRecoverRoutines /]
  [/#if]
[/#macro]

[#macro ParserProduction production]
    ${production.leadingComments}
// ${production.location}
    final ${production.accessModifier}
    ${production.returnType}
    ${production.name}(${production.parameterList!}) 
    throws ParseException
    [#list (production.throwsList.types)! as throw], ${throw}[/#list] {
     if (trace_enabled) LOGGER.info("Entering production defined on line ${production.beginLine} of ${production.inputSource?j_string}");
     if (cancelled) throw new CancellationException();
     String prevProduction = currentlyParsedProduction;
     this.currentlyParsedProduction = "${production.name}";
     [#--${production.javaCode!}
       This is actually inserted further down because
       we want the prologue java code block to be able to refer to 
       CURRENT_NODE.
     --]
     [@BuildCode production.expansion /]
    }   
[/#macro]

[#macro BuildCode expansion]
   [#if expansion.simpleName != "ExpansionSequence" && expansion.simpleName != "ExpansionWithParentheses"]
  // Code for ${expansion.simpleName} specified at:
  // ${expansion.location}
  [/#if]
     [@CU.HandleLexicalStateChange expansion false]
      [#if grammar.faultTolerant && expansion.requiresRecoverMethod && !expansion.possiblyEmpty]
         if (pendingRecovery) {
            if (debugFaultTolerant) LOGGER.info("Re-synching to expansion at: ${expansion.location?j_string}");
            ${expansion.recoverMethodName}();
         }
      [/#if]
       [@TreeBuildingAndRecovery expansion]
        [@BuildExpansionCode expansion/]
       [/@TreeBuildingAndRecovery]
     [/@CU.HandleLexicalStateChange]
[/#macro]

[#macro TreeBuildingAndRecovery expansion]
[#-- This macro handles both tree building AND recovery. It doesn't seem right.
     It should probably be two macros. Also, it is too darned big. --]
    [#var nodeVarName, 
          production, 
          treeNodeBehavior, 
          buildTreeNode=false, 
          closeCondition = "true", 
          javaCodePrologue = "",
          parseExceptionVar = CU.newVarName("parseException"),
          callStackSizeVar = CU.newVarName("callStackSize"),
          canRecover = grammar.faultTolerant && expansion.tolerantParsing && !expansion.isRegexp
    ]
    [#set treeNodeBehavior = expansion.treeNodeBehavior]
    [#if expansion.parent.simpleName = "BNFProduction"]
      [#set production = expansion.parent]
      [#set javaCodePrologue = production.javaCode!]
    [/#if]
    [#if grammar.treeBuildingEnabled]
      [#set buildTreeNode = (treeNodeBehavior?is_null && production?? && !grammar.nodeDefaultVoid)
                        || (treeNodeBehavior?? && !treeNodeBehavior.neverInstantiated)]
    [/#if]
    [#if !buildTreeNode && !canRecover]
      ${javaCodePrologue} 
      [#nested]
    [#else]
     [#if buildTreeNode]
     [#set nodeNumbering = nodeNumbering +1]
     [#set nodeVarName = currentProduction.name + nodeNumbering] ${grammar.utils.pushNodeVariableName(nodeVarName)!}
      [#if !treeNodeBehavior?? && !production?is_null]
         [#if grammar.smartNodeCreation]
            [#set treeNodeBehavior = {"name" : production.name, "condition" : "1", "gtNode" : true, "void" :false, "initialShorthand" : ">"}]
         [#else]
            [#set treeNodeBehavior = {"name" : production.name, "condition" : null, "gtNode" : false, "void" : false}]
         [/#if]
      [/#if]
      [#if treeNodeBehavior.condition?has_content]
         [#set closeCondition = treeNodeBehavior.condition]
         [#if treeNodeBehavior.gtNode]
            [#set closeCondition = "nodeArity() " + treeNodeBehavior.initialShorthand  + closeCondition]
         [/#if]
      [/#if]
      [@createNode treeNodeBehavior nodeVarName false /]
      [/#if]
         [#-- I put this here for the hypertechnical reason
              that I want the initial code block to be able to 
              reference CURRENT_NODE. --]
         ${javaCodePrologue}
         ParseException ${parseExceptionVar} = null;
         int ${callStackSizeVar} = parsingStack.size();
         try {
            if (false) throw new ParseException("Never happens!");
            [#nested]
         }
         catch (ParseException e) { 
            ${parseExceptionVar} = e;
            [#if !canRecover]
              [#if grammar.faultTolerant]
                if (isParserTolerant()) this.pendingRecovery = true;
              [/#if]
              throw e;
            [#else]
             if (!isParserTolerant()) throw e;
             this.pendingRecovery = true;
             ${expansion.customErrorRecoveryBlock!}
             [#if !production?is_null && production.returnType != "void"]
                [#var rt = production.returnType]
                [#-- We need a return statement here or the code won't compile! --]
                [#if rt = "int" || rt="char" || rt=="byte" || rt="short" || rt="long" || rt="float"|| rt="double"]
                return 0;
                [#else]
                return null;
                [/#if]
             [/#if]
          [/#if]
         }
         finally {
             restoreCallStack(${callStackSizeVar});
             [#if buildTreeNode]
             if (${nodeVarName}!=null) {
                 if (${parseExceptionVar} == null) {
                     closeNodeScope(${nodeVarName}, ${closeCondition});
                     [#list grammar.closeNodeHooksByClass[nodeClassName(treeNodeBehavior)]! as hook]
                        ${hook}(${nodeVarName});
                     [/#list]
                 } else {
                     if (trace_enabled) LOGGER.warning("ParseException: " + ${parseExceptionVar}.getMessage());
                  [#if grammar.faultTolerant]
                     closeNodeScope(${nodeVarName}, true);
                     ${nodeVarName}.setDirty(true);
                  [#else]
                     clearNodeScope();
                  [/#if]
                 }
             }
          ${grammar.utils.popNodeVariableName()!}
             [/#if]
             this.currentlyParsedProduction = prevProduction;
         }       
    [/#if]
[/#macro]

[#--  Boilerplate code to create the node variable --]
[#macro createNode treeNodeBehavior nodeVarName isAbstractType]
   [#var nodeName = nodeClassName(treeNodeBehavior)]
   ${nodeName} ${nodeVarName} = null;
   [#if !isAbstractType]
   if (buildTree) {
     ${nodeVarName} = new ${nodeName}();
  [#if grammar.nodeUsesParser]
     ${nodeVarName}.setParser(this);
  [/#if]
   openNodeScope(${nodeVarName});
  }
  [/#if]
[/#macro]

[#function nodeClassName treeNodeBehavior]
   [#if treeNodeBehavior?? && treeNodeBehavior.nodeName??] 
      [#return NODE_PREFIX + treeNodeBehavior.nodeName]
   [/#if]
   [#return NODE_PREFIX + currentProduction.name]
[/#function]


[#macro BuildExpansionCode expansion]
    [#var classname=expansion.simpleName]
    [#var prevLexicalStateVar = CU.newVarName("previousLexicalState")]
    [#if classname = "ExpansionWithParentheses"]
       [@BuildExpansionCode expansion.nestedExpansion/]
    [#elseif classname = "CodeBlock"]
       ${expansion}
    [#elseif classname = "UncacheTokens"]
         uncacheTokens();
    [#elseif classname = "Failure"]
       [@BuildCodeFailure expansion/]
    [#elseif classname = "TokenTypeActivation"]
       [@BuildCodeTokenTypeActivation expansion/]
    [#elseif classname = "ExpansionSequence"]
       [@BuildCodeSequence expansion/]
    [#elseif classname = "NonTerminal"]
       [@BuildCodeNonTerminal expansion/]
    [#elseif expansion.isRegexp]
       [@BuildCodeRegexp expansion/]
    [#elseif classname = "TryBlock"]
       [@BuildCodeTryBlock expansion/]
    [#elseif classname = "AttemptBlock"]
       [@BuildCodeAttemptBlock expansion /]
    [#elseif classname = "ZeroOrOne"]
       [@BuildCodeZeroOrOne expansion/]
    [#elseif classname = "ZeroOrMore"]
       [@BuildCodeZeroOrMore expansion/]
    [#elseif classname = "OneOrMore"]
        [@BuildCodeOneOrMore expansion/]
    [#elseif classname = "ExpansionChoice"]
        [@BuildCodeChoice expansion/]
    [#elseif classname = "Assertion"]
        [@BuildAssertionCode expansion/]
    [/#if]
[/#macro]

[#macro BuildCodeFailure fail]
    [#if fail.code?is_null]
      [#if fail.exp??]
       fail("Failure: " + ${fail.exp});
      [#else]
       fail("Failure");
      [/#if]
    [#else]
       ${fail.code}
    [/#if]
[/#macro]

[#macro BuildCodeTokenTypeActivation activation]
    [#if activation.deactivate]
       deactivateTokenTypes(
    [#else]
       activateTokenTypes(
    [/#if]
    [#list activation.tokenNames as name]
       ${CU.TT}${name} [#if name_has_next],[/#if]
    [/#list]
       );
[/#macro]

[#macro BuildCodeSequence expansion]
       [#list expansion.units as subexp]
           [@BuildCode subexp/]
       [/#list]        
[/#macro]

[#macro BuildCodeRegexp regexp]
   [#var LHS = ""]
   [#if regexp.LHS??][#set LHS = regexp.LHS + "="][/#if]
   [#if !grammar.faultTolerant]
       ${LHS} consumeToken(${CU.TT}${regexp.label});
   [#else]
       [#var tolerant = regexp.tolerantParsing?string("true", "false")]
       [#var followSetVarName = regexp.followSetVarName]
       [#if regexp.followSet.incomplete]
         [#set followSetVarName = "followSet" + CU.newID()]
         EnumSet<TokenType> ${followSetVarName} = null;
         if (outerFollowSet != null) {
            ${followSetVarName} = ${regexp.followSetVarName}.clone();
            ${followSetVarName}.addAll(outerFollowSet);
         }
       [/#if]
       ${LHS} consumeToken(${CU.TT}${regexp.label}, ${tolerant}, ${followSetVarName});
   [/#if]
[/#macro]

[#macro BuildCodeTryBlock tryblock]
     try {
        [@BuildCode tryblock.nestedExpansion /]
     }
   [#list tryblock.catchBlocks as catchBlock]
     ${catchBlock}
   [/#list]
     ${tryblock.finallyBlock!}
[/#macro]


[#macro BuildCodeAttemptBlock attemptBlock]
   try {
      stashParseState();
      [@BuildCode attemptBlock.nestedExpansion /]
      popParseState();
   }
   catch (ParseException e) {
      restoreStashedParseState();
      [@BuildCode attemptBlock.recoveryExpansion /]
   }
[/#macro]

[#macro BuildCodeNonTerminal nonterminal]
   [#var production = nonterminal.production]
   pushOntoCallStack("${nonterminal.containingProduction.name}", "${nonterminal.inputSource?j_string}", ${nonterminal.beginLine}, ${nonterminal.beginColumn});
   [#if grammar.faultTolerant]
      [#var followSet = nonterminal.followSet]
      [#if !followSet.incomplete]
         [#if !nonterminal.beforeLexicalStateSwitch]
            outerFollowSet = ${nonterminal.followSetVarName};
         [#else]
            outerFollowSet = null;
         [/#if]
      [#elseif !followSet.isEmpty()]
         if (outerFollowSet != null) {
            EnumSet<TokenType> newFollowSet = ${nonterminal.followSetVarName}.clone();
            newFollowSet.addAll(outerFollowSet);
            outerFollowSet = newFollowSet;
         }
      [/#if]
   [/#if]
   try {
   [#if !nonterminal.LHS?is_null && production.returnType != "void"]
       ${nonterminal.LHS} = 
   [/#if]
      ${nonterminal.name}(${nonterminal.args!});
   [#if !nonterminal.LHS?is_null && production.returnType = "void"]
      try {
         ${nonterminal.LHS} = (${production.nodeName}) peekNode();
      } catch (ClassCastException cce) {
         ${nonterminal.LHS} = null;
      }
   [/#if]
   } 
   finally {
       popCallStack();
   }
[/#macro]


[#macro BuildCodeZeroOrOne zoo]
    [#if zoo.nestedExpansion.alwaysSuccessful
      || zoo.nestedExpansion.class.simpleName = "ExpansionChoice"]
       [@BuildCode zoo.nestedExpansion /]
    [#else]
       if (${ExpansionCondition(zoo.nestedExpansion)}) {
          ${BuildCode(zoo.nestedExpansion)}
       }
    [/#if]
[/#macro]

[#var inFirstVarName = "", inFirstIndex =0]

[#macro BuildCodeOneOrMore oom]
   [#var nestedExp=oom.nestedExpansion, prevInFirstVarName = inFirstVarName/]
   [#if nestedExp.simpleName = "ExpansionChoice"]
     [#set inFirstVarName = "inFirst" + inFirstIndex, inFirstIndex = inFirstIndex +1 /]
     boolean ${inFirstVarName} = true; 
   [/#if]
   while (true) {
      [@RecoveryLoop oom /]
      [#if nestedExp.simpleName = "ExpansionChoice"]
         ${inFirstVarName} = false;
      [#else]
         if (!(${ExpansionCondition(oom.nestedExpansion)})) break;
      [/#if]
   }
   [#set inFirstVarName = prevInFirstVarName /]
[/#macro]

[#macro BuildCodeZeroOrMore zom]
    while (true) {
       [#if zom.nestedExpansion.class.simpleName != "ExpansionChoice"]
         if (!(${ExpansionCondition(zom.nestedExpansion)})) break;
       [/#if]
       [@RecoveryLoop zom/]
    }
[/#macro]

[#macro RecoveryLoop loopExpansion]
   [#if !grammar.faultTolerant || !loopExpansion.requiresRecoverMethod]
       ${BuildCode(loopExpansion.nestedExpansion)}
   [#else]
       [#var initialTokenVarName = "initialToken" + CU.newID()]
       Token ${initialTokenVarName} = lastConsumedToken;
       try {
          ${BuildCode(loopExpansion.nestedExpansion)}
       } catch (ParseException pe) {
          if (!isParserTolerant()) throw pe;
          if (debugFaultTolerant) LOGGER.info("Handling exception. Last consumed token: " + lastConsumedToken.getImage() + " at: " + lastConsumedToken.getLocation());
          if (${initialTokenVarName} == lastConsumedToken) {
             lastConsumedToken = nextToken(lastConsumedToken);
             //We have to skip a token in this spot or 
             // we'll be stuck in an infinite loop!
             lastConsumedToken.setSkipped(true);
             if (debugFaultTolerant) LOGGER.info("Skipping token " + lastConsumedToken.getImage() + " at: " + lastConsumedToken.getLocation());
          }
          if (debugFaultTolerant) LOGGER.info("Repeat re-sync for expansion at: ${loopExpansion.location?j_string}");
          ${loopExpansion.recoverMethodName}();
          if (pendingRecovery) throw pe;
       }
   [/#if]
[/#macro]

[#macro BuildCodeChoice choice]
   [#list choice.choices as expansion]
      [#if expansion.alwaysSuccessful]
         else {
           [@BuildCode expansion /]
         }
         [#return]
      [/#if]
      ${(expansion_index=0)?string("if", "else if")}
      (${ExpansionCondition(expansion)}) { 
         ${BuildCode(expansion)}
      }
   [/#list]
   [#if choice.parent.simpleName == "ZeroOrMore"]
      else {
         break;
      }
   [#elseif choice.parent.simpleName = "OneOrMore"]
       else if (${inFirstVarName}) {
           pushOntoCallStack("${currentProduction.name}", "${choice.inputSource?j_string}", ${choice.beginLine}, ${choice.beginColumn});
           throw new ParseException(this, ${choice.firstSetVarName}, parsingStack);
       } else {
           break;
       }
   [#elseif choice.parent.simpleName != "ZeroOrOne"]
       else {
           pushOntoCallStack("${currentProduction.name}", "${choice.inputSource?j_string}", ${choice.beginLine}, ${choice.beginColumn});
           throw new ParseException(this, ${choice.firstSetVarName}, parsingStack);
        }
   [/#if]
[/#macro]

[#-- 
     Macro to generate the condition for entering an expansion
     including the default single-token lookahead
--]
[#macro ExpansionCondition expansion]
    [#if expansion.requiresPredicateMethod]
       ${ScanAheadCondition(expansion)}
    [#else] 
       ${SingleTokenCondition(expansion)}
    [/#if]
[/#macro]


[#-- Generates code for when we need a scanahead --]
[#macro ScanAheadCondition expansion]
   [#if expansion.lookahead?? && expansion.lookahead.LHS??]
      (${expansion.lookahead.LHS} =
   [/#if]
   [#if expansion.hasSemanticLookahead && !expansion.lookahead.semanticLookaheadNested]
      (${expansion.semanticLookahead}) &&
   [/#if]
   ${expansion.predicateMethodName}()
   [#if expansion.lookahead?? && expansion.lookahead.LHS??]
      )
   [/#if]
[/#macro]


[#-- Generates code for when we don't need any scanahead routine --]
[#macro SingleTokenCondition expansion]
   [#if expansion.hasSemanticLookahead]
      (${expansion.semanticLookahead}) &&
   [/#if]
   [#if expansion.firstSet.tokenNames?size =0 || expansion.lookaheadAmount ==0]
      true 
   [#elseif expansion.firstSet.tokenNames?size < 5] 
      [#list expansion.firstSet.tokenNames as name]
          nextTokenType [#if name_index ==0]() [/#if]
          == ${CU.TT}${name} 
         [#if name_has_next] || [/#if] 
      [/#list]
   [#else]
      ${expansion.firstSetVarName}.contains(nextTokenType()) 
   [/#if]
[/#macro]



[#macro BuildAssertionRoutine assertion]
    [#var methodName = assertion.predicateMethodName?replace("scan$", "assert$")]
    [#var empty = true]
    private final void ${methodName}() throws ParseException {
       if (!(
       [#if !assertion.semanticLookahead?is_null]
          (${assertion.semanticLookahead})
          [#set empty = false /]
       [/#if]
       [#if !assertion.lookBehind?is_null]
          [#if !empty] && [/#if]
          !${assertion.lookBehind.routineName}()
       [/#if]
       [#if !assertion.expansion?is_null]
           [#if !empty] && [/#if]
           [#if assertion.expansion.negated] ! [/#if]
           ${assertion.expansion.scanRoutineName}()
       [/#if]
       )) {
          throw new ParseException(this, "${assertion.message?j_string}");
        }
    }
[/#macro]

[#macro BuildAssertionCode assertion]
   [#var optionalPart = ""]
   [#if assertion.messageExpression??]
      [#set optionalPart = " + " + assertion.messageExpression]
   [/#if]
   [#var assertionMessage = "Assertion at: " + assertion.location?j_string + " failed. "]
   [#if assertion.assertionExpression??]
      if (!(${assertion.assertionExpression})) {
         fail("${assertionMessage}"${optionalPart});
      }
   [/#if]
   [#if assertion.expansion??]
      if ( [#if !assertion.expansionNegated]![/#if]
      ${assertion.expansion.scanRoutineName}()) {
         fail("${assertionMessage}"${optionalPart});
      }
   [/#if]
[/#macro]


[#--
   Macro to build routines that scan up to the start of an expansion
   as part of a recovery routine
--]
[#macro BuildRecoverRoutines]
   [#list grammar.expansionsNeedingRecoverMethod as expansion]
       private void ${expansion.recoverMethodName}() {
          Token initialToken = lastConsumedToken;
          java.util.List<Token> skippedTokens = new java.util.ArrayList<>();
          boolean success = false;
          while (lastConsumedToken.getType() != EOF) {
            [#if expansion.simpleName = "OneOrMore" || expansion.simpleName = "ZeroOrMore"]
             if (${ExpansionCondition(expansion.nestedExpansion)}) {
            [#else]
             if (${ExpansionCondition(expansion)}) {
            [/#if]
                success = true;
                break;
             }
             [#if expansion.simpleName = "ZeroOrMore" || expansion.simpleName = "OneOrMore"]
               [#var followingExpansion = expansion.followingExpansion]
               [#list 1..1000000 as unused]
                [#if followingExpansion?is_null][#break][/#if]
                [#if followingExpansion.maximumSize >0] 
                 [#if followingExpansion.simpleName = "OneOrMore" || followingExpansion.simpleName = "ZeroOrOne" || followingExpansion.simpleName = "ZeroOrMore"]
                 if (${ExpansionCondition(followingExpansion.nestedExpansion)}) {
                 [#else]
                 if (${ExpansionCondition(followingExpansion)}) {
                 [/#if]
                    success = true;
                    break;
                 }
                [/#if]
                [#if !followingExpansion.possiblyEmpty][#break][/#if]
                [#if followingExpansion.followingExpansion?is_null]
                 if (outerFollowSet != null) {
                   if (outerFollowSet.contains(nextTokenType())) {
                      success = true;
                      break;
                   }
                 }
                 [#break/]
                [/#if]
                [#set followingExpansion = followingExpansion.followingExpansion]
               [/#list]
             [/#if]
             lastConsumedToken = nextToken(lastConsumedToken);
             skippedTokens.add(lastConsumedToken);
          }
          if (!success && !skippedTokens.isEmpty()) {
             lastConsumedToken = initialToken;
          } 
          if (success&& !skippedTokens.isEmpty()) {
             InvalidNode iv = new InvalidNode();
             for (Token tok : skippedTokens) {
                iv.addChild(tok);
             }
             if (debugFaultTolerant) {
                LOGGER.info("Skipping " + skippedTokens.size() + " tokens starting at: " + skippedTokens.get(0).getLocation());
             }
             pushNode(iv);
          }
          pendingRecovery = !success;
       }
   [/#list]
[/#macro]
