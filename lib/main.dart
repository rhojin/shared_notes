import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_notes/grpc/Notes.pbgrpc.dart';

class NoteServiceClientProvider extends ChangeNotifier {
  NoteServiceClient noteServiceClient;
  List<String> items = []; //TODO: extract to as dedicated ChangeNotifier

  NoteServiceClientProvider(this.noteServiceClient);

  void refresh() async {
    try {
      final response = await noteServiceClient.getNotes(Empty());
      items = response.note.map((note) => note.text).toList();
    } catch (e) {
      print('Caught error: $e');
    }
    notifyListeners();
  }

}

Future<void> main() async {
  runApp(const App());
  // await channel.shutdown();
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'Shared Notes';

    final channel = ClientChannel(
      '10.0.2.2',
      port: 8080,
      options: ChannelOptions(
        credentials: const ChannelCredentials.insecure(),
        codecRegistry:
        CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
      ),
    );
    final stub = NoteServiceClient(channel);

    return MaterialApp(
      title: title,
      home: ChangeNotifierProvider(
        create: (context) => NoteServiceClientProvider(stub),
        child: Scaffold(
            appBar: AppBar(
                title: const Text(title),
                actions: [
                  Consumer<NoteServiceClientProvider> (
                    builder: (context, notifier, child) {
                      return IconButton(
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                          ),
                          onPressed: () => notifier.refresh()
                      );
                    }
                  ),
                ],
            ),
            body: const Notes()
        ),
      )
    );
  }
}

class Notes extends StatelessWidget {
  const Notes({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteServiceClientProvider> (
      builder: (context, notifier, child) {
        return ListView.builder(
            itemCount: notifier.items.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xff1f92fc),
                  child: Text(style: const TextStyle(color: Color(0xffffffff)), notifier.items[index][0]),
                ),
                title: Text(notifier.items[index]),
              );
            }
        );
      }
    );
  }

}
