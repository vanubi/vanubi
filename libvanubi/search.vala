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

	public class SearchResultItem {
		public SearchDocument doc { get; private set; }
		public int score { get; private set; }
		
		public SearchResultItem (SearchDocument doc, int score) {
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
		const string[] stopwords = {"a", "about", "across", "after", "afterwards", "again", "against", "all", "almost", "alone", "along", "already", "also","although","always","am","among", "amongst", "amoungst", "amount",  "an", "and", "another", "any","anyhow","anyone","anything","anyway", "anywhere", "are", "around", "as",  "at", "back","be","became", "because","become","becomes", "becoming", "been", "before", "beforehand", "behind", "being", "below", "beside", "besides", "between", "beyond", "bill", "both", "bottom","but", "by", "call", "can", "cannot", "cant", "co", "con", "could", "couldnt", "cry", "de", "describe", "detail", "do", "done", "down", "due", "during", "each", "eg", "eight", "either", "eleven","else", "elsewhere", "empty", "enough", "etc", "even", "ever", "every", "everyone", "everything", "everywhere", "except", "few", "fifteen", "fify", "fill", "find", "fire", "first", "five", "for", "former", "formerly", "forty", "found", "four", "from", "front", "full", "further", "get", "give", "go", "had", "has", "hasnt", "have", "he", "hence", "her", "here", "hereafter", "hereby", "herein", "hereupon", "hers", "herself", "him", "himself", "his", "how", "however", "hundred", "ie", "if", "in", "inc", "indeed", "interest", "into", "is", "it", "its", "itself", "keep", "last", "latter", "latterly", "least", "less", "ltd", "made", "many", "may", "me", "meanwhile", "might", "mill", "mine", "more", "moreover", "most", "mostly", "move", "much", "must", "my", "myself", "name", "namely", "neither", "never", "nevertheless", "nine", "no", "nobody", "none", "noone", "nor", "not", "nothing", "now", "nowhere", "of", "off", "often", "on", "once", "one", "only", "onto", "or", "other", "others", "otherwise", "our", "ours", "ourselves", "out", "over", "own","part", "per", "perhaps", "please", "put", "rather", "re", "same", "see", "seem", "seemed", "seeming", "seems", "serious", "several", "she", "should", "show", "side", "since", "sincere", "six", "sixty", "so", "some", "somehow", "someone", "something", "sometime", "sometimes", "somewhere", "still", "such", "system", "take", "ten", "than", "that", "the", "their", "them", "themselves", "then", "thence", "there", "thereafter", "thereby", "therefore", "therein", "thereupon", "these", "they", "thickv", "thin", "third", "this", "those", "though", "three", "through", "throughout", "thru", "thus", "to", "together", "too", "top", "toward", "towards", "twelve", "twenty", "two", "un", "under", "until", "up", "upon", "us", "very", "via", "was", "we", "well", "were", "what", "whatever", "when", "whence", "whenever", "where", "whereafter", "whereas", "whereby", "wherein", "whereupon", "wherever", "whether", "which", "while", "whither", "who", "whoever", "whole", "whom", "whose", "why", "will", "with", "within", "without", "would", "yet", "you", "your", "yours", "yourself", "yourselves", "the"};

		public StringSearchDocument (string name, owned string[] fields) {
			base (name);
			this.fields = (owned) fields;
		}

		public void index (StringSearchIndex idx) {
			idx.add_occurrence (name, this);
			var namesplit = name.split ("-");
			foreach (unowned string n in namesplit) {
				idx.add_occurrence (n, this);
			}

			foreach (unowned string field in fields) {
				// stop words, stemming
				var cleaned = field.down().replace(",", " ").replace(".", " ").replace("/", " ").replace("-", " ");
				string[] words = cleaned.split (" ");
				foreach (unowned string word in words) {
					if (!(word in stopwords)) {
						idx.add_occurrence (word, this);
					}
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
		
		public List<SearchResultItem> search (string query) {
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
					foreach (var doc in table.get_values ()) {
						hashed[doc] = new SearchResultItem (doc, 0);
						assert (hashed[doc].doc == doc);
						assert (hashed[doc].doc != null);
					}
				}
			}
			var list = new List<SearchResultItem> ();
			foreach (var doc in hashed.get_values ()) {
				list.append (doc);
			}
			return list;
		}
	}
}
