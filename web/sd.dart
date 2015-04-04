// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:convert';
import 'package:chrome/chrome_ext.dart' as chrome;
import 'dart:async';
import 'dart:js';

final shownPollutants = ['SO2', 'NO2', 'PM10', 'PM2.5'];
//for linking to monitoring.krakow.pios.gov.pl
final locationMapping = {'Tarnów': 4, 'Skawina': 5, "Kraków, Al. Krasińskiego": 6,
  "Kraków, ul. Bulwarowa": 7, 'Nowy Sącz': 8, 'Zakopane': 9, 'Olkusz': 10,
  'Trzebinia': 11, 'Szymbark': 12, 'Szarów': 15, "Kraków, ul. Bujaka": 16};
//String serverUrl = 'http://localhost:8080';
String serverUrl = 'https://smog-server.herokuapp.com';
Map<String, Pollutant> displayedPollutants = {};
Timer timer;
Storage localStorage = window.localStorage;

class Pollutant {
  String shortLabel;
  double value;
  DateTime time;
  HtmlElement domEl;
  static final norms = {'SO2': 350, 'NO2': 200, 'PM10': 50, 'PM2.5': 25};

  Pollutant(this.shortLabel) {
    TemplateElement pollutantTemplate = querySelector('#pollutant');
    pollutantTemplate.content.querySelector('header').text = shortLabel;
    DocumentFragment clone = window.document.importNode(pollutantTemplate.content, true);
    querySelector('main').append(clone); //append returns DocumentFragment which later can't be accessed
    domEl = querySelectorAll('article').last;
    //TODO do this better - how to get cloned template?
  }

  update(DateTime t, double v) {
    String padZeroes(int n) => n > 9 ? n.toString() : '0' + n.toString();
    t = t.toLocal();
    value = v;
    if (time != null && t.difference(time).inHours.abs() > 3) {
      domEl.querySelector('section').text = 'b/d';
      domEl.className = 'in-norm';
    } else {
      int percentVal = (value / norms[shortLabel] * 100).round();
      domEl.querySelector('section').text = percentVal.toString() + '%';

      if (percentVal >= 100) {
        domEl.className = 'over-norm';
      } else if (percentVal >= 75) {
        domEl.className = 'warning';
      } else {
        domEl.className = 'in-norm';
      }
    }
    time = t.toLocal();
    domEl.querySelector('footer').text = '${padZeroes(time.hour)}:${padZeroes(time.minute)}';
  }
}

changeLocation(String location) {
  var options = new JsObject.jsify({
                                     'title': 'Smog: $location',
                                     'url': 'http://monitoring.krakow.pios.gov.pl/dane-pomiarowe/automatyczne/stacja/'
                                     + '${locationMapping[location]}/parametry/wszystkie'
                                   });
  context['opr']['speeddial'].callMethod('update', [options]);

  querySelector('main').nodes.clear();

  HttpRequest httpRequest = new HttpRequest();
  httpRequest
    ..open('GET', serverUrl + "/location/" + "?val=" + Uri.encodeComponent(location))
    ..onLoadEnd.listen((e) {
    Map locationData = JSON.decode(httpRequest.responseText);
    Map pollutants = locationData['pollutants'];
    List sorted = new List.from(pollutants.keys);
    sorted.sort();
    sorted.forEach((shortName) {
      if (!shownPollutants.contains(shortName)) return;
      Map lastValue = pollutants[shortName]['lastValue'];
      Pollutant p = new Pollutant(shortName);
      DateTime d = DateTime.parse(lastValue['dateTime']);
      double v = lastValue['value'];
      p.update(d, v);
      displayedPollutants[p.shortLabel] = p;
    });

    if (timer != null) timer.cancel();
    timer = new Timer.periodic(new Duration(minutes: 5), (Timer timer) {
      updatePollutantValues(location);
    });
  })
    ..send();
}

updatePollutantValues(String location) {
  print('updatePollutantValues $location');
  HttpRequest httpRequest = new HttpRequest();
  httpRequest
    ..open('GET', serverUrl + "/location/" + "?val=" + Uri.encodeComponent(location))
    ..onLoadEnd.listen((e) {
    Map locationData = JSON.decode(httpRequest.responseText);
    Map pollutants = locationData['pollutants'];
    displayedPollutants.keys.forEach((String pollutantName) {
      var p = pollutants[pollutantName];
      displayedPollutants[pollutantName].update(DateTime.parse(p['lastValue']['dateTime']), p['lastValue']['value']);
    });
  })
    ..send();
}

main() {
  chrome.runtime.onMessage.listen((chrome.OnMessageEvent e) {
    changeLocation(e.message);
  });

  String savedLocation = localStorage['location'];
  if (savedLocation == null) {
    chrome.TabsCreateParams tcp = new chrome.TabsCreateParams();
    tcp.url = 'options.html';
    chrome.tabs.create(tcp);
  } else {
    changeLocation(savedLocation);
  }
}