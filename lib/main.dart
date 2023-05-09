import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'Shared Notes';

    return MaterialApp(
      title: title,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(title),
        ),
        body: const Notes(["Watermelon", "Bread", "Bananas", "Flour"]),
      ),
    );
  }
}

class Notes extends StatelessWidget {
  final List<String> items;

  const Notes(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xff1f92fc),
              child: Text(style: const TextStyle(color: Color(0xffffffff)),items[index][0]),
            ),
            title: Text(items[index]),
          );
        }
    );
  }

}
