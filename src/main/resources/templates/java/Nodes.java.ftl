[#ftl strict_vars=true]
[#--
/* Copyright (c) 2008-2019 Jonathan Revusky, revusky@javacc.com
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
 /* Generated by: ${generated_by}. ${filename} */
[#if grammar.parserPackage?has_content]
package ${grammar.parserPackage};
[/#if]
import java.util.*;

/**
 * A set of static utility routines, mostly for working with Node objects.
 * These methods were not added to the Node interface in order to keep it 
 * fairly easy for someone to write their own Node implementation. 
 */

abstract public class Nodes {
    
     static public List<Token> getTokens(Node node) {
	       return node.descendantsOfType(Token.class);
    }
        
        
    static public List<Token> getRealTokens(Node node) {
        List<Token> result = new ArrayList<Token>();
		for (Token token : getTokens(node)) {
		    if (!token.isUnparsed()) {
		        result.add(token);
		    }
		}
	    return result;
	}
     
    // NB: This is not thread-safe
    // If the node's children could change out from under you,
    // you could have a problem.

    static public ListIterator<Node> iterator(final Node node) {
        return new ListIterator<Node>() {
            int current = -1;
            boolean justModified;
            
            public boolean hasNext() {
                return current+1 < node.getChildCount();
            }
            
            public Node next() {
                justModified = false;
                return node.getChild(++current);
            }
            
            public Node previous() {
                justModified = false;
                return node.getChild(--current);
            }
            
            public void remove() {
                if (justModified) throw new IllegalStateException();
                node.removeChild(current);
                --current;
                justModified = true;
            }
            
            public void add(Node n) {
                if (justModified) throw new IllegalStateException();
                node.addChild(current+1, n);
                justModified = true;
            }
            
            public boolean hasPrevious() {
                return current >0;
            }
            
            public int nextIndex() {
                return current + 1;
            }
            
            public int previousIndex() {
                return current;
            }
            
            public void set(Node n) {
                node.setChild(current, n);
            }
        };
    }
 
    /**
     * Expands (in place) a Node's children to include any comment tokens hanging
     * off the regular tokens.
     * @param n the Node 
     * @param recursive whether to recurse into child nodes.
     */

    static public void expandSpecialTokens(Node n, boolean recursive) {
        List<Token> expandedList = getAllTokens(n, true, false);
        n.clearChildren();
        for (Node child : expandedList) {
            n.addChild(child);
            if (recursive && child.getChildCount() >0) {
                expandSpecialTokens(child, true);
            }
        }
    }
    
    /**
     * @return a List containing all the tokens in a Node
     * @param n The Node 
     * @param includeCommentTokens Whether to include comment tokens
     * @param recursive Whether to recurse into child Nodes.
     */
    static public List<Token> getAllTokens(Node n, boolean includeCommentTokens, boolean recursive) {
		List<Token> result = new ArrayList<Token>();
        for (Iterator<Node> it = iterator(n); it.hasNext();) {
            Node child = it.next();
            if (child instanceof Token) {
                Token token = (Token) child;
                if (token.isUnparsed()) {
                    continue;
                }
                if (includeCommentTokens) {
	                Token specialToken = token;
	                while (specialToken.getSpecialToken() != null) {
	                    specialToken = specialToken.getSpecialToken();
	                }
	                while (specialToken != token && specialToken !=null) {
	                    result.add(specialToken);
	                    specialToken = specialToken.getNext();
	                }
                }
                result.add(token);
            } 
            else if (child.getChildCount() >0) {
               result.addAll(getAllTokens(child, includeCommentTokens, recursive));
            }
        }
        return result;
    }
    
    static public void copyLocationInfo(Node from, Node to) {
//        to.setInputSource(from.getInputSource()); REVISIT
        to.setBeginLine(from.getBeginLine());
        to.setBeginColumn(from.getBeginColumn());
        to.setEndLine(from.getEndLine());
        to.setEndColumn(from.getEndColumn());
    }
    
    static private String stringrep(Node n) {
        if (n instanceof Token) {
            return n.toString().trim();
        }
        return n.getClass().getSimpleName();
    }
   
    static public void dump(Node n, String prefix) {
        String output = stringrep(n);
        if (output.length() >0) {
            System.out.println(prefix + output);
        }
        for (Iterator<Node> it = iterator(n); it.hasNext();) {
            Node child = it.next();
            dump(child, prefix+"  ");
        }
    }

    static public void dump(Node n) {
        dump(n, "");
    }
 }
