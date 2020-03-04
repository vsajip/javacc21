/* Generated by: ${generated_by}. ${filename} */
[#if grammar.parserPackage?has_content]
package ${grammar.parserPackage};
[/#if]

[#if grammar.options.userCharStream || grammar.options.userDefinedLexer]
[#include "CharStreamInterface.java.ftl"]
[#else]
[#set classname = filename?substring(0, filename?length-5)]
[#set options = grammar.options]

import java.io.*;

[#if options.javaUnicodeEscape]
/**
 * A CharStream that handles unicode escape sequences
 * as in java source files
 */
[#else]
/**
 * A simple CharStream that has no special escaping.
 */
[/#if]

public class ${classname} {
    private int bufsize, available, tokenBegin;
    /** Position in buffer. */
    private int bufpos = -1;
    private int bufline[];
    private int bufcolumn[];
    private int column = 0;
    private int line = 1;
    private boolean prevCharIsCR, prevCharIsLF;
    private Reader reader;
    private char[] buffer;
    private int maxNextCharInd, backupAmount, tabSize=8;
    
//    private StringBuilder imageBuffer = new StringBuilder();
    
    
    /**
     * sets the size of a tab for location reporting 
     * purposes, default value is 8.
     */
    public void setTabSize(int i) {this.tabSize = i;}
    
    /**
     * returns the size of a tab for location reporting 
     * purposes, default value is 8.
     */
    public int getTabSize() {return tabSize;}
    
    private void expandBuff(boolean wrapAround) {
    
    // It's amazing. We never enter this method!
    
        char[] newbuffer = new char[bufsize + 2048];

        int newbufline[] = new int[bufsize + 2048];
        int newbufcolumn[] = new int[bufsize + 2048];
        if (wrapAround) {
                 System.arraycopy(buffer, tokenBegin, newbuffer, 0, bufsize - tokenBegin);
                 System.arraycopy(buffer, 0, newbuffer, bufsize - tokenBegin, bufpos);
                 buffer = newbuffer;
                 System.arraycopy(bufline, tokenBegin, newbufline, 0, bufsize - tokenBegin);
                 System.arraycopy(bufline, 0, newbufline, bufsize - tokenBegin, bufpos);
                 bufline = newbufline;
                 System.arraycopy(bufcolumn, tokenBegin, newbufcolumn, 0, bufsize - tokenBegin);
                 System.arraycopy(bufcolumn, 0, newbufcolumn, bufsize - tokenBegin, bufpos);
                 bufcolumn = newbufcolumn;
[#if options.javaUnicodeEscape]
                bufpos += (bufsize - tokenBegin);
[#else]
                 maxNextCharInd = (bufpos += (bufsize - tokenBegin));
[/#if]                 
            }
        else {
                 System.arraycopy(buffer, tokenBegin, newbuffer, 0, bufsize - tokenBegin);
                 buffer = newbuffer;
                 System.arraycopy(bufline, tokenBegin, newbufline, 0, bufsize - tokenBegin);
                 bufline = newbufline;
                 System.arraycopy(bufcolumn, tokenBegin, newbufcolumn, 0, bufsize - tokenBegin);
                 bufcolumn = newbufcolumn;
[#if options.javaUnicodeEscape]
                 bufpos -= tokenBegin;
[#else]				 
                 maxNextCharInd = (bufpos -= tokenBegin);
[/#if]                 
         }
        bufsize += 2048;
        available = bufsize;
        tokenBegin = 0;
    }
    
    private void updateLineColumn(char c) {
        column++;
        if (prevCharIsLF) {
            prevCharIsLF = false;
            ++line;
            column = 1;
        }
        else if (prevCharIsCR) {
            prevCharIsCR = false;
            if (c == '\n') {
                prevCharIsLF = true;
            }
            else {
                ++line;
                column = 1;
            }
        }
        switch(c) {
            case '\r' : 
                prevCharIsCR = true;
                break;
            case '\n' : 
                prevCharIsLF = true;
                break;
            case '\t' : 
                column--;
                column += (tabSize - (column % tabSize));
                break;
            default : break;
        }
        bufline[bufpos] = line;
        bufcolumn[bufpos] = column;
    }

    /** Read a character. */
    public char readChar() throws IOException {
        char result;
        if (backupAmount > 0) {
           --backupAmount;
           ++bufpos;
           if (bufpos == bufsize) {
               bufpos = 0;
           }
           result = buffer[bufpos];
//           imageBuffer.append(result);
           return result;
        }
[#if options.javaUnicodeEscape]

        if (++bufpos == available)
            AdjustBuffSize();

        char c;
        if ((buffer[bufpos] = c = readByte()) == '\\') {
            updateLineColumn(c);
            int backSlashCnt = 1;

            for (;;) // Read all the backslashes
            {
                ++bufpos;
                if (bufpos == available)
                    AdjustBuffSize();

                try {
                    c = readByte();
                    buffer[bufpos] = c;
                    if (c != '\\') { 
                        updateLineColumn(c);
                        // found a non-backslash char.
                        if ((c == 'u') && ((backSlashCnt & 1) == 1)) {
                            if (--bufpos < 0)
                                bufpos = bufsize - 1;

                            break;
                        }

                        backup(backSlashCnt);
//                        imageBuffer.append("\\");
                        return '\\';
                    }
                } catch (IOException e) {
                    if (backSlashCnt > 1)
                        backup(backSlashCnt - 1);
//                    imageBuffer.append("\\");
                    return '\\';
                }
                updateLineColumn(c);
                backSlashCnt++;
            }

            // Here, we have seen an odd number of backslash's followed by a 'u'
            try {
                while ((c = readByte()) == 'u')
                    ++column;

                buffer[bufpos] = c = (char) (hexval(c) << 12
                        | hexval(readByte()) << 8 | hexval(readByte()) << 4 | hexval(readByte()));

                column += 4;
            } catch (IOException e) {
                throw new Error("Invalid escape character at line " + line
                        + " column " + column + ".");
            }

            if (backSlashCnt == 1) {
//               imageBuffer.append(c);
                return c;
            }
            else {
                backup(backSlashCnt - 1);
//                imageBuffer.append("\\");
                return '\\';
            }
        }
[#else]        
        if (++bufpos >= maxNextCharInd) {
            fillBuff();
        }
        char c = buffer[bufpos];
[/#if]        
        updateLineColumn(c);
//        imageBuffer.append(c);
        return c;
    }
    
   
    /** Get token beginning column number. */
    int getBeginColumn() {
        return bufcolumn[tokenBegin];
    }
    
    /** Get token beginning line number. */
    int getBeginLine() {
        return bufline[tokenBegin];
    }
   
    /** Get token end column number. */
    int getEndColumn() {
        return bufcolumn[bufpos];
    }
    
    /** Get token end line number. */
    int getEndLine() {
        return bufline[bufpos];
    }
    
   
    /** Backup a number of characters. */
    public void backup(int amount) {
        backupAmount += amount;
        if ((bufpos -= amount) < 0) {
            bufpos += bufsize;
        }
//       imageBuffer.setLength(imageBuffer.length() - amount);
    }

    /** Constructor. */
    public ${classname}(Reader reader, int startline, int startcolumn, int buffersize) {
        this.reader = reader;
        line = startline;
        column = startcolumn - 1;
        available = bufsize = buffersize;
        buffer = new char[buffersize];
        bufline = new int[buffersize];
        bufcolumn = new int[buffersize];
[#if options.javaUnicodeEscape]
        nextCharBuf = new char[4096];
[/#if]
     }

     /** Constructor. */
    public ${classname}(Reader reader, int startline, int startcolumn) {
        this(reader, startline, startcolumn, 4096);
    }

    /** Constructor. */
    public ${classname}(Reader reader) {
        this(reader, 1, 1, 4096);
    }
    
    /** Get token literal value. */
    public String getImage() {
        String image;
        if (bufpos >= tokenBegin) { 
            image = new String(buffer, tokenBegin, bufpos - tokenBegin + 1);
        }
        else { 
            image = new String(buffer, tokenBegin, bufsize - tokenBegin) + new String(buffer, 0, bufpos + 1);
        }
        return image;
    }
    
    /** Get the suffix. */
    public char[] getSuffix(int len) {
        char[] ret = new char[len];
        if ((bufpos + 1) >= len) { 
            System.arraycopy(buffer, bufpos - len + 1, ret, 0, len);
        }
        else {
            System.arraycopy(buffer, bufsize - (len - bufpos - 1), ret, 0, len - bufpos -1);
            System.arraycopy(buffer, 0, ret, len - bufpos - 1, bufpos + 1);
        }
        return ret;
    } 

  
[#if grammar.options.javaUnicodeEscape]
  static int hexval(char c) throws IOException {
    switch(c)
    {
       case '0' :
          return 0;
       case '1' :
          return 1;
       case '2' :
          return 2;
       case '3' :
          return 3;
       case '4' :
          return 4;
       case '5' :
          return 5;
       case '6' :
          return 6;
       case '7' :
          return 7;
       case '8' :
          return 8;
       case '9' :
          return 9;

       case 'a' :
       case 'A' :
          return 10;
       case 'b' :
       case 'B' :
          return 11;
       case 'c' :
       case 'C' :
          return 12;
       case 'd' :
       case 'D' :
          return 13;
       case 'e' :
       case 'E' :
          return 14;
       case 'f' :
       case 'F' :
          return 15;
    }

    throw new IOException(); // Should never come here
  }
  
    private void AdjustBuffSize() {
        if (available == bufsize) {
            if (tokenBegin > 2048) {
                bufpos = 0;
                available = tokenBegin;
            } else {
                expandBuff(false);
            }
        } else if (available > tokenBegin) {
            available = bufsize;
        }
        else if ((tokenBegin - available) < 2048) {
            expandBuff(true);
        }
        else {
            available = tokenBegin;
        }
    }

    private char readByte() throws IOException {
        if (++nextCharInd >= maxNextCharInd)
            fillBuff();

        return nextCharBuf[nextCharInd];
    }
    
    private void fillBuff() throws IOException {
        if (maxNextCharInd == 4096)
            maxNextCharInd = nextCharInd = 0;

        try {
            int charsRead =   reader.read(nextCharBuf, maxNextCharInd, 4096 - maxNextCharInd);
            if (charsRead == -1) {
                throw new IOException();
            } 
            maxNextCharInd += charsRead;
            return;
        } catch (IOException e) {
            if (bufpos != 0) {
                --bufpos;
                backup(0);
            } else {
                bufline[bufpos] = line;
                bufcolumn[bufpos] = column;
            }
            throw e;
        }
    }
  
    public char beginToken() throws IOException {
        if (backupAmount > 0) {
            --backupAmount;

            if (++bufpos == bufsize)
                bufpos = 0;

            tokenBegin = bufpos;
            return buffer[bufpos];
        }

        tokenBegin = 0;
        bufpos = -1;
        
//        imageBuffer = new StringBuilder();

        return readChar();
    }
    
    protected char[] nextCharBuf;
    protected int nextCharInd = -1;
[#else]
    private void fillBuff() throws IOException {
        if (maxNextCharInd == available) {
            if (available == bufsize) {
                 if (tokenBegin > 2048) {
                     bufpos = maxNextCharInd = 0;
                     available = tokenBegin;
                }
                else if (tokenBegin < 0) {
                    bufpos = maxNextCharInd = 0;
                }
                else {
                    expandBuff(false);
                }
            }
	        else if (available > tokenBegin) {
               available = bufsize; 
            }
            else if ((tokenBegin - available) < 2048) {
                expandBuff(true);
            }
            else {
                available = tokenBegin;
            }
        }
        int i;
        try {
            if ((i = reader.read(buffer, maxNextCharInd, available - maxNextCharInd)) == -1) {
                reader.close();
                throw new IOException();
            }
            else {
               maxNextCharInd += i;
            }
            return;
        }
        catch(IOException e) {
            --bufpos;
            backup(0);
            if (tokenBegin == -1) {
                tokenBegin = bufpos;
            }
            throw e;
        }
    }
    
    public char beginToken() throws IOException {
        tokenBegin = -1;
//        imageBuffer = new StringBuilder();        
        char c = readChar();
        tokenBegin = bufpos;
        return c;
    }
[/#if]
   
}
[/#if]
