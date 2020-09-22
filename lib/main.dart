import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:fencingboxapp/MQTThelper.dart';
import 'ModeSelector.dart';
import 'package:wakelock/wakelock.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    // Disable screen going to sleep
    Wakelock.enable();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

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

  int _navBarIndex = 0;

  String matchMode = "None";

  final List<int> leftMatchOrder = [3,2,1,3,2,1,3,2,1];
  final List<int> rightMatchOrder = [2,1,3,1,3,2,3,2,1];
  int currentMatch = 0;
  List<String> leftNames = ["", "", ""];
  List<String> rightNames = ["", "", ""];

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
        brokerAddress: "192.168.4.1", //"test.mosquitto.org",
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
        onDisconnect: () {
          setState(() {
            tryConnection();
          });
        },
        onMessageReceived: [(String topic, String payload) {
          setState(() {
            switch (topic) {
              case "/clock":
                time = int.parse(payload);
                if(time <= 0) {
                  _timerFinished();
                }
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
        if(matchMode == "Team Match"){
          if(_redScore == (currentMatch + 1)*5){
            showNextMatchDialog();
          }
        }
      });
    }

    void setGreenScore(int value) {
      setState(() {
        mqtt.publish("/green", value.toString());
        _greenScore = value;
        if(matchMode == "Team Match"){
          if(_greenScore == (currentMatch + 1)*5){
            showNextMatchDialog();
          }
        }
      });
    }

    if (connected) {
      Widget appBarTitle;
      Expanded centralColumn;
      if(matchMode == "Team Match"){
        centralColumn = Expanded(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    child: IconButton(
                      icon: Icon(Icons.chevron_left),
                      color: Colors.grey,
                      onPressed: () {
                        if(currentMatch > 0) {
                          setState(() {
                            previousRound();
                          });
                        }
                      },
                    ),
                  ),
                  Text(
                    "${currentMatch + 1} / ${leftMatchOrder.length}",
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.visible,
                  ),
                  Container(
                    width: 30,
                    child: IconButton(
                      icon: Icon(Icons.chevron_right),
                      color: Colors.grey,
                      onPressed: () {
                        if (currentMatch < 8) {
                          setState(() {
                            nextRound();
                          });
                        }
                      },

                    ),
                  )
                ],
              ),
              Text(
                "${time ~/ 60}:${displayIntWithTwoPlaces(
                    time % 60)}",
                style: TextStyle(
                  fontSize: 50,
                  color: Colors.white,
                ),
                overflow: TextOverflow.visible,
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
            ],
          ),
        );
      }else{
        centralColumn = Expanded(
          child: Column(
            children: <Widget>[
              Text(
                "${time ~/ 60}:${displayIntWithTwoPlaces(
                    time % 60)}",
                style: TextStyle(
                  fontSize: 50,
                  color: Colors.white,
                ),
                overflow: TextOverflow.visible,
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
        );
      }
      Widget appBody;

      switch(_navBarIndex){
        case 0:
          appBarTitle = Text("The Fencing Box");
          appBody = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Flex(
                direction: Axis.horizontal,
                children: <Widget>[

                  //Red Score
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 0),
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
                                  fontSize: 97, color: Colors.red)),
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
                  ),

                  //Central Column
                  centralColumn,

                  //Green Score
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 0),
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
                                  fontSize: 97, color: Colors.green)),
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
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: getStartStopButton()),
              )
            ],
          );
          break;
        case 1:
          appBarTitle = Text("The Fencing Box - Matches");

          Widget mainContent;
          switch(matchMode){
            case "None":
              mainContent = Container();
              break;
            case "Poole":
              mainContent = Center(
                child: Text("Feature Coming Soon!",
                  style: TextStyle(fontSize: 32, color: Colors.red),
                )
              );
              break;
            case "Team Match":
              mainContent = Column(
                children: <Widget>[
                  Text("Team Names",
                    style: TextStyle(fontSize: 32),
                  ),
                  Flex(
                    direction: Axis.horizontal,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: <Widget>[
                              Text("Left Team",
                                style: TextStyle(fontSize: 24),
                              ),
                              TextFormField(
                                initialValue: leftNames[0],
                                decoration: InputDecoration(
                                    hintText: 'Name 1'
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    leftNames[0] = text;
                                    sendNames();
                                  });
                                },
                              ),
                              TextFormField(
                                initialValue: leftNames[1],
                                decoration: InputDecoration(
                                    hintText: 'Name 2'
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    leftNames[1] = text;
                                    sendNames();
                                  });
                                },
                              ),
                              TextFormField(
                                initialValue: leftNames[2],
                                decoration: InputDecoration(
                                    hintText: 'Name 3'
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    leftNames[2] = text;
                                    sendNames();
                                  });
                                },
                              )
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: <Widget>[
                              Text("Right Team",
                                style: TextStyle(fontSize: 24),
                              ),
                              TextFormField(
                                initialValue: rightNames[0],
                                decoration: InputDecoration(
                                  hintText: 'Name 1'
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    rightNames[0] = text;
                                    sendNames();
                                  });
                                },
                              ),
                              TextFormField(
                                initialValue: rightNames[1],
                                decoration: InputDecoration(
                                    hintText: 'Name 2'
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    rightNames[1] = text;
                                    sendNames();
                                  });
                                },
                              ),
                              TextFormField(
                                initialValue: rightNames[2],
                                decoration: InputDecoration(
                                    hintText: 'Name 3'
                                ),
                                onChanged: (text) {
                                  setState(() {
                                    rightNames[2] = text;
                                    sendNames();
                                  });
                                },
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Matchups",
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                  SizedBox(
                    height:150,
                    child: ListView(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget> [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: stringArrayToTextWidgets(distributeList<String>(leftNames, leftMatchOrder.map((x){return x-1;}).toList()), TextStyle(fontSize: 18)),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: intArrayToTextWidgets(leftMatchOrder, TextStyle(fontSize: 18))
                              ),
                            ),
                            Column(
                              children: stringArrayToTextWidgets(List.filled(leftMatchOrder.length, "v"), TextStyle(fontSize: 18))
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: intArrayToTextWidgets(rightMatchOrder, TextStyle(fontSize: 18)),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: stringArrayToTextWidgets(distributeList<String>(rightNames, rightMatchOrder.map((x){return x-1;}).toList()), TextStyle(fontSize: 18)),
                                ),
                              ),
                            ),
                          ]
                        ),
                      ],
                    ),
                  )
                ],
              );
              break;
          }

          appBody = Container(
            color: Colors.white,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("Select Format:",
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DropdownButton<String>(
                        value: matchMode,
                        icon: Icon(Icons.arrow_downward),
                        underline: Container(
                          height: 2,
                          color: Colors.deepPurpleAccent,
                        ),
                        onChanged: (String newValue) {
                          setState(() {
                            matchMode = newValue;
                          });
                        },
                        items: <String>['None', 'Poole', 'Team Match']
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
                mainContent
              ],
            ),
          );
          break;
        case 2:
          appBarTitle = Text("The Fencing Box - Settings");
          appBody = ModeSelector(mqtt: mqtt);
          break;
      }

      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: appBarTitle,
        ),
        body: appBody,
        bottomNavigationBar: BottomNavigationBar(
         currentIndex: _navBarIndex,
         onTap: (index) {
           setState(() {
             _navBarIndex = index;
           });
         },
         items: [
           BottomNavigationBarItem(
             icon: Icon(Icons.play_arrow),
             title: Text("Referee"),
           ),
           BottomNavigationBarItem(
             icon: Icon(Icons.table_chart),
             title: Text("Formats"),
           ),
           BottomNavigationBarItem(
             icon: Icon(Icons.settings),
             title: Text("Box Settings"),
           )
         ],
        ),
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

  List<Widget> intArrayToTextWidgets(List<int> sList, TextStyle style){
    List<Widget> out = [];
    for(int i in sList){
      out.add(Text(i.toString(), style: style));
    }
    return out;
  }

  List<Widget> stringArrayToTextWidgets(List<String> sList, TextStyle style){
    List<Widget> out = [];
    for(String s in sList){
      out.add(Text(s, style: style,
        overflow: TextOverflow.ellipsis,
      ));
    }
    return out;
  }

  List<T> distributeList<T>(List<T> list, List<int> order){
    // Creates a new list from a list with the index order specified
    List<T> out = [];
    for(int i in order){
      out.add(list[i]);
    }
    return out;
  }
  
  void sendNames(){
    mqtt.publish("/name/red", leftNames[leftMatchOrder[currentMatch] - 1]);
    mqtt.publish("/name/green", rightNames[rightMatchOrder[currentMatch] - 1]);
  }

  void nextRound(){
    currentMatch++;
    sendNames();
  }

  void previousRound(){
    currentMatch--;
    sendNames();
  }

  void notifyVibrate() async{
    if(await Vibration.hasVibrator()){
      if (await Vibration.hasCustomVibrationsSupport()) {
        Vibration.vibrate(pattern: [0,1000,500,1000,500,1000]);
      } else {
        Vibration.vibrate();
        await Future.delayed(Duration(milliseconds: 500));
        Vibration.vibrate();
      }
    }
  }

  void _timerFinished(){
    if(matchMode == "Team Match"){
      showNextMatchDialog();
    }else{
      notifyVibrate();
    }
  }

  Future<void> showNextMatchDialog() async{

    notifyVibrate();

    if(currentMatch == 8){
      return showDialog<void>(
          context: context,
          builder: (BuildContext context){
            return AlertDialog(
              title: Text("Match Done!"),
              content: SingleChildScrollView(
                  child: Text("Match Finished!")
              ),
              actions: <Widget>[
                FlatButton(
                  child: Text("Done"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          }
      );
    }

    ListBody content;
    if(currentMatch == 7){
      content = ListBody(
        children: <Widget>[
          Text("Round Over!"),
          Text("Next Round: ${leftNames[leftMatchOrder[8] - 1]} v ${rightNames[rightMatchOrder[8] - 1]}")
        ],
      );
    }else{
      content = ListBody(
        children: <Widget>[
          Text("Round Over!"),
          Text("Next Round: ${leftNames[leftMatchOrder[currentMatch+1] - 1]} v ${rightNames[rightMatchOrder[currentMatch+1] - 1]}"),
          Text("Getting Ready: ${leftNames[leftMatchOrder[currentMatch+2] - 1]} v ${rightNames[rightMatchOrder[currentMatch+2] - 1]}")
        ],
      );
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context){
        return AlertDialog(
          title: Text("Next Round"),
          content: SingleChildScrollView(
            child: content
          ),
          actions: <Widget>[
            FlatButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text("Next Round"),
              onPressed: () {
                nextRound();
                mqtt.publish("/general", "resetTime");
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      }
    );
  }

}
