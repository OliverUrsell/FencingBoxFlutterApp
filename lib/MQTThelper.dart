import 'package:flutter/cupertino.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:math';

//     || ||
//     ||_||
//     \___/
// Oliver Ursell

class MQTThelper{

  final Function onConnected;
  final Function onConnectionFailed;
  List<Function> onMessageReceived;
  final String brokerAddress;
  MqttServerClient _client;

  MQTThelper({
    @required this.onConnected,
    @required this.onConnectionFailed,
    @required this.onMessageReceived,
    @required this.brokerAddress
  }){
    _client = MqttServerClient(brokerAddress, '');
    this.connect();
  }

  void connect() async {
    _client.logging(on: true);
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = onDisconnected;
    _client.onSubscribed = onSubscribed;
    final connMess = MqttConnectMessage()
        .withClientIdentifier('${new Random().nextInt(1000)}')
        .keepAliveFor(
        20); // Must agree with the keep alive set above or not set
    print('Mosquitto client connecting....');
    _client.connectionMessage = connMess;

    try {
      await _client.connect();
    } on Exception catch (e) {
      print('client exception - $e');
      _client.disconnect();
    }

    /// Check we are connected
    if (_client.connectionStatus.state == MqttConnectionState.connected) {
      print('EXAMPLE::Mosquitto client connected');

      _client.updates.listen((dynamic c) {
        final MqttPublishMessage recMess = c[0].payload;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('Change notification:: topic is <${c[0].topic}>, payload is <-- $pt -->');
        for(Function f in onMessageReceived) {
          f("${c[0].topic}", "$pt");
        }
      });

      onConnected();
    } else {
      print(
          'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, state is ${_client
              .connectionStatus.state}');
      onConnectionFailed();
      _client.disconnect();
    }
  }

  void subscribe(String topic) {
    print("Subscribing to $topic...");
    _client.subscribe(topic, MqttQos.atLeastOnce);
  }

  void publish(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    print('Publishing to $topic...');
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload);
    _client.published.listen((MqttPublishMessage message) {
      print(
          'EXAMPLE::Published notification:: topic is ${message.variableHeader.topicName}, with Qos ${message.header.qos}');
    });
  }

  /// Subscribe to a topic
  void unsubscribe(String topic){
    _client.unsubscribe(topic);
  }

  /// The subscribed callback
  void onSubscribed(String topic) {
    print('Subscription confirmed for topic $topic');
  }

  /// The unsolicited disconnect callback
  void onDisconnected() {
    print('OnDisconnected client callback - Client disconnection');
  }

  void disconnect() {
    _client.disconnect();
  }

}