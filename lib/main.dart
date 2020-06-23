import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fencingboxapp/MQTThelper.dart';
import 'ModeSelector.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _redScore = 0;
  int _greenScore = 0;
  int time = 3 * 60;
  bool clockOn = false;

  MQTThelper mqtt;

  bool connected = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    tryConnection();
  }

  void tryConnection(){
    setState(() {
      connected = false;
      failed = false;
    });
    mqtt = new MQTThelper(
        brokerAddress: "test.mosquitto.org",//"192.168.4.1",
        onConnected: () {
          setState(() {
            connected = true;
            failed = false;
          });
          subscribeToTopics();
          mqtt.publish("/general", "publishState");
        },
        onConnectionFailed: () {
          setState(() {
            connected = false;
            failed = true;
          });
        },
        onMessageReceived: [(String topic, String payload) {
          setState(() {
            switch (topic) {
              case "/clock":
                time = int.parse(payload);
                break;
              case "/clock/control":
                clockOn = payload == "true";
                break;
              case "/red":
                _redScore = int.parse(payload);
                break;
              case "/green":
                _greenScore = int.parse(payload);
                break;
            }
          });
        }]);
  }

  void subscribeToTopics() {
    mqtt.subscribe("/clock");
    mqtt.subscribe("/clock/control");
    mqtt.subscribe("/red");
    mqtt.subscribe("/green");
  }

  @override
  Widget build(BuildContext context) {
    void setRedScore(int value) {
      setState(() {
        mqtt.publish("/red", value.toString());
        _redScore = value;
      });
    }

    void setGreenScore(int value) {
      setState(() {
        mqtt.publish("/green", value.toString());
        _greenScore = value;
      });
    }

    if (connected) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text("The Fencing Box"),
          actions: <Widget>[
            FlatButton(
              child: Text("Change Mode",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ModeSelector(mqtt: this.mqtt)),
                );
              },
            )
          ],
        ),
        body: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        children: <Widget>[
                          Container(
                            height: 100,
                            width: 100,
                            child: RaisedButton(
                              child: Icon(Icons.arrow_upward, size: 50),
                              onPressed: () {
                                if (_redScore < 99) {
                                  setRedScore(_redScore + 1);
                                }
                              },
                            ),
                          ),
                          Text("$_redScore",
                              style: TextStyle(
                                  fontSize: 100, color: Colors.red)),
                          Container(
                            height: 100,
                            width: 100,
                            child: RaisedButton(
                              child: Icon(Icons.arrow_downward, size: 50),
                              onPressed: () {
                                if (_redScore > 0) {
                                  setRedScore(_redScore - 1);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: <Widget>[
                          Text(
                            "${time ~/ 60}:${displayIntWithTwoPlaces(
                                time % 60)}",
                            style: TextStyle(
                              fontSize: 50,
                              color: Colors.white,
                            ),
                          ),
                          RaisedButton(
                            onPressed: () {
                              showModalBottomSheet(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Container(
                                      color: Colors.grey[400],
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment
                                            .center,
                                        children: <Widget>[
                                          RaisedButton(
                                            child: Text("Reset Just Scores"),
                                            onPressed: () {
                                              setRedScore(0);
                                              setGreenScore(0);
                                              mqtt.publish(
                                                  "/clock/control", "false");
                                              Navigator.pop(context);
                                            },
                                          ),
                                          RaisedButton(
                                            child: Text("Reset Just Time"),
                                            onPressed: () {
                                              mqtt.publish(
                                                  "/general", "resetTime");
                                              Navigator.pop(context);
                                            },
                                          ),
                                          RaisedButton(
                                            child: Text(
                                                "Reset Scores and Time"),
                                            onPressed: () {
                                              setRedScore(0);
                                              setGreenScore(0);
                                              mqtt.publish(
                                                  "/general", "resetTime");
                                              Navigator.pop(context);
                                            },
                                          ),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment
                                                .center,
                                            children: <Widget>[
                                              RaisedButton(
                                                child: Text("Reset Time -"),
                                                onPressed: () {
                                                  setRedScore(0);
                                                  setGreenScore(0);
                                                  mqtt.publish(
                                                      "/general", "resetTime-");
                                                  Navigator.pop(context);
                                                },
                                              ),
                                              Padding(
                                                padding: const EdgeInsets
                                                    .fromLTRB(8, 0, 0, 0),
                                                child: RaisedButton(
                                                  child: Text("Reset Time +"),
                                                  onPressed: () {
                                                    setRedScore(0);
                                                    setGreenScore(0);
                                                    mqtt.publish(
                                                        "/general",
                                                        "resetTime+");
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    );
                                  });
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                              child: Text(
                                "Reset",
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 3),
                            child: Container(
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.amber)),
                              child: FlatButton(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      0, 25, 0, 25),
                                  child: Text(
                                    "Pause",
                                    style:
                                    TextStyle(
                                        fontSize: 24, color: Colors.amber),
                                  ),
                                ),
                                onPressed: () {
                                  mqtt.publish("/general", "pause");
                                },
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        children: <Widget>[
                          Container(
                            height: 100,
                            width: 100,
                            child: RaisedButton(
                              child: Icon(Icons.arrow_upward, size: 50),
                              onPressed: () {
                                if (_greenScore < 99) {
                                  setGreenScore(_greenScore + 1);
                                }
                              },
                            ),
                          ),
                          Text("$_greenScore",
                              style: TextStyle(
                                  fontSize: 100, color: Colors.green)),
                          Container(
                            height: 100,
                            width: 100,
                            child: RaisedButton(
                              child: Icon(Icons.arrow_downward, size: 50),
                              onPressed: () {
                                if (_greenScore > 0) {
                                  setGreenScore(_greenScore - 1);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: getStartStopButton()),
                )
              ],
            )),
      );
    } else if(failed){
      return Scaffold(
          body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: Icon(Icons.sentiment_dissatisfied, color: Colors.red, size: 100,)
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Text("Connection Failed",
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: RaisedButton(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Try Again", style: TextStyle(fontSize: 24)),
                      ),
                      onPressed: () {
                        tryConnection();
                      },
                    )
                  ),
                ],
              )
          )
      );
    } else {
      return Scaffold(
          body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: CircularProgressIndicator()
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Text("Connecting",
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ],
              )
          )
      );
    }
  }

  String displayIntWithTwoPlaces(int input) {
    int value = input.round();
    if (value < 0)
      throw Exception("Invalid input to displayIntWithTwoPlaces,"
          " value cannot be less than zero");
    if (value < 10) return "0$value";
    return "$value";
  }

  Widget getStartStopButton() {
    if (clockOn) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red),
        ),
        child: FlatButton(
          color: Colors.black,
          onPressed: () {
            setState(() {
              mqtt.publish("/clock/control", "false");
              clockOn = false;
            });
          },
          child: Text(
            "Stop",
            style: TextStyle(fontSize: 24, color: Colors.red),
          ),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green),
        ),
        child: FlatButton(
          color: Colors.black,
          onPressed: () {
            setState(() {
              mqtt.publish("/clock/control", "true");
              clockOn = true;
            });
          },
          child: Text(
            "Start",
            style: TextStyle(fontSize: 24, color: Colors.green),
          ),
        ),
      );
    }
  }
}
