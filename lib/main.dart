import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grpc/grpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_notes/grpc/Notes.pbgrpc.dart';

class TopicServiceClientProvider extends ChangeNotifier {
  TopicServiceClient topicServiceClient;
  List<Topic> topics = []; //TODO: extract as dedicated ChangeNotifier?
  Topic? selectedTopic;
  TextEditingController createTopicTextController = TextEditingController();
  TextEditingController updateTopicTextController = TextEditingController();

  TopicServiceClientProvider(this.topicServiceClient);

  void refresh() async {
    try {
      final response = await topicServiceClient.getTopics(Empty());
      topics = response.topic;
      topics.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));

      if (selectedTopic == null && topics.isNotEmpty) {
        selectTopic(topics[0].id);
      }
    } catch (e) {
      print('Caught error: $e');
    }
    notifyListeners();
  }

  void selectTopic(int topicId) async {
    final newTopic = topics.firstWhere((t) => t.id == topicId);
    selectedTopic = newTopic;
    notifyListeners();
  }
}

class NoteServiceClientProvider extends ChangeNotifier {
  TopicServiceClientProvider topicServiceClientProvider;
  NoteServiceClient noteServiceClient;
  List<Note> items = []; //TODO: extract as dedicated ChangeNotifier
  TextEditingController createNoteTextController = TextEditingController();
  TextEditingController updateNoteTextController = TextEditingController();

  NoteServiceClientProvider(this.topicServiceClientProvider, this.noteServiceClient);

  void refresh() async {
    try {
      topicServiceClientProvider.refresh();
      if (topicServiceClientProvider.selectedTopic != null) {
        final response = await noteServiceClient.getNotesByTopic(topicServiceClientProvider.selectedTopic!);
        items = response.note;
        items.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
      }
    } catch (e) {
      print('Caught error: $e');
    }
    notifyListeners();
  }

  void selectTopic(int topicId) async {
    topicServiceClientProvider.selectTopic(topicId);
    refresh();
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
        codecRegistry:
            CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
      ),
    );
    final noteServiceClient = NoteServiceClient(channel);
    final topicServiceClient = TopicServiceClient(channel);

    return MaterialApp(
        title: title, //TODO: make this changeable - is the selected topic
        home: ChangeNotifierProvider(
          create: (context) => NoteServiceClientProvider(
              TopicServiceClientProvider(topicServiceClient), noteServiceClient)
            ..refresh(),
          child: Scaffold(
            drawer: Consumer<NoteServiceClientProvider>(
                builder: (context, notifier, child) {
              return Menu(notifier);
            }),
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text(title),
              actions: [
                Consumer<NoteServiceClientProvider>(
                    builder: (context, notifier, child) {
                  //https://stackoverflow.com/questions/56275595/no-materiallocalizations-found-myapp-widgets-require-materiallocalizations-to
                  return CreateNoteButton(notifier);
                  //needs to be in a separate widget so that MaterialLocalizations widget is in the widget tree of MaterialApp implicitly
                }),
                Consumer<NoteServiceClientProvider>(
                    builder: (context, notifier, child) {
                  return IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                      ),
                      onPressed: () => notifier.refresh());
                }),
              ],
            ),
            body: Container(
              padding: const EdgeInsets.all(15),
              child: const Notes(),
            ),
          ),
        ));
  }
}

class Menu extends StatelessWidget {
  final NoteServiceClientProvider notifier;
  const Menu(this.notifier, {super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: ListView.separated(
            itemCount: notifier.topicServiceClientProvider.topics.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                    height: 64,
                    width: 1,
                    child: DrawerHeader(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 10),
                        child: Row(
                          children: [
                            const Text('Shared Notes',
                                style: TextStyle(
                                    fontSize: 20, color: Colors.white)),
                            const Spacer(),
                            CreateTopicButton(notifier),
                          ],
                        )));
              } else {
                final topic = notifier.topicServiceClientProvider.topics[index - 1];
                return Dismissible(
                    key: Key(topic.id.toString()),
                    onDismissed: (direction) {
                      TopicId topicId = TopicId.create()..id = topic.id;
                      notifier.topicServiceClientProvider.topicServiceClient
                          .deleteTopic(topicId)
                          .then((topic) {
                            notifier.refresh();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${topic.text} removed')));
                          });
                    },
                    direction: DismissDirection.endToStart,
                    background: Container(color: Colors.red),
                    child: ListTile(
                      title: Text(topic.text),
                      onTap: () {
                        notifier.selectTopic(topic.id);
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                          icon: const Icon(
                          Icons.edit,
                            color: Colors.grey,
                          ),
                        onPressed: () {
                          notifier.topicServiceClientProvider.updateTopicTextController.text = topic.text;
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
                                                controller: notifier.topicServiceClientProvider.updateTopicTextController,
                                                textAlignVertical: const TextAlignVertical(y: 1),
                                                textAlign: TextAlign.left,
                                                decoration: const InputDecoration(
                                                  isDense: true,
                                                  border: OutlineInputBorder(),
                                                  hintText: 'Enter new topic name',
                                                ),
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              String text = notifier.topicServiceClientProvider.updateTopicTextController.text;
                                              if (text.isNotEmpty) {
                                                topic.text = text;
                                                notifier.topicServiceClientProvider.topicServiceClient.updateTopic(topic).then((topic) {
                                                  notifier.refresh();
                                                  notifier.topicServiceClientProvider.updateTopicTextController.text = '';
                                                });
                                              }
                                              Navigator.pop(context);
                                            },
                                            child: const Text("Submit"),
                                          ),
                                        ],
                                      ),
                                    ));
                              });
                        },
                      ),
                    ));
              }
            },
            separatorBuilder: (BuildContext context, int index) {
              return Container();
            }));
  }
}

class CreateTopicButton extends StatelessWidget {
  NoteServiceClientProvider notifier;
  CreateTopicButton(this.notifier, {super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(
        Icons.add,
        size: 20,
        color: Colors.white,
      ),
      onPressed: () {
        showDialog(
            context: context,
            builder: (context) {
              //this is the dialog to add a new entry
              return Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
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
                            controller: notifier.topicServiceClientProvider
                                .createTopicTextController,
                            textAlignVertical: const TextAlignVertical(y: 1),
                            textAlign: TextAlign.left,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              hintText: 'Enter a new topic',
                            ),
                          ),
                        )),
                        TextButton(
                          onPressed: () {
                            String text = notifier.topicServiceClientProvider
                                .createTopicTextController.text;
                            if (text.isNotEmpty) {
                              final topic = Topic(text: text);
                              notifier
                                  .topicServiceClientProvider.topicServiceClient
                                  .createTopic(topic)
                                  .then((note) {
                                notifier.topicServiceClientProvider.refresh();
                                notifier.refresh();
                                notifier.topicServiceClientProvider
                                    .createTopicTextController.text = '';
                              });
                            }
                            Navigator.pop(context);
                          },
                          child: const Text("Submit"),
                        )
                      ],
                    ),
                  ));
            });
      },
    );
  }
}

class CreateNoteButton extends StatelessWidget {
  final NoteServiceClientProvider notifier;
  const CreateNoteButton(this.notifier, {super.key});

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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
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
                        )),
                        TextButton(
                          onPressed: () {
                            String text =
                                notifier.createNoteTextController.text;
                            if (text.isNotEmpty) {
                              var note = Note(
                                  text: text,
                                  topic: notifier.topicServiceClientProvider
                                      .selectedTopic);
                              notifier.noteServiceClient
                                  .createNote(note)
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
                  ));
            });
      },
    );
  }
}

class Notes extends StatelessWidget {
  const Notes({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteServiceClientProvider>(
        builder: (context, notifier, child) {
      return ListView.separated(
        itemCount: notifier.items.length,
        itemBuilder: (context, index) {
          final item = notifier.items[index];
          return Dismissible(
            key: Key(item.id.toString()),
            onDismissed: (direction) {
              NoteId noteId = NoteId.create()..id = item.id;
              notifier.noteServiceClient.deleteNote(noteId).then((note) {
                notifier.refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${note.text} removed')));
              });
            },
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xff1f92fc),
                child: Text(
                    style: const TextStyle(color: Color(0xffffffff)),
                    notifier.items[index].text[0]),
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
                                      if (text.isNotEmpty) {
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
                            ));
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
    });
  }
}
