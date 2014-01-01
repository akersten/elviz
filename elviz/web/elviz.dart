
//XXX: State for certain actions - right now things will break if the syllable
//button action is triggered before things are actually set up (CSS will prevent
//this for normal users, but if someone starts poking it it'll break... Suppose
//that's a layer-8 error though).

import 'dart:html';
import 'dart:async';
import 'dart:collection';
import 'dart:js' as js;
import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:utf/utf.dart' as utf;

Element defaultEventContainer = querySelector("#replayTargetContainer");
String lastColorString = "#FFF";

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
  

  Map toJson();
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
    SpanElement el = new SpanElement();
    el.text = text;
    el.style.color = lastColorString;
    container.children.add(el);
    
    //Scroll to the bottom of that container too...
    js.context.callMethod('di_bottom', []);
  }
  
  Map toJson() {
    return {"ti": this.showtime, "ty": "st", "tx": this.text};
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
  
  Map toJson() {   
    return {"ti": this.showtime, "ty": "cc"};
  }
}

class ColorChangeEvent extends ElvizEvent {
  String colorString;
  ColorChangeEvent(var showtime, String colorString) : super(showtime) {
    this.colorString = colorString;
  }
  
  void execute() {
    lastColorString = this.colorString;
  }
  
  Map toJson() {
    return {"ti": this.showtime, "ty": "co", "cs": this.colorString};
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
  checkForSharesAndAct();
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
    js.context.callMethod('di_play', []);
    
    return;
  }
  
  //Take this item off the displayed list.
  Element ll = querySelector("#lyricsList");
  ll.children.removeAt(0);
 
  //Add each syllable of the word as a display text event in the event queue.
  List<String> syllables = tokens[syllableClickIdx].split(new RegExp(r"\*+"));
  

  //If it's a color change, add a color change event instead.
  if (syllables[0].startsWith(new RegExp(r"#"))) {
    eventQueue.add(new ColorChangeEvent(stopwatch.elapsedMilliseconds, syllables[0]));
    syllableClickIdx += 1;
    return;
  }
  
  //If it's a single syllable word, this will just add it to the event queue.
  //Otherwise it'll add the correct part because of our internal-word indexing.
  //We want spaces at the end of every word.
  eventQueue.add(new ShowTextEvent(stopwatch.elapsedMilliseconds,
                  syllables[syllableClickIdx2] +
                  (syllableClickIdx2 == syllables.length - 1 ? " " : ""),
                  defaultEventContainer));
  
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
    
    //Generate the share link by serializing the event queue.
    TextAreaElement txta = querySelector("#shareLink");
    txta.value = serializeEventQueue();

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
  js.context.callMethod('di_play', []);
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
  //TODO: XXX: Fudge factor of 650ms... Need to sync better...
  while (nextEvent.showtime <= stopwatch.elapsedMilliseconds + 650) {
    backupQueue.add(eventQueue.removeFirst()); //For re-use.
    
    nextEvent.execute();
    
    if (eventQueue.isEmpty) {
      break;
    }
    nextEvent = eventQueue.first;
  }
}

String lastVideoID = "";

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
   
   lastVideoID = tokens[1];
   //Load the new video by calling the JS method for the YT API.
   js.context.callMethod('di_newYTURL', [lastVideoID]);
}


/**
 * This is for the share links. The way we'll do this is, for each event in the
 * event queue, 
 */
String serializeEventQueue() {
  String shareLink = lastVideoID + "::";
  buildShareLink(ElvizEvent) {
    shareLink += JSON.encode(ElvizEvent) + "::";
  }
  eventQueue.forEach(buildShareLink);
  
  //The link now looks something like this:
  //videoID::{"ti":0,"ty":"cc"}::{"ti":1105,"ty":"st","tx":"A "}::{"ti":1460,"ty":"st","tx":"Word"}
  
  //base64 it for transmission.
  return window.location.href + "#_" +
          crypto.CryptoUtils.bytesToBase64(utf.encodeUtf8(shareLink));
}


/**
 * We'll have to reconstruct events and put them in the event queue here.
 */
void deserializeEventQueueAndPlay(String base64stuff) {
  //First, de-base64 it.
  String workingOnIt = utf.decodeUtf8(
                          crypto.CryptoUtils.base64StringToBytes(base64stuff));
  
  //Now split it into tokens - we'll have to push them on to the event queue
  //as new event objects based on what event type ('ti') they are. Recall the
  //JSON format:
  //{"ti":0,"ty":"cc"}::{"ti":1105,"ty":"st","tx":"A "}::{"ti":1460,"ty":"st","tx":"Word"}
  List<String> eventList = workingOnIt.split(new RegExp(r"::"));
  if (eventList.last.length == 0) { //Extra due to trailing ::
    eventList.removeLast();
  }
  
  //Clear the event queue and then populate it with the new events.
  lastVideoID = eventList.first;
  eventList.removeAt(0);
  
  /* We will _GUESS_ that the container is the default during reconstruction
   * to save on share link size...
   */
  generateEventAndPush(String eventJSON) {
    ElvizEvent thisEvent;
    
    //Depending on the type of event, switch to see which implementing class
    //needs to be reconstituted into the polymorphic event container.
    Map decodedMap = JSON.decode(eventJSON);
    switch(decodedMap["ty"]) {
      case "cc":
        thisEvent = new ClearChildrenEvent(decodedMap["ti"], defaultEventContainer);
        break;
      case "st":
        thisEvent = new ShowTextEvent(decodedMap["ti"], decodedMap["tx"], defaultEventContainer);
        break;
      case "co":
        thisEvent = new ColorChangeEvent(decodedMap["ti"], decodedMap["cs"]);
        break;
      default:
        print("Unknown event type: ${decodedMap['ty']}");
    }
    
    eventQueue.add(thisEvent);
  }
  
  eventList.forEach(generateEventAndPush);
  
  //It should be loaded since we'll check the data after the # only once the
  //callback for YT load has finished.
  js.context.callMethod('di_newYTURL', [lastVideoID]);
  
  //Now, send us to the third screen and be ready to play!
  querySelector("#stage2").style.display = "none";
  querySelector("#stage3").style.display = "block";
  
  //Hide the share textfield for now... Could just populate it with the URL
  //though.
  TextAreaElement txta = querySelector("#shareLink");
  //txta.value = serializeEventQueue();
  txta.style.display = "none";
}

/**
 * Basically, the problem with everything is it's async. In order to check if
 * we've got a shared hashtag, we need to wait until the player becomes ready.
 * We check this by continuing to probe a variable which gets set in JS when the
 * player is ready, and after that sentinel is true, then check if there's share
 * hash content.
 */
void checkForSharesAndAct() {
  //Set a timer to keep doing this until it's ready.
  chkFrShrsTimer =  new Timer.periodic(const Duration(milliseconds: 45),
                                        chkFrShrsWorker);  
}

Timer chkFrShrsTimer;

/**
 * Timer periodical for `checkForSharesAndAct`, see its documentation above.
 */
void chkFrShrsWorker(Timer t) {
  if (js.context['ytready'].toString() == "false") {
    //Wait...
  } else {
    //Ready! Check if the base64 hashtag is what we want...
    querySelector("#loader").style.display = "none";
    if (window.location.hash.length > 2 && window.location.hash.substring(1, 2) == "_") {
      deserializeEventQueueAndPlay(window.location.hash.substring(2));
    } else {
      //If not, just make stage1 visible instead...
      querySelector("#stage1").style.display = "block";
    }
    
    t.cancel();
  }
}
