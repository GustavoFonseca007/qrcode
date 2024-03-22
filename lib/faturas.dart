import 'dart:io';
import 'dart:typed_data';
import 'package:qrcode/extrato.dart';
import 'package:qrcode/perfil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdfWidgets;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:dio/dio.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class FaturasScreen extends StatefulWidget {
  @override
  _FaturasScreenState createState() => _FaturasScreenState();
}

class _FaturasScreenState extends State<FaturasScreen> {
  late Stream<QuerySnapshot> _faturasStream;

  List<Map<String, dynamic>> _fotosList = [];
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _faturasStream = Stream.empty();
  }

  _checkLoginStatus() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await _fetchData();
      String userId = user.uid;
      _faturasStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('faturas')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  _fetchData() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userId = user.uid;

      firebase_storage.ListResult result = await firebase_storage
          .FirebaseStorage.instance
          .ref('FaturasFoto/$userId/${user.displayName}')
          .listAll();

      _fotosList = result.items.map((item) {
        return {
          'nome': item.name,
          'url': item.fullPath,
        };
      }).toList();

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<Stream<QuerySnapshot>> _fetchFaturasStream() async {
    await _checkLoginStatus();
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userId = user.uid;
      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('faturas')
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
    throw Exception("User not logged in");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Faturas'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'extratos') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ExtratosScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'extratos',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_drop_down),
                      Text('Extratos'),
                    ],
                  ),
                ),
              ];
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () async {
              await _showCategoryFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _faturasStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SpinKitCircle(
                      color: Colors.blue,
                      size: 50.0,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Erro: ${snapshot.error}');
                }

                List<DocumentSnapshot> documents = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  documents = snapshot.data!.docs;

                  if (_selectedCategory.isNotEmpty) {
                    documents.retainWhere(
                      (document) => document['category'] == _selectedCategory,
                    );
                  }
                }

                return documents.isEmpty
                    ? Center(
                        child: Text('Nenhuma fatura encontrada.'),
                      )
                    : ListView.builder(
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          final document = documents[index];
                          return _buildFaturaListItem(document);
                        },
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaturaListItem(DocumentSnapshot document) {
    return ListTile(
      title: Text('ID: ${document.id}'),
      subtitle: Text('Categoria: ${document['category']}'),
      onTap: () {
        _showOptionsDialog(document);
      },
    );
  }

  void _showOptionsDialog(DocumentSnapshot document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Opções'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text('Visualizar Fatura'),
                onTap: () {
                  _viewFatura(document);
                },
              ),
              ListTile(
                title: Text('Baixar Fatura'),
                onTap: () {
                  _downloadFatura(document);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCategoryFilterDialog() async {
    String selectedCategory = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Escolha a Categoria'),
          content: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  selectedCategory = 'Tudo';
                  Navigator.of(context).pop();
                },
                child: Text('Tudo'),
              ),
              ElevatedButton(
                onPressed: () {
                  selectedCategory = 'Gasolina';
                  Navigator.of(context).pop();
                },
                child: Text('Gasolina'),
              ),
              ElevatedButton(
                onPressed: () {
                  selectedCategory = 'Gaso-GLP';
                  Navigator.of(context).pop();
                },
                child: Text('Gaso-GLP'),
              ),
              ElevatedButton(
                onPressed: () {
                  selectedCategory = 'Outras Faturas';
                  Navigator.of(context).pop();
                },
                child: Text('Outras Faturas'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedCategory == 'Tudo') {
      _selectedCategory = '';
    } else {
      _selectedCategory = selectedCategory;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _downloadFatura(DocumentSnapshot document) async {
    final pdf = pdfWidgets.Document();

    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    List<pdfWidgets.Widget> widgets = [];

    final String nomeFatura = data['nome'] ?? 'Sem Nome';

    widgets.add(
      pdfWidgets.Text(
        'Nome da Fatura: $nomeFatura',
        style: pdfWidgets.TextStyle(
          font: pdfWidgets.Font.ttf(
            await rootBundle.load('fonts/Roboto-BoldItalic.ttf'),
          ),
        ),
      ),
    );

    data.forEach((key, value) async {
      if (key != 'timestamp') {
        widgets.add(
          pdfWidgets.Text(
            '$key: $value',
            style: pdfWidgets.TextStyle(
              font: pdfWidgets.Font.ttf(
                await rootBundle.load('fonts/Roboto-BoldItalic.ttf'),
              ),
            ),
          ),
        );
      }
    });

    pdf.addPage(
      pdfWidgets.Page(
        build: (pdfWidgets.Context context) => pdfWidgets.Column(
          children: widgets,
        ),
      ),
    );

    try {
      final downloadsDirectory = await getExternalStorageDirectory();
      final appDirectory =
          path.join(downloadsDirectory!.path, 'com.example.projetoqrcode');

      if (!(await Directory(appDirectory).exists())) {
        await Directory(appDirectory).create(recursive: true);
      }

      final fileName = 'fatura_$nomeFatura.pdf';
      final filePath = path.join(appDirectory, fileName);

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      OpenFile.open(filePath);

      print('Fatura salva em: $filePath');
    } catch (e) {
      print('Erro ao salvar a fatura: $e');
    }

    Navigator.of(context).pop();
  }

  Future<void> _deleteFatura(DocumentSnapshot document) async {}

  Future<void> _deleteFoto(Map<String, dynamic> foto) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String userId = user.uid;
      String photoName = foto['nome'];

      await firebase_storage.FirebaseStorage.instance
          .ref('FaturasFoto/$userId/${user.displayName}/$photoName')
          .delete();

      _fotosList.removeWhere((element) => element['nome'] == photoName);

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _viewFatura(DocumentSnapshot document) async {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;

    final pdf = pdfWidgets.Document();

    List<pdfWidgets.Widget> widgets = [];

    final String nomeFatura = data['nome'] ?? 'Sem Nome';

    widgets.add(
      pdfWidgets.Text(
        'Nome da Fatura: $nomeFatura',
        style: pdfWidgets.TextStyle(
          font: pdfWidgets.Font.ttf(
            await rootBundle.load('fonts/Roboto-BoldItalic.ttf'),
          ),
        ),
      ),
    );

    data.forEach((key, value) async {
      if (key != 'timestamp') {
        widgets.add(
          pdfWidgets.Text(
            '$key: $value',
            style: pdfWidgets.TextStyle(
              font: pdfWidgets.Font.ttf(
                await rootBundle.load('fonts/Roboto-BoldItalic.ttf'),
              ),
            ),
          ),
        );
      }
    });

    pdf.addPage(
      pdfWidgets.Page(
        build: (pdfWidgets.Context context) => pdfWidgets.Column(
          children: widgets,
        ),
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'fatura_${nomeFatura}_$timestamp.pdf';
      final tempFilePath = path.join(tempDir.path, fileName);

      final file = File(tempFilePath);
      await file.writeAsBytes(await pdf.save());

      OpenFile.open(tempFilePath);
    } catch (e) {
      print('Erro ao visualizar a fatura como PDF: $e');
    }
  }
}
