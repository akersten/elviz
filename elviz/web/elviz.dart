import 'dart:html';

void main() {
  querySelector("#tapCuesLink")
    ..onClick.listen(tapCues);
}


var tokens = [];
var timecues = []; //

void printThing(var thinga) {
  print(thinga);
}
void tapCues(MouseEvent event) {
  //Transform the textarea content into an array of
  //strings delimited by space, tab, newline, and *.
  //Each one of these strings is a "syllable" and will be
  //cued by a tap on the spacebar.
  TextAreaElement txta = querySelector("#lyricsInputBox");
  tokens = txta.value.split(new RegExp(r"[\t\n *]"));
  
  //Generate the HTML for the thing...
  
}