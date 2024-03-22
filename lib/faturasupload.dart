import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_pickers/image_pickers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;
import 'package:scan/scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class Upload extends StatefulWidget {
  @override
  _UploadState createState() => _UploadState();
}

class _UploadState extends State<Upload> {
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MyAppHomePage(platformVersion: _platformVersion);
  }
}

class MyAppHomePage extends StatefulWidget {
  final String platformVersion;

  const MyAppHomePage({required this.platformVersion});

  @override
  _MyAppHomePageState createState() => _MyAppHomePageState();
}

class _MyAppHomePageState extends State<MyAppHomePage> {
  String qrcode = 'Unknown';
  List<String> documentUids = [];
  late String fileName; // Adicione esta linha

  @override
  void initState() {
    super.initState();
    _loadDocumentUids();
    ;
  }

  void _showPhotoOptionWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Aviso'),
          content: Text(
            'A opção de fotografia dentro do botão está desativada. '
            'Por favor, escolha uma imagem da galeria.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _openFile(String uid) async {
    try {
      Directory? appDocumentsDirectory =
          await getApplicationDocumentsDirectory();
      String pdfDirectoryPath = path.join(appDocumentsDirectory!.path, uid);
    } catch (e) {
      print('Error opening the file: $e');
    }
  }

  Future<void> _loadDocumentUids() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        String uid = user.uid;

        CollectionReference documentsCollection = FirebaseFirestore.instance
            .collection('uploadedFiles')
            .doc(uid)
            .collection('documents');

        QuerySnapshot querySnapshot = await documentsCollection.get();

        List<String> updatedDocumentUids =
            querySnapshot.docs.map((doc) => doc.id).toList();

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setStringList('documentUids', updatedDocumentUids);

        setState(() {
          documentUids = updatedDocumentUids;
        });
      } catch (e) {
        print('Error loading document UIDs: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('upload das Faturas'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                child: Text("Ler QR Code da Fatura"),
                onPressed: () async {
                  await _checkPermissions();

                  List<Media>? res = await ImagePickers.pickerPaths(
                    galleryMode: GalleryMode.image,
                    selectCount: 1,
                    showCamera: true,
                    compressSize: 500,
                  );

                  if (res != null && res.isNotEmpty) {
                    if (res[0]?.path?.contains("camera") ?? false) {
                      _showPhotoOptionWarning();
                    } else {
                      String? str = await Scan.parse(res[0]?.path ?? '');
                      if (str != null) {
                        setState(() {
                          fileName = 'nome_do_arquivo.jpg';
                        });
                        _uploadToFirestore(res[0].path ?? '', str);
                      }
                    }
                  }
                },
              ),
            ),
            SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: documentUids.map((uid) {
                return GestureDetector(
                  onTap: () {
                    _openFile(uid);
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 14.0),
                    child: Text(
                      uid,
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<MapEntry<String, String>>> _fetchFaturaData(String uid) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('uploadedFiles')
          .doc(uid)
          .collection('documents')
          .doc(uid)
          .get();

      if (snapshot.exists) {
        var scanResult = snapshot.get('scanResult');
        print('Dados do Firestore: $scanResult');

        List<MapEntry<String, String>> data = _processQRCodeData(scanResult);
        print('Dados da Fatura: $data');

        return data;
      } else {
        print('Documento não encontrado no Firestore para a UID: $uid');
        return [];
      }
    } catch (e) {
      print('Erro ao buscar dados da fatura: $e');
      return [];
    }
  }

  List<MapEntry<String, String>> _processQRCodeData(String rawData) {
    List<String> fields = rawData.split('*');
    List<MapEntry<String, String>> dataEntries = [];

    Map<String, String> fieldNames = {
      'A': 'NIF do emitente',
      'B': 'NIF do cliente',
      'C': 'País de origem',
      'D': 'País de destino',
      'E': 'Tipo de fatura',
      'F': 'Data de emissão da fatura',
      'G': 'Número da fatura',
      'H': 'Código de controle da fatura',
      'I1': 'Código do país para o item da fatura',
      'I7': 'Valor total dos itens da fatura',
      'I8': 'Outro valor dos itens da fatura',
      'N': 'Valor total do IVA da fatura',
      'O': 'Valor final da fatura',
      'Q': 'Outro código de controle',
      'R': 'Número adicional',
    };

    for (String field in fields) {
      List<String> keyValue = field.split(':');
      if (keyValue.length == 2 && fieldNames.containsKey(keyValue[0])) {
        String fieldName = fieldNames[keyValue[0]]!;
        String fieldValue = keyValue[1];

        if (['I7', 'I8', 'N', 'O'].contains(keyValue[0])) {
          double valorCampo =
              double.tryParse(fieldValue.replaceAll(',', '.')) ?? 0.0;
          fieldValue = '€${valorCampo.toStringAsFixed(2)}';
        }

        dataEntries.add(MapEntry(fieldName, fieldValue));
      }
    }

    MapEntry<String, String>? dataEntry = dataEntries.firstWhere(
      (element) => element.key == fieldNames['F'],
      orElse: () => MapEntry(fieldNames['F']!, ''),
    );
    if (dataEntry != null && dataEntry.value.isNotEmpty) {
      DateTime? data = _parseDate(dataEntry.value);
      if (data != null) {
        String dataFormatada = DateFormat('dd/MM/yyyy').format(data);
        dataEntries.removeWhere((element) => element.key == fieldNames['F']);
        dataEntries.add(MapEntry(fieldNames['F']!, dataFormatada));
      }
    }

    return dataEntries;
  }

  DateTime? _parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  Future<void> _checkPermissions() async {
    var status = await Permission.storage.status;
    if (status != PermissionStatus.granted) {
      var result = await Permission.storage.request();
      if (result == PermissionStatus.granted) {
      } else {
        print('Permissão negada pelo usuário');
      }
    } else {}
  }

  Future<void> _uploadToFirestore(String imagePath, String scanResult) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      String uid = user.uid;
      String email = user.email ?? 'N/A';
      String nomeUsuario = user.displayName ?? 'N/A';

      CollectionReference userCollection =
          FirebaseFirestore.instance.collection('uploadedFiles');

      await userCollection.doc(uid).set({
        'email': email,
        'nomeUsuario': nomeUsuario,
      });

      CollectionReference documentsCollection =
          userCollection.doc(uid).collection('documents');

      String sanitizedImagePath = imagePath.replaceAll('//', '__');

      QuerySnapshot existingDocs = await documentsCollection
          .where('scanResult', isEqualTo: scanResult)
          .get();

      if (existingDocs.docs.isNotEmpty) {
        print('Dados duplicados. Não realizando o upload novamente.');

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Aviso'),
              content: Text('Esta fatura já foi enviada anteriormente.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );

        return;
      }

      Map<String, String> fieldNames = {
        'A': 'NIF do emitente',
        'B': 'NIF do cliente',
        'C': 'País de origem',
        'D': 'País de destino',
        'E': 'Tipo de fatura',
        'F': 'Data de emissão da fatura',
        'G': 'Número da fatura',
        'H': 'Código de controle da fatura',
        'I1': 'Código do país para o item da fatura',
        'I7': 'Valor total dos itens da fatura',
        'I8': 'Outro valor dos itens da fatura',
        'N': 'Valor total do IVA da fatura',
        'O': 'Valor final da fatura',
        'Q': 'Outro código de controle',
        'R': 'Número adicional',
      };

      Map<String, dynamic> firestoreData = {
        'imagePath': sanitizedImagePath,
        'scanResult': scanResult,
        'timestamp': FieldValue.serverTimestamp(),
      };

      for (var entry in fieldNames.entries) {
        firestoreData[entry.value] = '';
      }

      for (var entry in _processQRCodeData(scanResult)) {
        firestoreData[entry.key] = entry.value;
      }

      Directory appDocumentsDirectory =
          await getApplicationDocumentsDirectory();
      String directoryPath = '${appDocumentsDirectory.path}/$uid';

      await Directory(directoryPath).create(recursive: true);

      DocumentReference documentRef =
          await documentsCollection.add(firestoreData);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> updatedDocumentUids =
          prefs.getStringList('documentUids') ?? [];
      updatedDocumentUids.add(documentRef.id);
      prefs.setStringList('documentUids', updatedDocumentUids);

      if (mounted) {
        setState(() {
          documentUids = updatedDocumentUids;
        });
      }

      firebase_storage.Reference storageRef = firebase_storage
          .FirebaseStorage.instance
          .ref()
          .child('FaturasUpload')
          .child('$uid/$nomeUsuario/${documentRef.id}.jpg');

      await storageRef.putFile(File(imagePath));

      String imageUrl = await storageRef.getDownloadURL();

      await documentRef.update({'imageUrl': imageUrl});

      await _generateAndSavePdf(
          documentRef.id, _processQRCodeData(scanResult), imagePath);

      final smtpServer = hotmail('Appopportunity@hotmail.com', 'Portug@l2024');

      final processedData = _processQRCodeData(scanResult);

      final message = Message()
        ..from = Address('Appopportunity@hotmail.com', 'Appopportunity')
        ..recipients.add('Appopportunity@hotmail.com')
        ..subject = 'Upload da Fatura'
        ..text = '''
Usuário: $nomeUsuario
E-mail: $email
Dados Processados:
${processedData.map((entry) => '${entry.key}: ${entry.value}').join('\n')}
''';

      if (imagePath != null) {
        final imageAttachment = FileAttachment(File(imagePath));
        message.attachments.add(imageAttachment);
      }

      try {
        final sendReport = await send(message, smtpServer);
        print('E-mail enviado: ${sendReport.toString()}');
      } catch (e, stackTrace) {
        print('Erro ao enviar e-mail: $e');
        print('StackTrace: $stackTrace');
      }
    }
  }

  Future<void> _generateAndSavePdf(
      String uid, List<MapEntry<String, String>> data, String imagePath) async {
    try {
      Directory appDocumentsDirectory =
          await getApplicationDocumentsDirectory();
      Directory pdfDirectory = Directory('${appDocumentsDirectory.path}/$uid');
      if (!await pdfDirectory.exists()) {
        pdfDirectory.createSync(recursive: true);
      }

      final pdf = pw.Document();

      final ByteData fontData =
          await rootBundle.load('fonts/Roboto-BoldItalic.ttf');
      final pw.Font customFont = pw.Font.ttf(fontData.buffer.asByteData());

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Fatura - $uid',
                      style: pw.TextStyle(
                          font: customFont,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  for (var entry in data)
                    pw.Text('${entry.key}: ${entry.value}',
                        style: pw.TextStyle(font: customFont)),
                  pw.Image(pw.MemoryImage(File(imagePath).readAsBytesSync())),
                ],
              ),
            );
          },
        ),
      );
      String pdfPath = '${appDocumentsDirectory.path}/$uid/${uid}_$uid.pdf';

      File pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      print('PDF generated successfully: $pdfPath');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error generating PDF: $e');
    }
  }
}
