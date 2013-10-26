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
	public abstract class SearchDocument {
		public abstract uint hash ();
		public abstract bool equal (SearchDocument o);
	}

	/* Documents with a unique name */
	public class NamedSearchDocument : SearchDocument {
		public string name { get; private set; }

		public NamedSearchDocument (string name) {
			this.name = name;
		}

		public override uint hash () {
			return name.hash ();
		}
		
		public override bool equal (SearchDocument other) {
			if (other == null) {
				return false;
			}
			return name == ((StringSearchDocument) other).name;
		}
	}

	public class SearchResultItem<D> {
		public D doc { get; private set; }
		public int score { get; private set; }
		
		public SearchResultItem (D doc, int score) {
			this.doc = doc;
			this.score = score;
		}
	}

	public interface SearchIndex<D> {
		public abstract void index_document (D doc);
		public abstract List<SearchResultItem<D>> search (string query);
	}

	public class StringSearchDocument : NamedSearchDocument {
		public string[] fields;

		public StringSearchDocument (string name, owned string[] fields) {
			base (name);
			this.fields = (owned) fields;
		}

		public void index (StringSearchIndex idx) {
			idx.add_occurrence (name, this);
			foreach (unowned string field in fields) {
				string[] words = field.split (" ");
				foreach (unowned string word in words) {
					idx.add_occurrence (word, this);
				}
			}
		}
		
	}

	public class StringSearchIndex : SearchIndex<StringSearchDocument> {
		HashTable<string, HashTable<SearchDocument, SearchDocument>> index = new HashTable<string, HashTable<SearchDocument, SearchDocument>> (str_hash, str_equal);
		public HashTable<string, string> synonyms = new HashTable<string, string> (str_hash, str_equal);

		public void add_occurrence (string word, StringSearchDocument doc) {
			// TODO: stemming
			unowned string syn = synonyms[word];
			if (syn != null) {
				word = syn;
			}
			var table = index[word];
			if (table == null) {
				table = new HashTable<SearchDocument, SearchDocument> (SearchDocument.hash, SearchDocument.equal);
				index[word] = table;
			}
			table[doc] = doc;
		}
		
		public void index_document (StringSearchDocument doc) {
			doc.index (this);
		}
		
		public List<SearchResultItem<SearchDocument>> search (string query) {
			// TODO: sort by score, distinct, stemming
			var hashed = new HashTable<SearchDocument, SearchResultItem> (SearchDocument.hash, SearchDocument.equal);
			string[] words = query.split (" ");
			foreach (unowned string word in words) {
				unowned string syn = synonyms[word];
				if (syn != null) {
					word = syn;
				}
				var table = index[word];
				if (table != null) {
					var keys = table.get_keys ();
					foreach (var doc in keys) {
						hashed[doc] = new SearchResultItem<SearchDocument> (doc, 0);
					}
				}
			}
			return hashed.get_values ();
		}
	}
}
