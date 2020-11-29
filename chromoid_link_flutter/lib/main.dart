import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:phoenix_wings/phoenix_wings.dart';
import 'package:device_info/device_info.dart';

// final url = 'ws://192.168.1.108:4000/device_socket/websocket';
// final token = '0Mvm_1SI8ibpNAjaJpTCZKk-a2JbQrOgsV7a2YOlATw';

final url = 'wss://chromo.id/device_socket/websocket';
final token = 'EcLawt5itDGoDBteRTRpmjR9jJbLE_B9PUvNRjLmfGw';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chromoid Link',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: MyHomePage(title: 'Chromoid Link'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  final socket = PhoenixSocket(url,
      socketOptions: PhoenixSocketOptions(params: {"token": token}));
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool alreadyConnect = false;
  bool alreadyService = false;
  PhoenixChannel _channel;

  static Future<List<String>> getDeviceDetails() async {
    String deviceName;
    String deviceVersion;
    String identifier;
    final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        var build = await deviceInfoPlugin.androidInfo;
        deviceName = build.model;
        deviceVersion = build.version.toString();
        identifier = build.androidId; //UUID for Android
      } else if (Platform.isIOS) {
        var data = await deviceInfoPlugin.iosInfo;
        deviceName = data.name;
        deviceVersion = data.systemVersion;
        identifier = data.identifierForVendor; //UUID for iOS
      }
    } on PlatformException {
      print('Failed to get platform version');
    }

    return [deviceName, deviceVersion, identifier];
  }

  @override
  void initState() {
    connectSocket();
    getDeviceDetails().then((result) {
      print(result);
    });
    super.initState();
  }

  connectSocket() async {
    await widget.socket.connect();
    // Create a new PhoenixChannel
    _channel = widget.socket.channel("device");
    _channel.on("photo_request", (payload, ref, joinRef) {
      print("handling photo request");
      _channel
          .push(event: 'photo_response', payload: {'error': 'Not supported'});
    });

    // Make the request to the server to join the channel
    _channel.join();
  }

  _MyHomePageState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
            child: Column(
          children: <Widget>[
            StreamBuilder<List<ScanResult>>(
              stream: FlutterBlue.instance.scanResults,
              initialData: [],
              builder: (context, snapshot) {
                BluetoothDevice device;
                snapshot.data.forEach((element) {
                  if (element.device.id ==
                      DeviceIdentifier("08:31:20:00:33:EA")) {
                    print("found: ${element.device.id}");
                    device = element.device;
                  }
                });

                if (device != null) {
                  if (!alreadyConnect) {
                    device.connect();
                    alreadyConnect = true;
                  }
                  return DeviceScreen(device: device, socket: widget.socket);
                } else {
                  return Text("Search for device first");
                }
              },
            )
          ],
        )),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}

class _DeviceScreenState extends State<DeviceScreen> {
  _DeviceScreenState();
  PhoenixChannel _channel;
  BluetoothCharacteristic _characteristic;

  @override
  void initState() {
    connectChannel();
    // widget.device.discoverServices();
    super.initState();
  }

  connectChannel() {
    // Create a new PhoenixChannel
    _channel = widget.socket.channel('ble:${widget.device.id}');
    _channel.on("set_color", (colorPayload, ref, joinRef) {
      print("handling color request: ${colorPayload}");
      Color color = Color(colorPayload['color']);
      var blePayload = [
        0x0c,
        0x01,
        0x00,
        0x64,
        0x64,
        color.red,
        color.green,
        color.blue,
        0xff,
        0x64,
        0xff,
        0xff,
        0xff,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00
      ];
      print("Changing color: ${color.value} (${color})");
      _characteristic.write(blePayload, withoutResponse: true);
      _channel.push(event: 'color_state', payload: {'color': color.value});
    });

    _channel.join();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      StreamBuilder(
          stream: widget.device.state,
          initialData: BluetoothDeviceState.connecting,
          builder: (c, snapshot) {
            switch (snapshot.data) {
              case BluetoothDeviceState.connecting:
                return Column(children: [
                  SizedBox(
                    child: const CircularProgressIndicator(),
                    width: 60,
                    height: 60,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text("Connecting..."),
                  )
                ]);
                break;
              case BluetoothDeviceState.connected:
                return Text("Connected!");
                break;
              case BluetoothDeviceState.disconnected:
                return Text("Disconnected!");
                break;
              default:
                return Text("Unknown state!");
                break;
            }
          }),
      StreamBuilder<List<BluetoothService>>(
          stream: widget.device.services,
          initialData: [],
          builder: (c, snapshot) {
            if (snapshot.data.isEmpty) widget.device.discoverServices();
            Color initialColor = Colors.black;

            snapshot.data.forEach((service) {
              if (service.uuid ==
                  Guid("0000fffc-0000-1000-8000-00805f9b34fb")) {
                print("found color service");
                service.characteristics.forEach((char) async {
                  if (char.uuid ==
                      Guid("0000ff30-0000-1000-8000-00805f9b34fb")) {
                    print("Found color characteristic: ${char.uuid}");
                    _characteristic = char;
                    var value = await char.read();
                    initialColor =
                        Color.fromRGBO(value[5], value[6], value[7], 0);
                    print(initialColor);
                  }
                });
              }
            });

            if (_characteristic != null) {
              // var color = await characteristic.read();
              // print(color);
              return ColorPicker(
                  enableAlpha: false,
                  pickerColor: initialColor,
                  onColorChanged: (color) async {
                    var payload = [
                      0x0c,
                      0x01,
                      0x00,
                      0x64,
                      0x64,
                      color.red,
                      color.green,
                      color.blue,
                      0xff,
                      0x64,
                      0xff,
                      0xff,
                      0xff,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00,
                      0x00
                    ];
                    await _characteristic.write(payload, withoutResponse: true);
                  });
            } else {
              return Text("Searching for device");
            }
          })
    ]);
  }
}

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key key, this.device, this.socket}) : super(key: key);
  final BluetoothDevice device;
  final PhoenixSocket socket;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}
