/*
 *  Copyright © 2013 Luca Bruno
 *
 *  This file is part of Vanubi.
 *
 *  Vanubi is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Vanubi is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Vanubi.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Vanubi.Vade {
	public enum TType {
		OPEN_BRACE,
		CLOSE_BRACE,
		OPEN_PAREN,
		CLOSE_PAREN,
		OPEN_SQUARE,
		CLOSE_SQUARE,
		COMMA,
		COLON,
		SEMICOLON,
		PLUS,
		MINUS,
		INC,
		DEC,
		STRING,
		ADDRESS,
		ID,
		NUM,
		MOD,
		DIV,
		MUL,
		POW,
		IDIV,
		GT,
		LT,
		GE,
		LE,
		EQ,
		AND,
		OR,
		BIT_AND,
		BIT_OR,
		ASSIGN,
		DOT,
		END,
		UNKNOWN
	}
	
	[Immutable]
	public struct Token {
		public TType type;
		public int offset;
		public int length;
		public double num;
		public string str;
		
		public Token (TType type, int offset, int length) {
			this.type = type;
			this.offset = offset;
			this.length = length;
		}
		
		public string to_string () {
			return @"$(type.to_string())($offset,$length)";
		}
	}
	
	public class Lexer {
		public string code;
		public int len;
		public int pos;
		
		public char @char {
			get {
				return code[pos];
			}
		}
		
		public Lexer (string code) {
			this.code = code;
			this.len = code.length;
			this.pos = 0;
		}
		
		public Token next () throws VError.SYNTAX_ERROR {
			while (pos < len && char.isspace ()) pos++;
			if (pos >= len) {
				return Token (TType.END, pos, 0);
			}
			
			var orig = pos;
			switch (char) {
			case '+':
				pos++;
				if (char == '+') {
					pos++;
					return Token (TType.INC, orig, 2);
				}
				return Token (TType.PLUS, orig, 1);
			case '-':
				pos++;
				if (char == '-') {
					pos++;
					return Token (TType.DEC, orig, 2);
				}
				return Token (TType.MINUS, orig, 1);
			case '*':
				pos++;
				if (char == '*') {
					pos++;
					return Token (TType.POW, orig, 2);
				}
				return Token (TType.MUL, orig, 1);
			case '/':
				pos++;
				if (char == '/') {
					pos++;
					return Token (TType.IDIV, orig, 2);
				}
				return Token (TType.DIV, orig, 1);
			case '.':
				pos++;
				return Token (TType.DOT, orig, 1);
			case '{':
				pos++;
				return Token (TType.OPEN_BRACE, orig, 1);
			case '[':
				pos++;
				return Token (TType.OPEN_SQUARE, orig, 1);
			case '(':
				pos++;
				return Token (TType.OPEN_PAREN, orig, 1);
			case '}':
				pos++;
				return Token (TType.CLOSE_BRACE, orig, 1);
			case ']':
				pos++;
				return Token (TType.CLOSE_SQUARE, orig, 1);
			case ')':
				pos++;
				return Token (TType.CLOSE_PAREN, orig, 1);
			case ',':
				pos++;
				return Token (TType.COMMA, orig, 1);
			case ':':
				pos++;
				return Token (TType.COLON, orig, 1);
			case ';':
				pos++;
				return Token (TType.SEMICOLON, orig, 1);
			case '&':
				pos++;
				if (char == '&') {
					pos++;
					return Token (TType.AND, orig, 1);
				}
				return Token (TType.BIT_AND, orig, 1);
			case '|':
				pos++;
				if (char == '|') {
					pos++;
					return Token (TType.OR, orig, 1);
				}
				return Token (TType.BIT_OR, orig, 1);
			case '=':
				pos++;
				if (char == '=') {
					pos++;
					return Token (TType.EQ, orig, 2);
				}
				return Token (TType.ASSIGN, orig, 1);
			case '>':
				pos++;
				if (char == '=') {
					pos++;
					return Token (TType.GE, orig, 2);
				}
				return Token (TType.GT, orig, 1);
			case '<':
				pos++;
				if (char == '<') {
					pos++;
					return Token (TType.LE, orig, 2);
				}
				return Token (TType.LT, orig, 1);
			case '\'':
				pos++;
				var b = new StringBuilder ();
				while (pos < len && char != '\'') {
					if (char == '\\') {
						b.append_c (char);
						pos++;
						b.append_c (char);
						pos++;
					} else {
						b.append_c (char);
						pos++;
					}
				}
				if (pos >= len) {
					throw new VError.SYNTAX_ERROR ("Unterminated string literal");
				}
				pos++;
				var tok = Token (TType.STRING, orig, pos);
				tok.str = (owned) b.str;
				return tok;
			}
			
			if (char.isdigit ()) {
				// number
				double num = 0;
				int numbase = 10;
				if (char == '0') {
					pos++;
					if (char == 'x') {
						// hex
						numbase = 16;
						pos++;
						while (char.isxdigit ()) {
							if (char.isdigit ()) {
								num += char-'0';
								num *= 16;
							} else {
								num += char.tolower()-'a'+10;
								num *= 16;
							}
							pos++;
						}
					} else if (char == 'b') {
						// bin
						numbase = 2;
						pos++;
						while (char == '0' || char == '1') {
							num += char-'0';
							num *= 2;
							pos++;
						}
					} else if (char.isdigit () && (char-'0' < 8)) {
						numbase = 8;
						// octal
						while (char.isdigit () && (char-'0' < 8)) {
							num += char-'0';
							num *= 8;
							pos++;
						}
					} else if (char == '.') {
						// decimal
					} else {
						throw new VError.SYNTAX_ERROR ("Unsupported number literal format");
					}						
				} else {
					// decimal
					while (char.isdigit ()) {
						num += char-'0';
						num *= 10;
						pos++;
					}
				}
				
				if (numbase == 10 && char == '.') {
					pos++;
					var ndec = 1;
					while (char.isdigit ()) {
						num += char-'0';
						num *= 10;
						ndec *= 10;
						pos++;
					}
					num /= ndec;
				}
				num /= numbase;
				var tok = Token (TType.NUM, orig, pos);
				tok.num = num;
				return tok;
			}
			
			if (char.isalpha ()) {
				// identifier
				var b = new StringBuilder ();
				b.append_c (char);
				pos++;
				while (char.isalnum () || char == '_') {
					b.append_c (char);
					pos++;
				}
				var tok = Token (TType.ID, orig, pos);
				tok.str = (owned) b.str;
				return tok;
			}

			return Token (TType.UNKNOWN, orig, 1);
		}
	}	
}