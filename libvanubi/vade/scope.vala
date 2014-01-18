/*
*  Copyright © 2013-2014 Luca Bruno
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
	public abstract class Function {
		public abstract async Value eval (Scope scope, Value[]? arguments, out Value? error, Cancellable? cancellable)  throws IOError.CANCELLED, VError.EVAL_ERROR;
		public abstract string to_string ();
	}
	
	[Immutable]
	public class UserFunction : Function {
		public string[] parameters;
		public Expression body;
		
		public UserFunction (string[]? parameters, Expression body) {
			this.parameters = parameters;
			this.body = body;
		}
		
		public override async Value eval (Scope scope, Value[]? arguments, out Value? error, Cancellable? cancellable) throws IOError.CANCELLED, VError.EVAL_ERROR {
			error = null;
			for (var i=0; i < int.min(parameters.length, arguments.length); i++) {
				scope.set_local (parameters[i], arguments[i]);
			}
			var ret = yield scope.eval (body, cancellable);
			return ret;
		}
		
		public override string to_string () {
			if (parameters.length == 0) {
				return @"{| $body }";
			} else {
				var pars = string.joinv (" ", parameters);
				return @"{ $pars | $body }";
			}
		}
	}
	
	public abstract class Value {
		public abstract double? num { owned get; }
		public abstract bool @bool { get; }
		public abstract string? str { owned get; }
		
		public int? @int {
			owned get {
				var n = num;
				if (num == null) {
					return null;
				}
				return (int) n;
			}
		}
		
		public virtual Value? get_member (string name) { return null; }
		public virtual void set_member (string name, Value? val) { }
		
		public virtual Value? get_instance_member (string name) {
			var v = get_member (name);
			if (v is FunctionValue) {
				// lift to instance method
				var fval = (FunctionValue) v;
				return new FunctionValue (new InstanceMethod (this, fval.func), fval.scope);
			}
			return v;
		}
		
		public abstract bool equal (Value v);
		public abstract string to_string ();
	}
	
	[Immutable]
	public class NullValue : Value {
		public static NullValue _instance;
		
		public static NullValue instance {
			get {
				if (_instance == null) {
					_instance = new NullValue ();
				}
				return _instance;
			}
		}
		
		public override double? num {
			owned get {
				return 0;
			}
		}
		
		public override bool @bool {
			get {
				return false;
			}
		}
		
		public override string? str {
			owned get {
				return null;
			}
		}
		
		public override bool equal (Value v) {
			return this == v;
		}
		
		public override string to_string () {
			return "null";
		}
	}
	
	[Immutable]
	public class StringValue : Value {
		string val;
		
		public StringValue (string val) {
			this.val = val;
		}
		
		public override double? num {
			owned get {
				return double.parse (str);
			}
		}
		
		public override bool @bool {
			get {
				return val != "";
			}
		}
		
		public override string? str {
			owned get {
				return val;
			}
		}
		
		public override bool equal (Value v) {
			if (v is NumValue || v is StringValue) {
				return str == v.str;
			}
			return false;
		}
		
		public override string to_string () {
			return str;
		}
	}
	
	[Immutable]
	public class NumValue : Value {
		double val;
		
		public NumValue (double val) {
			this.val = val;
		}
		
		public NumValue.for_bool (bool b) {
			this.val = b ? 1 : 0;
		}
		
		public override double? num {
			owned get {
				return val;
			}
		}
		
		public override bool @bool {
			get {
				return val != 0;
			}
		}
		
		public override string? str {
			owned get {
				return val.to_string ();
			}
		}
		
		public override bool equal (Value v) {
			if (v is NumValue) {
				return num == v.num;
			} else if (v is StringValue) {
				return str == v.str;
			} else {
				return false;
			}
		}
		
		public override string to_string () {
			return str;
		}
	}
	
	[Immutable]
	public class FunctionValue : Value {
		public Function func;
		public unowned Scope? scope;
		
		public FunctionValue (owned Function func, Scope? scope = null) {
			this.func = (owned) func;
			this.scope = scope;
		}
		
		public override double? num {
			owned get {
				return null;
			}
		}
		
		public override bool @bool {
			get {
				return true;
			}
		}
		
		public override string? str {
			owned get {
				return null;
			}
		}
		
		public override bool equal (Value v) {
			if (v is NumValue || v is StringValue) {
				return str == v.str;
			}
			return false;
		}
		
		public override string to_string () {
			return func.to_string ();
		}
	}
	
	public class InstanceMethod : Function {
		Value self;
		Function func;
		
		public InstanceMethod (Value self, Function func) {
			this.self = self;
			this.func = func;
		}
		
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable? cancellable) throws IOError.CANCELLED, VError.EVAL_ERROR {
			Value[] b = new Value[a.length+1];
			b[0] = self;
			for (var i=0; i < a.length; i++) {
				b[i+1] = a[i];
			}
			return yield func.eval (scope, b, out error, cancellable);
		}
		
		public override string to_string () {
			return func.to_string ();
		}
	}
	
	public class UserObject : Value {
		HashTable<string, Value> members = new HashTable<string, Value> (str_hash, str_equal);
		
		public override Value? get_member (string name) {
			return members[name];
		}
		
		public override void set_member (string name, Value? val) {
			if (val == null) {
				members.remove (name);
			} else {
				members[name] = val;
			}
		}
		
		public override double? num {
			owned get {
				return null;
			}
		}
		
		public override bool @bool {
			get {
				return members.size() > 0;
			}
		}
		
		public override string? str {
			owned get {
				return null;
			}
		}
		
		public override bool equal (Value v) {
		// TODO:
			return this == v;
		}
		
		public override string to_string () {
			var b = new StringBuilder ();
			b.append ("{ ");
			bool first = true;
			foreach (unowned string name in members.get_keys ()) {
				if (!first) {
					b.append (", ");
				}
				b.append ("'");
				b.append (name.escape ("\""));
				b.append ("': ");
				b.append (members[name].to_string ());
				first = false;
			}
			b.append (" }");
			
			return b.str;
		}
	}
	
	public abstract class NativeObject : Value {
		protected class HashTable<string, Value> vtable = null;
		
		class construct {
			vtable = new HashTable<string, Value> (str_hash, str_equal);
		}
		
		public override Value? get_member (string name) {
			var vmemb = vtable[name];
			return vmemb;
		}
		
		public override void set_member (string name, Value? val) {
		}
		
		public override double? num {
			owned get {
				return null;
			}
		}
		
		public override bool @bool {
			get {
				return true;
			}
		}
		
		public override string? str {
			owned get {
				return null;
			}
		}
		
		public override bool equal (Value v) {
		// TODO:
			return this == v;
		}
	}
	
	[Immutable]
	public class Scope {
		public HashTable<string, Value> registers = new HashTable<string, Value> (str_hash, str_equal);
		public Scope? parent;
		public bool passthrough;
		
		public Scope (Scope? parent, bool passthrough) {
			this.parent = parent;
			this.passthrough = passthrough;
		}
		
		public void set_local (string name, Value? val) {
			if (val == null) {
				registers.remove (name);
			} else {
				registers[name] = val;
			}
		}
		
		public Value get_local (string name) {
			return registers[name];
		}
		
		public unowned Value? get (string name) {
			unowned Value? val = registers[name];
			if (val == null && parent != null) {
				val = parent[name];
			}
			return val;
		}
		
		public bool contains (string name) {
			if (name in registers) {
				return true;
			}
			if (parent != null) {
				return name in parent;
			}
			return false;
		}
		
		public void set (string name, Value val) {
			if (parent == null) {
				// ignore passthrough
				registers[name] = val;
			} else {
				if (!passthrough && (name in registers || !(name in parent))) {
					registers[name] = val;
				} else {
					parent[name] = val;
				}
			}
		}
		
		public async Value eval (Expression expr, Cancellable? cancellable) throws IOError.CANCELLED, VError.EVAL_ERROR {
			var ev = new EvalVisitor ();
			var ret = yield ev.eval (this, expr, cancellable);
			return ret;
		}
		
		public async Value eval_string (string sexpr, Cancellable? cancellable) throws IOError.CANCELLED, VError {
			var parser = new Vade.Parser.for_string (sexpr);
			var expr = parser.parse_expression ();
			return yield eval (expr, cancellable);
		}
		
		public async Value eval_embedded (string sexpr, Cancellable? cancellable) throws IOError.CANCELLED, VError {
			var parser = new Vade.Parser.for_string (sexpr);
			var expr = parser.parse_embedded ();
			return yield eval (expr, cancellable);
		}
		
		public Value eval_sync (Expression expr) throws Error {
			Value ret = null;
			Error err = null;
			
			var ctx = MainContext.default ();
			var loop = new MainLoop (ctx, false);
			eval.begin (expr, new Cancellable(), (s,r) => {
					try {
						ret = eval.end (r);
					} catch (Error e) {
						err = e;
					} finally {
						loop.quit ();
					}
			});
			loop.run ();
			
			if (err != null) {
				throw err;
			}
			
			return ret;
		}
	}
	
	public errordomain VError {
		SYNTAX_ERROR,
		SEMANTIC_ERROR,
		EVAL_ERROR
	}
}
