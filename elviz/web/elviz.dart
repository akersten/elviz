import 'dart:html';

//XXX: State for certain actions - right now things will break if the syllable
//button action is triggered before things are actually set up (CSS will prevent
//this for normal users, but if someone starts poking it it'll break... Suppose
//that's a layer-8 error though).

/**
 * Set up actions for page elements.
 */
void main() {
  querySelector("#tapCuesLink")
    ..onClick.listen(tapCues);
  querySelector("#syllableButton")
    ..onClick.listen(syllableClick);
}

List<String> tokens = [];
List<int> timecues = [];
List<List<int>> innerTimecues = [];

void tapCues(MouseEvent event) {
  //Transform the textarea content into an array of strings delimited by space,
  //tab, and newline to find all the word tokens. We'll deal with the asterisks
  //later, during the rendering, and leave them in the word for now (to be
  //displayed with dashes during the timecue input phase).
  TextAreaElement txta = querySelector("#lyricsInputBox");
  //Get rid of any decorative verse slashes before doing this though...
  txta.value = txta.value.replaceAll(new RegExp(r"/"), "\n");
  tokens = txta.value.split(new RegExp(r"[\t\n ]+")); //Fix double+ spacing too.
  
  //Generate the HTML for the timecue input list...
  Element ll = querySelector("#lyricsList");
  ll.children = [];
  
  var tmpi = 0;
  /**
   * Add this item to the lyrics list (for timecue input). We'll also discover
   * here if a word has multiple syllables, and set up the appropriate array
   * structure for those words.
   */
  addToTheLyricsList(String token) {
    Element ll = querySelector("#lyricsList");
    List<String> syllables = [];
    
    //If the user is silly and the token is lieterally just asterisks... Well,
    //they'll be left with an empty item in the list - don't want to take it out
    //though, it'll mess with our indexing.
    syllables = token.split(new RegExp(r"\*+"));
    
    innerTimecues.add(null);

    /**
     * Add each syllable to the list element; don't append a dash if we're at
     * the last syllable.
     */
    var j = 0;
    LIAdd(String text) {
      ll.children.add(new LIElement()..text = text +
          (j == syllables.length - 1 ? "" : "-"));
      j++;
    }
    syllables.forEach(LIAdd);
    
    //If it happened to be a multi-syllable word, then we'll need to set up the
    //inner-word timecue list.
    if (syllables.length != 1) {
      innerTimecues[tmpi] = new List<int>(syllables.length);
    }
    
    tmpi++;
  }
  
  tokens.forEach(addToTheLyricsList);
  
  //Switch over to the second stage interface...
  querySelector("#stage1").style.display = "none";
  querySelector("#stage2").style.display = "block";
}


var syllableClickIdx = -1;
var syllableClickIdx2 = 0;

/**
 * Triggered by the user hitting the syllable button. Add the syllable timestamp
 * to the list of timecues, unless the index has a non-null value in the
 * innerTimecues list, in which case set its values (using the 2nd index above).  
 */
void syllableClick(MouseEvent event) {
  //XXX: Does mouseClick event also capture spacebar-ing it for every browser?
  
  //On the first click, start the timer.
  if (syllableClickIdx == -1) {
  }
}