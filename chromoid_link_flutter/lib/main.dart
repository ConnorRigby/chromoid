import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key key, this.device}) : super(key: key);

  final BluetoothDevice device;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      StreamBuilder(
          stream: device.state,
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
          stream: device.services,
          initialData: [],
          builder: (c, snapshot) {
            if (snapshot.data.isEmpty) device.discoverServices();
            BluetoothCharacteristic characteristic;
            Color initialColor = Colors.black;

            snapshot.data.forEach((service) {
              if (service.uuid ==
                  Guid("0000fffc-0000-1000-8000-00805f9b34fb")) {
                print("found color service");
                service.characteristics.forEach((char) async {
                  if (char.uuid ==
                      Guid("0000ff30-0000-1000-8000-00805f9b34fb")) {
                    print("Found color characteristic: ${char.uuid}");
                    characteristic = char;
                    var value = await char.read();
                    initialColor =
                        Color.fromRGBO(value[5], value[6], value[7], 0);
                    print(initialColor);
                  }
                });
              }
            });

            if (characteristic != null) {
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
                    await characteristic.write(payload, withoutResponse: true);
                  });
            } else {
              return Text("Searching for device");
            }
          })
    ]);
  }
}

class _MyHomePageState extends State<MyHomePage> {
  bool alreadyConnect = false;
  bool alreadyService = false;
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
                  return DeviceScreen(device: device);
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
