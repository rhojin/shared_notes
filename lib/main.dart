import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_notes/grpc/Notes.pbgrpc.dart';

class NoteServiceClientProvider extends ChangeNotifier {
  NoteServiceClient noteServiceClient;
  List<Note> items = []; //TODO: extract to as dedicated ChangeNotifier
  TextEditingController createNoteTextController = TextEditingController();
  TextEditingController updateNoteTextController = TextEditingController();

  NoteServiceClientProvider(this.noteServiceClient);

  void refresh() async {
    try {
      final response = await noteServiceClient.getNotes(Empty());
      items = response.note;
      items.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    } catch (e) {
      print('Caught error: $e');
    }
    notifyListeners();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); //otherwise getConfig() will fail!
  getConfig().then((config) {
    runApp(App(config));
  });
  // await channel.shutdown();
}

Future<Map<String, dynamic>> getConfig() async {
  final String response = await rootBundle.loadString('config.json');
  return jsonDecode(response);
}

class App extends StatelessWidget {
  final Map<String, dynamic> config;
  const App(this.config, {super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'Shared Notes';

    final channel = ClientChannel(
      config['server']['ip'].toString(),
      port: int.parse(config['server']['port'].toString()),
      options: ChannelOptions(
        credentials: const ChannelCredentials.insecure(),
        codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
      ),
    );
    final stub = NoteServiceClient(channel);

    return MaterialApp(
      title: title,
      home: ChangeNotifierProvider(
        create: (context) => NoteServiceClientProvider(stub)..refresh(),
        child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
                title: const Text(title),
                actions: [
                  Consumer<NoteServiceClientProvider> (
                    builder: (context, notifier, child) {
                      //https://stackoverflow.com/questions/56275595/no-materiallocalizations-found-myapp-widgets-require-materiallocalizations-to
                      return CreateButton(notifier);
                      //needs to be in a separate widget so that MaterialLocalizations widget is in the widget tree of MaterialApp implicitly
                    }
                  ),
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
            body: Container(
                padding: const EdgeInsets.all(15),
                child: const Notes(),
            ),
        ),
      )
    );
  }
}

class CreateButton extends StatelessWidget {
  final NoteServiceClientProvider notifier;
  const CreateButton(this.notifier, {super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.add,
        color: Colors.white,
      ),
      onPressed: () {
        showDialog(
            context: context,
            builder: (context) {
              //this is the dialog to add a new entry
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                elevation: 16,
                child: Container(
                  height: 60,
                  width: 120,
                  color: Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(3.0),
                          child: TextField(
                            controller: notifier.createNoteTextController,
                            textAlignVertical: const TextAlignVertical(y: 1),
                            textAlign: TextAlign.left,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: 'Enter a new note',
                            ),
                          ),
                        )
                      ),
                      TextButton(
                          onPressed: () {
                            String text = notifier.createNoteTextController.text;
                            if(text.isNotEmpty) {
                              var note = Note(text: text);
                              notifier.noteServiceClient.createNote(note)
                                  .then((note) {
                                    notifier.refresh();
                                    notifier.createNoteTextController.text = '';
                              });
                            }
                            Navigator.pop(context);
                          },
                          child: const Text("Submit"),
                      )
                    ],
                  ),
                )
              );
            });
      },
    );
  }

}

class Notes extends StatelessWidget {
  const Notes({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteServiceClientProvider> (
      builder: (context, notifier, child) {
        return ListView.separated(
            itemCount: notifier.items.length,
            itemBuilder: (context, index) {
              final item = notifier.items[index];
              return Dismissible(
                  key: Key(item.id.toString()),
                  onDismissed: (direction) {
                    NoteId noteId = NoteId.create()
                      ..id = item.id;
                    notifier.noteServiceClient.deleteNote(noteId)
                        .then((note) {
                          notifier.refresh();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${note.text} removed')));
                      });
                  },
                  direction: DismissDirection.endToStart,
                  background: Container(color: Colors.red),
                  child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xff1f92fc),
                        child: Text(style: const TextStyle(color: Color(0xffffffff)), notifier.items[index].text[0]),
                      ),
                      title: Text(notifier.items[index].text),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          notifier.updateNoteTextController.text = item.text;
                          showDialog(
                            context: context,
                            builder: (context) {
                              //this is the dialog to edit one entry
                            return Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                              elevation: 16,
                              child: Container(
                                height: 60,
                                width: 120,
                                color: Colors.white,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(3.0),
                                        child: TextField(
                                          controller: notifier.updateNoteTextController,
                                          textAlignVertical: const TextAlignVertical(y: 1),
                                          textAlign: TextAlign.left,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                            hintText: 'Enter note text',
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        String text = notifier.updateNoteTextController.text;
                                        if(text.isNotEmpty) {
                                          item.text = text;
                                          notifier.noteServiceClient.updateNote(item).then((item) {
                                            notifier.refresh();
                                            notifier.updateNoteTextController.text = '';
                                          });
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: const Text("Submit"),
                                    ),
                                  ],
                                  ),
                                )
                              );
                            });
                          },
                        ),
                    ),
              );
          },
          separatorBuilder: (context, index) {
            return const Divider(
              color: Colors.blue,
              thickness: 2,
            );
          },
        );
      }
    );
  }

}
