import 'dart:html';
import 'dart:async';
import 'dart:collection';

/**
 * Events will be used to drive the show. Every event has an appearance time
 * associated with it, and will be triggered when that amount of time has
 * elapsed.
 */
abstract class ElvizEvent {
  var showtime = 0;
  
  ElvisEvent(var showtime) {
    this.showtime = showtime;
  }
}

class ShowTextEvent extends ElvizEvent {
  String text;
  
  ShowTextEvent(var showtime, String text) : super(showtime) {
    this.text = text;
  }
}

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

//The way this will work is that we'll start with an array of "tokens". Some
//of these tokens might be multi-syllable (i.e. have *'s in them), that's ok.
//We'll use the length of their respective innerTimecues list to track them as
//we iterate through the symbols and record timecues. After recording each
//timestamp, the event queue will be built with the ends of words trailed by a
//space (the event queue will be a used for other things too, but these events
//will just be "display n-characters" events).
List<String> tokens = [];
//List<int> timecues = [];
//List<List<int>> innerTimecues = [];
List<int> syllableCounts = [];
Queue<ElvizEvent> eventQueue = new Queue<ElvizEvent>();

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
  
  tokens.add("~fin~"); //Need a final token which isn't multi-syllable.
  tokens.forEach(addToTheLyricsList);

  //Switch over to the second stage interface...
  querySelector("#stage1").style.display = "none";
  querySelector("#stage2").style.display = "block";
}



Stopwatch stopwatch = new Stopwatch();
Timer domUpdateTimer;

Element durationElement = querySelector('#cuetimer');
void doDomUpdate(Timer useless) {
  durationElement.innerHtml = "${stopwatch.elapsedMilliseconds}";
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
    stopwatch.start();
    domUpdateTimer = new Timer.periodic(const Duration(milliseconds: 150),
                                          doDomUpdate);
    syllableClickIdx = 0;
    return;
  }
  
  //Stop the timer after the last syllable happens.
  if (syllableClickIdx == tokens.length - 1) {
    stopwatch.stop();
    
    //TODO: Build the event chain from the timecues.
    return;
  }
  
  if (innerTimecues[syllableClickIdx] == null) {
    //Single syllable word.
    timecues[syllableClickIdx] = 
    syllableClickIdx++;
  }else {
    
  }
  
  
}