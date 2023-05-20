import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<void> getMp3Files() async {
    try {
      Directory dir = Directory('/storage/emulated/0/Download');
      Database database = await bdhelper.initializeDatabase();
      var a = await database.query('music');
      for (var i in a) {
        print(i['path']);
      }
      await for (FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.mp3')) {
          await database.insert(
              "music", {'path': entity.path, 'is_fav': 0, 'is_playing': 0});
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('error $e');
    }
  }

  Future<void> requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  @override
  initState() {
    super.initState();
    requestPermission();
    getMp3Files();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AudioPlayerProvider(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'mp3',
        home: playerpage(),
      ),
    );
  }
}

class playerpage extends StatefulWidget {
  const playerpage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _playerpageState createState() => _playerpageState();
}

class _playerpageState extends State<playerpage> {
  List<fichier_mp3> fichiers = [];
  late AudioPlayerProvider providreaudio;

  int i = -1;
  @override
  void initState() {
    super.initState();

    providreaudio = Provider.of<AudioPlayerProvider>(context, listen: false);
  }

  List<fichier_mp3> tmp = [];

  List<fichier_mp3> favFiles = [];
  bool like = false;
  var basedone = bdhelper.initializeDatabase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(12, 16, 30, 0.7),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(12, 16, 30, 0.7),
        actions: [
          //show drop down menu
          PopupMenuButton(
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem(
                  value: 0,
                  child: Text(like ? 'voir tous' : 'voir favorite'),
                ),
                const PopupMenuItem(
                  value: 1,
                  child: Text('Telecharger'),
                ),
              ];
            },
            onSelected: (value) {
              if (value == 0) {
                setState(() {
                  like = !like;
                });
              } else {
                final TextEditingController urlc = TextEditingController();
                final TextEditingController titrec = TextEditingController();
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Telecharger'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: urlc,
                            decoration: const InputDecoration(
                              labelText: 'URL',
                              hintText: 'URL de music',
                            ),
                          ),
                          TextField(
                            controller: titrec,
                            decoration: const InputDecoration(
                              labelText: 'Titre',
                              hintText: 'Titre de fichier',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () async {
                            String url = urlc.text;
                            await telecharger(url, titrec.text)
                                .then((value) => Navigator.pop(context));
                            // ignore: use_build_context_synchronously
                          },
                          child: const Text('Telecharger'),
                        ),
                      ],
                    );
                  },
                ).then((value) => setState(() {}));
              }
            },
          ),
        ],
      ),
      body: FutureBuilder(
          future: like ? getlikes() : fetchbasedonne(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(); // Display a loading indicator while waiting for data
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              List data = snapshot.data!;
              fichiers.clear();
              for (var i in data) {
                fichiers.add(fichier_mp3(
                  id: 1,
                  path: i['path'],
                  isFavorite: i['is_fav'] == 1 ? true : false,
                  isPlaying: i['is_playing'] == 1 ? true : false,
                ));
              }
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (BuildContext context, int index) {
                      return cardlist(index);
                    },
                  ),
                  i == -1 ? const SizedBox() : notif(i),
                ],
              );
            }
          }),
    );
  }

  Container notif(index) {
    return Container(
      decoration: BoxDecoration(
        //shadow
        color: Color.fromRGBO(12, 16, 30, 1),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Expanded(
            child: Text(
          fichiers[i]
              .path
              .split('/')
              .last
              .replaceAll("-", " ")
              .split(".mp3")[0],
          style: TextStyle(color: Colors.white),
        )),
        //play button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            button(() async {
              index = index - 1 % fichiers.length;
              providreaudio.playPath(fichiers[index].path);
              await miseajour(fichiers[index].path);
              for (int j = 0; j < fichiers.length; j++) {
                setState(() {
                  i = index;
                });
              }
            }, Icons.skip_previous),
            button(() async {
              providreaudio.playPath(fichiers[index].path);
              await miseajour(fichiers[index].path);
              for (int j = 0; j < fichiers.length; j++) {
                setState(() {
                  i = index;
                });
              }
            }, fichiers[index].isPlaying ? Icons.pause : Icons.play_arrow),
            button(() async {
              index = index + 1 % fichiers.length;
              providreaudio.playPath(fichiers[index].path);
              await miseajour(fichiers[index].path);
              for (int j = 0; j < fichiers.length; j++) {
                setState(() {
                  i = index;
                });
              }
            }, Icons.skip_next),
          ],
        ),
      ]),
    );
  }

  Future miseajour(String path) async {
    var db = await basedone;
    //get current song from path
    List<Map<String, dynamic>> tmp =
        await db.query('music', where: 'is_playing = ?', whereArgs: [1]);
    await db.rawUpdate('UPDATE music SET is_playing = 0 WHERE is_playing = 1');
    try {
      if (tmp[0]['path'].toString() != path) {
        await db.rawUpdate(
            'UPDATE music SET is_playing = 1 WHERE path = ?', [path]);
      }
    } catch (e) {
      await db
          .rawUpdate('UPDATE music SET is_playing = 1 WHERE path = ?', [path]);
    }
  }

  GestureDetector cardlist(int index) {
    return GestureDetector(
      onTap: () async {
        providreaudio.playPath(fichiers[index].path);
        await miseajour(fichiers[index].path);

        setState(() {
          i = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 5, 10, 5),
        decoration: BoxDecoration(
          //shadow
          color: Color.fromRGBO(255, 255, 255, 1),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Expanded(
              child: Text(fichiers[index]
                  .path
                  .split('/')
                  .last
                  .replaceAll("-", " ")
                  .split(".mp3")[0])),
          IconButton(
            onPressed: () {
              likemusic(fichiers[index].path).then((value) => setState(() {}));
            },
            icon: fichiers[index].isFavorite
                ? const Icon(Icons.favorite, color: Colors.red)
                : const Icon(Icons.favorite_border),
          ),
        ]),
      ),
    );
  }

  Future likemusic(String path) async {
    Database database = await bdhelper.initializeDatabase();
    //see if song already is_favorite
    List<Map<String, dynamic>> data =
        await database.query('music', where: 'path = ?', whereArgs: [path]);
    if (data[0]['is_fav'] == 1) {
      await database.update('music', {'is_fav': 0},
          where: 'path = ?', whereArgs: [path]);
    } else {
      await database.update('music', {'is_fav': 1},
          where: 'path = ?', whereArgs: [path]);
    }
  }

  Future getlikes() async {
    Database database = await bdhelper.initializeDatabase();
    List<Map<String, dynamic>> data =
        await database.query('music', where: 'is_fav = ?', whereArgs: [1]);
    return data;
  }

  Future<List<Map<String, dynamic>>> fetchbasedonne() async {
    Database database = await bdhelper.initializeDatabase();
    return await database.query('music');
  }

  Future current(path) async {
    Database database = await bdhelper.initializeDatabase();
    List<Map<String, dynamic>> data = await database.query('music',
        where: 'is_playing = ? or path = ?', whereArgs: [1, path]);
    return data;
  }

  Container button(z, icon) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        //shadow
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: IconButton(
        onPressed: z,
        icon: Icon(
          icon,
          size: 30,
        ),
      ),
    );
  }

  Future<void> telecharger(String url, String title) async {
    try {
      Dio dio = Dio();
      String filename = title;
      Directory downloadsDirectory =
          await getExternalStorageDirectory() ?? Directory('Download');
      String savePath = '${downloadsDirectory.path}/$filename.mp3';
      await dio.download(url, savePath);
      //add to db
      Database database = await bdhelper.initializeDatabase();
      await database.insert('music', {
        'path': savePath,
        'is_fav': 0,
        'is_playing': 0,
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error downloading file: $e');
    }
  }
}

class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayer get audioPlayer => _audioPlayer;
  String path = '';
  play() {
    _audioPlayer.play();
    notifyListeners();
  }

  pause() {
    _audioPlayer.pause();
    notifyListeners();
  }

  stop() {
    _audioPlayer.stop();
    notifyListeners();
  }

  playPath(String path) {
    if (this.path == path) {
      if (_audioPlayer.playing) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
      }
    } else {
      this.path = path;
      _audioPlayer.stop();
      _audioPlayer.setFilePath(path);
      _audioPlayer.play();
    }

    notifyListeners();
  }
}

class fichier_mp3 {
  fichier_mp3(
      {required this.id,
      required this.path,
      required this.isPlaying,
      required this.isFavorite});
  String path;
  int id;
  bool isPlaying;
  bool isFavorite;
}

class bdhelper {
  static Future<Database> initializeDatabase() async {
    String dbPath = 'music.db';
    Database database = await openDatabase(dbPath, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS music (path TEXT PRIMARY KEY, is_fav INTEGER default 0, is_playing INTEGER default 0)');
    });
    return database;
  }
}
