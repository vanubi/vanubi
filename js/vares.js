(function ($,_) {
		Vares = {};
		Vares.root = ".";
		
		Vares.pattern_match = function (pattern, haystack) {
			var rank = 0;
			var n = pattern.length;
			var m = haystack.length;
			var j = 0;
			for (var i=0; i < n; i++) {
				var c = pattern[i];
				var found = false;
				for (; j < m; j++) {
					if (c.toLowerCase () == haystack[j].toLowerCase ()) {
						found = true;
						break;
					}
					rank += j+100;
				}
				if (!found) {
					// no match
					return -1;
				}
				j++;
			}
			rank += m-j;
			return rank;
		};
		
		Vares.Index = function () {
			this.documents = [];
		};
		
		Vares.Index.stopwords = ["a", "about", "across", "after", "afterwards", "again", "against", "all", "almost", "alone", "along", "already", "also","although","always","am","among", "amongst",
								 "amoungst", "amount",  "an", "and", "another", "any","anyhow","anyone","anything","anyway", "anywhere", "are", "around", "as",  "at", "back","be","became", "because","become","becomes", "becoming", "been", "before", "beforehand", "behind", "being", "below", "beside", "besides", "between", "beyond", "bill",
								 "both", "bottom","but", "by", "call", "can", "cannot", "cant", "co", "con", "could", "couldnt", "cry", "de", "describe", "detail", "do", "done", "down", "due", "during", "each", "eg", "eight", "either", "eleven","else", "elsewhere", "empty", "enough", "etc", "even", "ever", "every", "everyone", "everything",
								 "everywhere", "except", "few", "fifteen", "fify", "fill", "fire", "first", "five", "for", "former", "formerly", "forty", "found", "four", "from", "front", "full", "further", "get", "give", "go", "had", "has", "hasnt", "have", "he", "hence", "her", "here", "hereafter", "hereby", "herein", "hereupon", "hers",
								 "herself", "him", "himself", "his", "how", "however", "hundred", "ie", "if", "in", "inc", "indeed", "interest", "into", "is", "it", "its", "itself", "keep", "last", "latter",
								 "latterly", "least", "less", "ltd", "made", "many", "may", "me", "meanwhile", "might", "mill", "mine", "more", "moreover", "most", "mostly", "move", "much", "must", "my", "myself", "name", "namely", "neither", "never", "nevertheless", "nine", "no", "nobody", "none", "noone", "nor", "not", "nothing",
								 "now", "nowhere", "of", "off", "often", "on", "once", "one", "only", "onto", "or", "other", "others", "otherwise", "our", "ours", "ourselves", "out", "over", "own","part", "per", "perhaps", "please", "put", "rather", "re", "same", "see", "seem", "seemed", "seeming", "seems", "serious", "several", "she",
								 "should", "show", "side", "since", "sincere", "six", "sixty", "so", "some", "somehow", "someone", "something", "sometime", "sometimes", "somewhere", "still", "such", "take", "ten", "than", "that", "the", "their", "them", "themselves", "then", "thence", "there", "thereafter", "thereby", "therefore", "therein", "thereupon", "these", "they", "thickv", "thin", "third", "this", "those", "though", "three", "through", "throughout", "thru", "thus",
								 "to", "together", "too", "top", "toward", "towards", "twelve", "twenty", "two", "un", "under", "until", "up", "upon", "us", "very", "via", "was", "we", "well", "were", "what", "whatever", "when", "whence", "whenever", "where", "whereafter", "whereas", "whereby", "wherein", "whereupon", "wherever", "whether",
								 "which", "while", "whither", "who", "whoever", "whole", "whom", "whose", "why", "will", "with", "within", "without", "would", "yet", "you", "your", "yours", "yourself", "yourselves", "the"];
		
		Vares.Index.prototype.index = function (doc, keywords) {
			this.documents.push ({doc: doc, keywords: keywords});
		};
		
		Vares.Index.prototype.search = function (query) {
			var result = [];
			
			var words = query.split (" ");
			for (var i=0; i < this.documents.length; i++) {
				var idoc = this.documents[i];
				var score = 0;
				
				var has_match = false;
				var has_mismatch = false;
				for (var j=0; j < words.length; j++) {
					var qword = words[j].trim ();
					if (qword.length == 0 || (words.length > 1 && Vares.Index.stopwords.indexOf (qword) >= 0)) {
						continue;
					}
					
					var match = false;
					for (var k=0; k < idoc.keywords.length; k++) {
						var dword = idoc.keywords[k];
						var tmp = Vares.pattern_match (qword, dword);
						if (tmp >= 0) {
							match = true;
							score += tmp;
							break;
						}
					}
					
					if (match) {
						has_match = true;
					} else {
						has_mismatch = true;
					}
				}
				
				if (has_match) {
					if (has_mismatch) {
						score = Number.MAX_VALUE;
					}
					result.push ({doc: idoc.doc, score: score});
				}
			}
			
			result.sort (function (a,b) { return a.score-b.score; });
			return _.map (result, function (e) { return e.doc; });
		};
		
		Vares.fetch_topic_previews = function () {
			return $.ajax ({url: Vares.root+"/topics.html", dataType: "text"});
		};
		
		Vares.fetch_topics = function () {
			return $.ajax ({url: Vares.root+"/doc.html", dataType: "text"});
		};
		
		Vares.index_topic_previews = function (idx) {
			var topics = $(".topic-preview");
			for (var i=0; i < topics.length; i++) {
				var topic = topics[i];
				var keywords = $.grep ($(topic).attr("data-keywords").split (" "), _.identity);
				idx.index (topic, keywords);
			}
		};
		
		Vares.get_all_topic_previews = function () {
			return _.map (Vares.docs_index.documents, function (d) { return d.doc; });
		};
		
		Vares.get_topic_preview_by_id = function (id) {
			return _.find (Vares.get_all_topic_previews (), function (d) { return $(d).attr ("data-id") == id; });
		};
		
		Vares.set_displayed_topic_previews = function (topics) {
			var old_ids = $(".topic-preview").map (function (_,e) { return $(e).attr("data-id"); });
			var new_ids = _.map (topics, function (e) { return $(e).attr("data-id"); });
			var to_hide = _.map (_.difference (old_ids, new_ids), Vares.get_topic_preview_by_id);
			var to_show = _.map (_.difference (new_ids, old_ids), Vares.get_topic_preview_by_id);
			
			$("#topic-previews").html("");
			$("#topic-previews").append (to_show);
		};
		
		Vares.set_topic_previews_html = function (html) {
			$("#topic-previews").html (html);
			$(document).on ("click", ".topic-preview", function (p) { Vares.open_topic ($(this).attr("data-id")); });
			return html;
		};
		
		Vares.open_topic = function (id) {
			$("#topic-previews").slideUp ();
			$("#topics div[data-id='"+id+"']").fadeIn (200);
		};
		
		Vares.open_topic_previews = function () {
			$("#topics div:visible").fadeOut (200);
			$("#topic-previews").slideDown ();
		}
		
		Vares.set_topics_html = function (html) {
			$("#topics").html (html);
			return html;
		};
		
		Vares.get_search_query = function () {
			return $("#search input").val ();
		};
		
		Vares.search_changed = function () {
			Vares.open_topic_previews ();
			var query = Vares.get_search_query ();
			var matches = Vares.docs_index.search (query);
			if (query.trim() == "") {
				matches = Vares.get_all_topic_previews ();
			}
			Vares.set_displayed_topic_previews (matches);
			return false;
		};
		
		Vares.init = function () {
			Vares.docs_index = new Vares.Index ();
			Vares.fetch_topic_previews().then (Vares.set_topic_previews_html).then (_.partial (Vares.index_topic_previews, Vares.docs_index));
			Vares.fetch_topics().then (Vares.set_topics_html);
			$("#search input").keyup (Vares.search_changed).on ('changed', Vares.search_changed);
			$("#search form").submit (Vares.search_changed);
		};
} ($,_));

Vares.init();