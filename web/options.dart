import 'dart:html';
import 'dart:convert';
import 'package:chrome/chrome_ext.dart' as chrome;

void selectLocation(String location) {
  chrome.runtime.sendMessage(location);
  window.localStorage['location'] = location;
}

void main() {
//  String serverUrl = 'http://localhost:8080';
  String serverUrl = 'https://smog-server.herokuapp.com';

  var httpRequest = new HttpRequest();
  httpRequest
    ..open('GET', '$serverUrl/locations/')
    ..onLoadEnd.listen((e) {
    List<String> locations = JSON.decode(httpRequest.responseText);
    selectLocation(locations.first);
    SelectElement select = querySelector('select');
    locations.forEach((location) {
      OptionElement o = new OptionElement();
      o.value = o.text = location;
      select.append(o);
    });
    select.onChange.listen((Event e) {
      selectLocation((e.target as SelectElement).selectedOptions.single.value);
    });
  })
    ..send();
}