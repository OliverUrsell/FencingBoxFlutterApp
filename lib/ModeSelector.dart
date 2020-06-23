import 'package:fencingboxapp/MQTThelper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ModeSelector extends StatefulWidget {
  final MQTThelper mqtt;

  ModeSelector({
    @required this.mqtt
  });

  @override
  _ModeSelectorState createState() => _ModeSelectorState(mqtt: mqtt);
}

class _ModeSelectorState extends State<ModeSelector> {
  MQTThelper mqtt;

  static String dropdownValue = "Foil";

  _ModeSelectorState({
    @required this.mqtt
  }){
    mqtt.onMessageReceived.add((topic, payload) {
      switch(topic){
        case "/sword":
          setState(() {
            if(payload == "Foil" || payload == "Sabre" || payload == "Epee") {
              dropdownValue = payload;
            }
          });
          break;
      }
    });
    mqtt.subscribe("/sword");
    mqtt.publish("/general", "publishState");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Mode")),
      body: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Select Sword:",
                  style: TextStyle(fontSize: 24),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<String>(
                  value: dropdownValue,
                  icon: Icon(Icons.arrow_downward),
                  underline: Container(
                    height: 2,
                    color: Colors.deepPurpleAccent,
                  ),
                  onChanged: (String newValue) {
                    setState(() {
                      dropdownValue = newValue;
                      mqtt.publish("/sword", newValue);
                    });
                  },
                  items: <String>['Foil', 'Sabre', 'Epee']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(fontSize: 24)),
                    );
                  })
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
