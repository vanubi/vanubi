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

namespace Vanubi {
	public class SearchResultItem<D> {
		public D doc;
		public int score;
		
		public SearchResultItem (D doc, int score) {
			this.doc = doc;
			this.score = score;
		}
	}

	public interface SearchIndex<D> {
		public abstract string name { get; }
		public abstract void index_document (D doc);
		public abstract List<SearchResultItem<D>> search (string query);
	}

	public class StringSearchDocument {
		public string name;
		public string[] fields;

		public void index (StringSearchIndex idx) {
			idx.add_occurrence (name, this);
			foreach (unowned string field in fields) {
				string[] words = field.split (" ");
				foreach (unowned string word in words) {
					idx.add_occurrence (word, this);
				}
			}
		}
		
		public uint hash () {
			return str_hash (name);
		}
		
		public bool equal (StringSearchDocument other) {
			return name == other.name;
		}
	}

	public class StringSearchIndex : SearchIndex<StringSearchDocument> {
		public string name {
			get { return this._name; }
		}
		
		private string _name;

		HashTable<string, HashTable<StringSearchDocument, StringSearchDocument>> index = new HashTable<string, HashTable<StringSearchDocument, StringSearchDocument>> (str_hash, str_equal);
		HashTable<string, string> synonyms = new HashTable<string, string> (str_hash, str_equal);

		public StringSearchIndex (string name) {
			this._name = name;
		}

		public void add_occurrence (string word, StringSearchDocument doc) {
			var table = index[word];
			if (table == null) {
				table = new HashTable<StringSearchDocument, StringSearchDocument> (StringSearchDocument.hash, StringSearchDocument.equal);
				index[word] = table;
			}
			table[doc] = doc;
		}
		
		public void index_document (StringSearchDocument doc) {
			doc.index (this);
		}
		
		public List<SearchResultItem<StringSearchDocument>> search (string query) {
			// TODO: sort by score, distinct
			var result = new List<unowned SearchResultItem<unowned StringSearchDocument>>();
			string[] words = query.split (" ");
			foreach (unowned string word in words) {
				var table = index[word];
				if (table != null) {
					var keys = table.get_keys ();
					foreach (var doc in keys) {
						result.append (new SearchResultItem<StringSearchDocument> (doc, 0));
					}
				}
			}
			return result;
		}
	}
}
