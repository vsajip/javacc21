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
 *     * Redistributions in binary formnt must reproduce the above copyright
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


import java.io.IOException;
import java.io.*;
import java.util.HashMap;

/**
 * Rather bloody-minded implementation of a class to read in a file 
 * and store the contents in a String, and keep track of where the 
 * lines are.
 */

public class FileLineMap {

   static private HashMap<String, FileLineMap> tableLookup = new HashMap<>();
   
   static FileLineMap getFileLineMap(String inputSource) {
        return tableLookup.get(inputSource);
   }
   
	
	// File content without any adjustments for unicode escapes or tabs or any of that.
	private String rawContent;
	
// Munged content, possibly replace unicode escapes, tabs, or CRLF with LF.	
	private String content;
	
	// Typically a filename, I suppose.
	private String inputSource;
	
	// A list of offsets of the beginning of lines
	private int[] lineOffsets = new int[1024];

	private int startingLine = 1, startingColumn = 1;
		
	[#var PRESERVE_LINE_ENDINGS = grammar.options.preserveLineEndings?string("true", "false")]
	[#var JAVA_UNICODE_ESCAPE = grammar.options.javaUnicodeEscape?string("true", "false")]
	
	public FileLineMap(String inputSource, CharSequence charSequence) {
		this.inputSource = inputSource;
		this.rawContent = charSequence.toString(); // We will likely need this eventually, I suppose.
		this.content = mungeContent(rawContent, ${grammar.options.tabsToSpaces}, ${PRESERVE_LINE_ENDINGS}, ${JAVA_UNICODE_ESCAPE});
		if (this.content.equals(this.rawContent)) {
		        this.content = this.rawContent;
		}
		this.lineOffsets = createLineOffsetsTable(this.content);
		if (inputSource != null && inputSource.length() >0) {
			tableLookup.put(inputSource, this);
	    }
	}
	
	public FileLineMap(String inputSource, Reader reader) {
		this(inputSource, readToEnd(reader));
	}
	
	public FileLineMap(Reader reader, int startingLine, int startingColumn) {
	    this("", reader);
	    this.startingLine = this.line = startingLine;
	    this.startingColumn = this.column = startingColumn;
	}
	
	public FileLineMap(String inputSource, File file) throws IOException {
		this(inputSource, new FileReader(file));
	}
	
	
	// Icky method to handle annoying stuff. Might make this public later if it is needed elsewhere
    private String mungeContent(String content, int tabsToSpaces, boolean preserveLines, boolean javaUnicodeEscape) {
            if (tabsToSpaces<=0 && preserveLines && !javaUnicodeEscape) return content;
            StringBuilder buf = new StringBuilder();
            int index =0; 
            int col = 0; // This is just to handle spaces to tabs. If you don't have that setting set, it is really unused.
                while(index< content.length()) {
                char ch = content.charAt(index++);
                if (ch == '\\' && javaUnicodeEscape && index < content.length()) {
                   ch = content.charAt(index++);
                   if (ch != 'u') {
                      buf.append((char) '\\');
                      buf.append(ch);
                      if (ch == '\n') col =0; 
                      else col+=2;
                   }
                   else {
                       while (content.charAt(index) == 'u') {
                          index++; 
                         // col++;
                       }
                       String hex = content.substring(index, index+=4);
                       buf.append((char) Integer.parseInt(hex, 16));
                       //col +=6; 
                       ++col; // REVISIT. Should this increase by six or one? Really just a corner case anyway.
                   }
                }
                else if (ch == '\r' && !preserveLines) {
                   buf.append((char)'\n'); 
                   if (index < content.length()) {
                       ch = content.charAt(index++);
                       if (ch!='\n') {
                           buf.append(ch);
                           ++col;
                        } 
                        else col = 0;
                   }
                } 
                else if (ch == '\t' && tabsToSpaces > 0) {
                    int spacesToAdd = tabsToSpaces - col%tabsToSpaces;
                    for (int i=0; i<spacesToAdd; i++) {
                        buf.append((char) ' ');
                        col++;
                    }
                }
                else {
                    buf.append((char) ch);
                    if (ch=='\n') {
                        col = 0;
                    } 
                    else col++;
                }
            }
            return buf.toString();
        }
	
	
	public String getInputSource() {
		return inputSource;
	}
	
	public int getLineCount() {
	    return lineOffsets.length;
	}
	
	public String getText(int beginLine, int beginColumn, int endLine, int endColumn) {
		int startOffset = getOffset(beginLine, beginColumn);
		int endOffset = getOffset(endLine, endColumn);
		return content.substring(startOffset, endOffset+1);
	}
	
	public String getLine(int lineNumber) {
	    int realLineNumber = lineNumber - startingLine;
	    int startOffset = lineOffsets[realLineNumber];
	    int endOffset = (realLineNumber+1 == lineOffsets.length) ? content.length() : lineOffsets[realLineNumber+1];
	    return content.substring(startOffset, endOffset);
	}
	
	public void setStartPosition(int line, int column) {
	   this.startingLine = line;
	   this.startingColumn = column;
	   this.line = line;
	   this.column = column; 
	}
	
	private int getOffset(int line, int column) {
	   int columnAdjustment = (line==startingLine) ? column- startingColumn : 1; 
       return lineOffsets[line-startingLine] + column - columnAdjustment;
	}
	
	public int getLineNumber(int offset) {
		int i =0;
		while (offset >= lineOffsets[i++]) {
			if (i==lineOffsets.length) break;
		}
		return i + startingLine -1;
	}
	
	
	static int[] createLineOffsetsTable(CharSequence charSequence) {
	     if (charSequence.length() == 0) {
	         return new int[0];
	     }
	     final char[] chars = charSequence.toString().toCharArray();
	     int lineCount = 0;
	     for (char ch : chars) {
	         if (ch == '\n') lineCount++;
	     }
	     if (chars[chars.length-1] != '\n') lineCount++;
	     int [] table = new int[lineCount];
	     table[0] = 0;
	     int index = 1;
	     for (int i=0; i < chars.length; i++) {
	         if (chars[i] == '\n') {
	             if (i+1 == chars.length) break;
	             table[index++] = i+1;
	         }
	     }
	     return table;
	}
	
	static private int BUF_SIZE = 0x10000;
	
	//Annoying kludge really...
	
	static private String readToEnd(Reader reader) {
	    try {
	        return readFully(reader);
	    } catch (IOException ioe) {
	        throw new RuntimeException(ioe);
	    } 
	}
	
	static String readFully(Reader reader) throws IOException {
		char[] block = new char[BUF_SIZE];
		int charsRead = reader.read(block);
		if (charsRead < 0) {
			throw new IOException("No input");
		}
		else if (charsRead < BUF_SIZE) {
			char[] result = new char[charsRead];
			System.arraycopy(block, 0, result, 0, charsRead);
			reader.close();
			return new String(block, 0, charsRead);
		}
		StringBuilder buf = new StringBuilder();
     	buf.append(block);
		do {
	     	charsRead = reader.read(block);
	     	if (charsRead >0) {
	     		buf.append(block, 0, charsRead);
	     	}
		} while (charsRead == BUF_SIZE);
		reader.close();
		return buf.toString();
	}

// Now some methods to fulfill the functionality that used to be in that SimpleCharStream class
// REVISIT: Currently the backup() method does not handle any of the messiness with column numbers relating to tabs 
// or unicode escapes. (Maybe REVISIT)

	private int bufferPosition, tokenBeginOffset, tokenBeginColumn,  tokenBeginLine, line =1, column =1;
	
    public void backup(int amount) {
        for (int i =0; i<amount; i++) {
           --bufferPosition;
            if (column ==1) {
                --line;
                column = getLine(line).length();
            } else {
                --column;
            }
         }
    }

	int readChar()  {
	     if (bufferPosition >= content.length()) {
	         return -1;
	     }
	     int ch = content.charAt(bufferPosition++);
	     if (ch == '\n') {
	         ++line;
	         column =1;
	     } else {
	         ++column;
	     }
	     return ch;
    }
	
    String getImage() {
          return content.substring(tokenBeginOffset, bufferPosition);
    }
    
    String getSuffix(final int len) {
         int startPos = bufferPosition - len +1;
         return content.substring(startPos, bufferPosition);
    } 

    int beginToken() {
        tokenBeginOffset = bufferPosition;
        tokenBeginColumn = column;
        tokenBeginLine = line;
        return readChar();
    }
   
    int getBeginColumn() {
        return tokenBeginColumn;
    }
    
    int getBeginLine() {
        return tokenBeginLine;
    }
   
    int getEndColumn() {
         if (column==1) {
              if (line == tokenBeginLine) {
                  return 1;
              }
              return getLine(line-1).length();
         }
         return column -1;
    }
    
    int getEndLine() {
        if (column == 1 && line > tokenBeginLine) return line -1;
        return line;
    }
}
