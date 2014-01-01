
//XXX: State for certain actions - right now things will break if the syllable
//button action is triggered before things are actually set up (CSS will prevent
//this for normal users, but if someone starts poking it it'll break... Suppose
//that's a layer-8 error though).

import 'dart:html';
import 'dart:async';
import 'dart:collection';
import 'dart:js' as js;

/**
 * Events will be used to drive the show. Every event has an appearance time
 * associated with it, and will be triggered when that amount of time has
 * elapsed.
 */
abstract class ElvizEvent {
  var showtime = 0;
  
  ElvizEvent(var showtime) {
    this.showtime = showtime;
  }
  
  void execute();
}

class ShowTextEvent extends ElvizEvent {
  String text;
  Element container;  //Where the text shown should be inserted.
  
  ShowTextEvent(var showtime, String text, Element container) : super(showtime) {
    this.text = text;
    this.container = container;
  }
  
  /**
   * Put this text on-screen.
   */
  void execute() {
    container.children.add(new SpanElement()..text = text);
    
    //Scroll to the bottom of that container too...
    js.context.callMethod('di_bottom', []);
  }
}

class ClearChildrenEvent extends ElvizEvent {
  Element container;
  
  ClearChildrenEvent(var showtime, Element container): super(showtime) {
    this.container = container;
  }
  
  /**
   * Clean up the children of whatever container is referenced.
   */
  void execute() {
    container.children = [];
  }
}

/**
 * Set up actions for page elements.
 */
void main() { 
  querySelector("#tapCuesLink")
    ..onClick.listen(tapCues);
  querySelector("#syllableButton")
    ..onClick.listen(syllableClick);
  querySelector("#ytinput")
  ..onInput.listen(ytinputChange);
  querySelector("#replayButton")
    ..onClick.listen(replayClick);
}

//The way this will work is that we'll start with an array of "tokens". Some
//of these tokens might be multi-syllable (i.e. have *'s in them), that's ok.
//We'll parse them out and track how many syllables each token has. Then, during
//timecue input or rendering we can split the tokens into multi-syllable parts.
List<String> tokens = [];
List<int> syllableCounts = [];

//Eventually, these tokens get turned into events in this event queue (with
//corresponding text and appearance times). Multi-syllable words are simply
//text events without a space at the end, so the next syllable is attached ;)
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
  
  var i = 0;
  
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
    
    syllableCounts.add(j);
    i++;
  }
  tokens.add("~"); //Need a final token which isn't multi-syllable.
  syllableCounts.add(1);
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
  
  //On the first click, start the timer, and add a clear-children event to
  //clean up anything we left behind.
  if (syllableClickIdx == -1) {
    stopwatch.start();
    domUpdateTimer = new Timer.periodic(const Duration(milliseconds: 150),
                                          doDomUpdate);
    syllableClickIdx = 0;
    eventQueue.add(new ClearChildrenEvent(0,
                                      querySelector("#replayTargetContainer")));
    
    //Start playing the actual video so we can track along...
    js.context.callMethod('di_play', [tokens[1]]);
    
    return;
  }
  
  //Take this item off the displayed list.
  Element ll = querySelector("#lyricsList");
  ll.children.removeAt(0);
 
  //Add each syllable of the word as a display text event in the event queue.
  List<String> syllables = tokens[syllableClickIdx].split(new RegExp(r"\*+"));
  
  //If it's a single syllable word, this will just add it to the event queue.
  //Otherwise it'll add the correct part because of our internal-word indexing.
  //We want spaces at the end of every word.
  eventQueue.add(new ShowTextEvent(stopwatch.elapsedMilliseconds,
                  syllables[syllableClickIdx2] +
                  (syllableClickIdx2 == syllables.length - 1 ? " " : ""),
                  querySelector("#replayTargetContainer")));
  
  //Not done with the current word yet?
  if (syllableClickIdx2 != syllables.length - 1) {
    //Can't possibly be done (remember, single syllable end token), so increment
    //and return.
    syllableClickIdx2 += 1;
    return;
  }
  syllableClickIdx2 = 0; //Reset for the next multi-syllable word.
  
  //Stop the timer after the last syllable happens.
  if (syllableClickIdx == tokens.length - 1) {
    querySelector("#syllableButton").setAttribute("disabled", "true");
 
    //Switch to replay view with a share URL and other fun stuff.
    
    //Generate the share link by serializing (in some manner) the event queue.
    
    querySelector("#stage2").style.display = "none";
    querySelector("#stage3").style.display = "block";
    
    stopwatch.stop();
  }
  
  syllableClickIdx++;
}

//Replay section

//Basically, the way replay works is that we have a granularity on a timer; each
//period, check if the head of the queue is earlier than the elapsed time; if it
//is, do that event, and continue doing events until the head of the queue is
//beyond the current time. Adjust the milliseconds here for more accurate event
//scheduling at the cost of CPU and potentially below browser JS precision.
Timer replayTimer;
void replayClick(MouseEvent event) {
  stopwatch.reset();
  stopwatch.start();
  replayTimer =  new Timer.periodic(const Duration(milliseconds: 45),
                                      doReplayUpdate);
  querySelector("#stage3").style.display = "none";
  querySelector("#stage4").style.display = "block";
  
  //Yeah, go!
  js.context.callMethod('di_play', [tokens[1]]);
}

Queue<ElvizEvent> backupQueue = new Queue<ElvizEvent>();
/**
 * Check for events in the queue which need to be processed. Stop the timers if
 * the queue is empty.
 */
void doReplayUpdate(Timer t) {
  if (eventQueue.isEmpty) {
    stopwatch.stop();
    t.cancel();
    eventQueue.addAll(backupQueue); //Add them back again.
    querySelector("#stage4").style.display = "none";
    querySelector("#stage3").style.display = "block";
    return;
  }
  
  ElvizEvent nextEvent = eventQueue.first;
  while (nextEvent.showtime <= stopwatch.elapsedMilliseconds) {
    backupQueue.add(eventQueue.removeFirst()); //For re-use.
    
    nextEvent.execute();
    
    if (eventQueue.isEmpty) {
      break;
    }
    nextEvent = eventQueue.first;
  }
}

/**
 * The text has changed in the YT URL input field, see if it's valid and if so
 * extract the video ID.
 */
void ytinputChange(Event event) {
   //XXX: No validation yet, just display button after input changes...
   querySelector("#tapCuesContainer").style.display = "block";
   querySelector("#ytplayerContainer").style.display = "block";
       
   InputElement e = querySelector("#ytinput");
   String url = e.value;
   List<String> tokens = url.split(new RegExp(r"\\?v=")); //Lazy but whatever.
   
   if (tokens.length != 2) {
     querySelector("#yterror").innerHtml = "Not a valid YT URL...";
     return;
   } else {
     querySelector("#yterror").innerHtml = "";
   }
   
   //Load the new video by calling the JS method for the YT API.
   js.context.callMethod('di_newYTURL', [tokens[1]]);
}