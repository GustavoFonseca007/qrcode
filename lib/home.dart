import 'dart:io';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, double> _qrCodeValues = {};

  String? _scannedQRCode;
  String? _documentId;
  File? _capturedImage;
  Map<String, String> processedData = {};
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 30.0, color: Colors.white),
        ),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _sendEmail(String userEmail, String userName, String category,
      Map<String, String> processedData, File? image) async {
    final smtpServer = hotmail('gustavo.pessoa2017@hotmail.com', 'P@to01234567890');

    final message = Message()
      ..from = Address('gustavo.pessoa2017@hotmail.com', 'Appopportunity')
      ..recipients.add('gustavo.pessoa2017@hotmail.com')
      ..subject = 'Nova Fatura - Categoria: $category'
      ..text =
          'Usuário: $userName\nE-mail: $userEmail\nCategoria: $category\nDados Processados: $processedData';

    if (image != null) {
      final imageAttachment = FileAttachment(image);
      message.attachments.add(imageAttachment);
    }

    try {
      final sendReport = await send(message, smtpServer);
      print('E-mail enviado: ${sendReport.toString()}');
    } catch (e) {
      print('Erro ao enviar e-mail: $e');
    }
  }

  Future<void> _scanQRCode() async {
    try {
      ScanResult result = await BarcodeScanner.scan();
      print('Conteúdo do QR Code lido: ${result.rawContent}');
      setState(() {
        _scannedQRCode = result.rawContent;
      });
    } catch (e) {
      print('Erro ao escanear QR Code: $e');
    }
  }

  Future<void> _updateTotalFinalValue(double totalFinalValue) async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'totalFinalValue': totalFinalValue}, SetOptions(merge: true));
    } catch (e) {
      print('Erro ao atualizar total final no Firestore: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? file =
          await ImagePicker().pickImage(source: ImageSource.camera);

      if (file != null) {
        setState(() {
          _capturedImage = File(file.path);
        });
      }
    } catch (e) {
      print('Erro ao tirar foto: $e');
    }
  }

  Future<void> _uploadReciboVerdeData() async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      String userName = FirebaseAuth.instance.currentUser?.displayName ?? '';

      if (_capturedImage == null) {
        print('Erro: _capturedImage é nulo.');
        return;
      }

      double? enteredValue = await _showValueDialog();
      if (enteredValue == null) {
        return;
      }

      String valorComEuro = '€${enteredValue.toStringAsFixed(2)}';

      DocumentReference documentReference = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('recibos_verdes')
          .add({
        'value': valorComEuro,
        'timestamp': FieldValue.serverTimestamp(),
      });

      String documentId = documentReference.id;

      String fileName =
          'ReciboVerdeFotos/$userId/$userName/${DateTime.now().millisecondsSinceEpoch}.jpg';
      firebase_storage.Reference storageReference =
          firebase_storage.FirebaseStorage.instance.ref().child(fileName);
      await storageReference.putFile(_capturedImage!);

      print(
          'Dados enviados para Firestore e imagem enviada para o Firebase Storage com sucesso. ID do documento: $documentId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recibo Verde Enviado com Sucesso',
            style: TextStyle(fontSize: 30.0, color: Colors.white),
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _capturedImage = null;
      });
    } catch (e) {
      print(
          'Erro ao enviar dados para Firestore e imagem para o Firebase Storage: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha no envio, por favor, tente novamente, ou faça Upload da fatura(verifique a terceira opção do menu).',
            style: TextStyle(fontSize: 30.0),
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<double?> _showValueDialog() async {
    TextEditingController valueController = TextEditingController();

    return showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Valor do Recibo Verde'),
          content: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text('€', style: TextStyle(fontSize: 18.0)),
                  ),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: TextField(
                      controller: valueController,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Insira o valor',
                        prefixText: '€ ',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                double? enteredValue;
                try {
                  enteredValue = double.tryParse(
                          valueController.text.replaceAll(',', '.')) ??
                      0.0;
                } catch (e) {
                  print('Erro ao converter o valor: $e');
                }
                Navigator.of(context).pop(enteredValue);
              },
              child: Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Map<String, String> processQRCodeData(String rawData) {
    print('Dados brutos do QR Code: $rawData');
    List<String> fields = rawData.split('*');
    Map<String, String> dataMap = {};

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
      'I3': 'Valor líquido da fatura',
      'I4': 'Outro valor líquido da fatura',
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

        if (keyValue[0] == 'I3') {
          double valorCampo =
              double.tryParse(fieldValue.replaceAll(',', '.')) ?? 0.0;
          dataMap[fieldName] = '€${valorCampo.toStringAsFixed(2)}';
        } else {
          dataMap[fieldName] = fieldValue;
        }
      }
    }

    List<String> camposComEuro = ['I7', 'I8', 'N', 'O'];
    for (String campo in camposComEuro) {
      if (dataMap.containsKey(campo)) {
        double valorCampo =
            double.tryParse(dataMap[campo]!.replaceAll(',', '.')) ?? 0.0;
        dataMap[campo] = '€${valorCampo.toStringAsFixed(2)}';
      }
    }

    if (dataMap.containsKey('Data de emissão da fatura')) {
      String dataEmissao = dataMap['Data de emissão da fatura']!;
      DateTime data = DateTime.parse(dataEmissao);
      String dataFormatada = DateFormat('dd/MM/yyyy').format(data);
      dataMap['Data de emissão da fatura'] = dataFormatada;
    }

    return dataMap;
  }

  Map<String, String> processNewQRCodeData(String rawData) {
    print('Dados brutos do novo QR Code: $rawData');
    List<String> fields = rawData.split('*');
    Map<String, String> dataMap = {};

    for (String field in fields) {
      List<String> keyValue = field.split(':');
      if (keyValue.length == 2) {
        dataMap[keyValue[0]] = keyValue[1];
      }
    }

    if (dataMap.containsKey('I7') && dataMap.containsKey('N')) {
      double totalItens = double.tryParse(dataMap['I7']!) ?? 0.0;
      double ivaItens = double.tryParse(dataMap['N']!) ?? 0.0;
      double valorFinal = totalItens + ivaItens;
      dataMap['O'] = '€${valorFinal.toStringAsFixed(2)}';
    }

    List<String> camposComEuro = ['I7', 'N', 'O'];
    for (String campo in camposComEuro) {
      if (dataMap.containsKey(campo)) {
        double valorCampo = double.tryParse(dataMap[campo]!) ?? 0.0;
        dataMap[campo] = '€${valorCampo.toStringAsFixed(2)}';
      }
    }

    if (dataMap.containsKey('F')) {
      String dataEmissao = dataMap['F']!;
      DateTime data = DateTime.parse(dataEmissao);
      String dataFormatada = DateFormat('dd/MM/yyyy').format(data);
      dataMap['F'] = dataFormatada;
    }

    return dataMap;
  }

  Future<Map<String, String>> getUserInfo() async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userSnapshot.exists) {
        Map<String, dynamic> userData = userSnapshot.data()!;
        String userName = userData['nomeUsuario'] ?? '';
        String userEmail = userData['email'] ?? '';
        return {'name': userName, 'email': userEmail};
      } else {
        return {'name': '', 'email': ''};
      }
    } catch (e) {
      print('Erro ao obter informações do usuário: $e');
      return {'name': '', 'email': ''};
    }
  }

  Map<String, String> addEmptyFields(Map<String, String> data) {
    Map<String, String> result = Map.from(data);

    List<String> allFields = [
      'NIF do emitente',
      'NIF do cliente',
      'País de origem',
      'País de destino',
      'Tipo de fatura',
      'Data de emissão da fatura',
      'Código de controle da fatura',
      'Código do país para o item da fatura',
      'Valor total dos itens da fatura',
      'Valor total do IVA da fatura',
      'Valor final da fatura',
    ];

    for (String field in allFields) {
      if (!result.containsKey(field)) {
        result[field] = '';
      }
    }

    return result;
  }

  double _totalFinalValue = 0.0;

  Future<void> _uploadData(
      String category, Map<String, String> processedData, File? image) async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      String userName = FirebaseAuth.instance.currentUser?.displayName ?? '';

      String _documentId = DateTime.now().millisecondsSinceEpoch.toString();

      String fileName = 'FaturasFoto/$userId/$userName/$_documentId.jpg';

      firebase_storage.Reference storageReference =
          firebase_storage.FirebaseStorage.instance.ref().child(fileName);
      await storageReference.putFile(image!);

      double valorFinal = double.tryParse(
              processedData['Valor final da fatura']!.substring(1)) ??
          0.0;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot<Map<String, dynamic>> userSnapshot = await transaction
            .get(FirebaseFirestore.instance.collection('users').doc(userId));

        double totalFinalValueFirestore =
            userSnapshot['totalFinalValue'] ?? 0.0;
        transaction.update(
            FirebaseFirestore.instance.collection('users').doc(userId), {
          'totalFinalValue': totalFinalValueFirestore + valorFinal,
        });

        List<String> qrCodeIdentifiers =
            userSnapshot['qrCodeIdentifiers'] ?? [];
        qrCodeIdentifiers.add(_documentId);
        transaction.update(
            FirebaseFirestore.instance.collection('users').doc(userId), {
          'qrCodeIdentifiers': qrCodeIdentifiers,
        });
      });

      // Salva o 'Valor final da fatura' na coleção no Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('valores_finais')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'valor_final': valorFinal,
        'qrCodeIdentifier': _documentId,
      });

      processedData = addEmptyFields(processedData);

      if (_checkRequiredFields(processedData)) {
        String documentId = DateTime.now().millisecondsSinceEpoch.toString();

        if ((_scannedQRCode == null || processedData.isEmpty) &&
            (processedData['timestamp']!.isNotEmpty &&
                processedData['documentId']!.isNotEmpty &&
                processedData['category']!.isNotEmpty)) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('faturas_sem_dados')
              .doc(documentId)
              .set({
            'category': processedData['category'],
            'timestamp': processedData['timestamp'],
            'processedData': processedData,
          });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('faturas')
              .doc(documentId)
              .set({
            'category': category,
            'timestamp': FieldValue.serverTimestamp(),
            'processedData': processedData,
            'documentId': _documentId,
          });
        }

        print(
            'Dados enviados para o Firestore, e imagem enviada para o Firebase Storage com sucesso. ID do documento: $documentId');

        Map<String, String> userInfo = await getUserInfo();

        _showSuccessSnackbar();

        await Future.delayed(Duration(milliseconds: 500));

        _resetData();

        await _sendEmail(userInfo['email'] ?? '', userInfo['name'] ?? '',
            category, processedData, image);

        _resetData();
      } else {
        _showMissingFieldsSnackbar();
      }
    } catch (e, stackTrace) {
      print(
          'Erro ao enviar dados para o Firestore e imagem para o Firebase Storage: $e');
      print(stackTrace);

      _showFailureSnackbar();

      _resetImageData();
    }
  }

  Future<double> _getTotalFinalValue() async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('valores_finais')
              .get();

      double totalFinalValueFirestore =
          querySnapshot.docs.fold(0, (previous, doc) {
        if (_qrCodeValues.containsKey(doc.id)) {
          return previous + _qrCodeValues[doc.id]!;
        }
        return previous;
      });

      double totalFinalValue = _totalFinalValue + totalFinalValueFirestore;

      return totalFinalValue;
    } catch (e) {
      print('Erro ao obter o total do Valor final da fatura: $e');
      return 0.0;
    }
  }

  bool _checkRequiredFields(Map<String, String> processedData) {
    List<String> requiredFields = [
      'NIF do emitente',
      'NIF do cliente',
      'País de origem',
      'País de destino',
      'Tipo de fatura',
      'Data de emissão da fatura',
      'Código de controle da fatura',
      'Código do país para o item da fatura',
      'Valor total dos itens da fatura',
      'Valor total do IVA da fatura',
      'Valor final da fatura',
    ];

    for (String field in requiredFields) {
      if (!processedData.containsKey(field) || processedData[field]!.isEmpty) {
        return false;
      }
    }

    return true;
  }

  void _showMissingFieldsSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Campos do QR CODE ficaram em branco, por favor, tente novamente ou faça um upload da fatura.',
          style: TextStyle(fontSize: 30.0),
        ),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fatura Enviada com Sucesso',
          style: TextStyle(
            fontSize: 30.0,
            backgroundColor: Colors.green,
          ),
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _resetData() {
    setState(() {
      _scannedQRCode = null;
      _capturedImage = null;
    });
  }

  void _showFailureSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Falha no envio, por favor, tente novamente, ou faça Upload da fatura(verifique a terceira opção do menu).',
          style: TextStyle(fontSize: 30.0),
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _resetImageData() {
    setState(() {
      _capturedImage = null;
    });
  }

  Future<void> _showCategoryDialog() async {
    Map<String, String> processedData = _scannedQRCode != null
        ? processQRCodeData(_scannedQRCode!)
        : {
            'NIF do emitente': '',
            'NIF do cliente': '',
            'País de origem': '',
            'País de destino': '',
            'Tipo de fatura': '',
            'Data de emissão da fatura': '',
            'Código de controle da fatura': '',
            'Código do país para o item da fatura': '',
            'Valor total dos itens da fatura': '',
            'Outro valor dos itens da fatura': '',
            'Valor total do IVA da fatura': '',
            'Valor final da fatura': '',
          };

    if (processedData.isEmpty) {
      processedData = processNewQRCodeData(_scannedQRCode!);
    }

    bool isDuplicate = await checkDuplicateFatura(processedData);

    if (isDuplicate) {
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

    String selectedCategory = '';
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Escolha a categoria'),
          content: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  selectedCategory = 'Gasolina';
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  child: Center(child: Text('Gasolina')),
                ),
              ),
              SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: () {
                  selectedCategory = 'Gaso-GLP';
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  child: Center(child: Text('Gaso-GLP')),
                ),
              ),
              SizedBox(height: 8.0),
              ElevatedButton(
                onPressed: () {
                  selectedCategory = 'Outras Faturas';
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  child: Center(child: Text('Outras Faturas')),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedCategory.isNotEmpty) {
      if (_capturedImage != null) {
        _documentId = DateTime.now().millisecondsSinceEpoch.toString();
        await _uploadData(selectedCategory, processedData, _capturedImage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha no envio, por favor, tente novamente, ou faça Upload da fatura (verifique a terceira opção do menu).',
              style: TextStyle(fontSize: 30.0),
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanAndProcessQRCode() async {
    try {
      ScanResult result = await BarcodeScanner.scan();
      print('Conteúdo do QR Code lido: ${result.rawContent}');

      Map<String, String> processedData =
          processNewQRCodeData(result.rawContent);

      setState(() {
        _scannedQRCode = result.rawContent;
        processedData = addEmptyFields(processedData);
      });

      await _showCategoryDialog();

      double valorFinal = double.tryParse(
              processedData['Valor final da fatura']!.substring(1)) ??
          0.0;
      _qrCodeValues[result.rawContent] = valorFinal;
    } catch (e) {
      print('Erro ao escanear e processar QR Code: $e');
    }
  }

  Future<bool> checkDuplicateFatura(Map<String, String> data) async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (data.isEmpty) {
        return false;
      }

      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('faturas')
              .where('processedData', isEqualTo: data)
              .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Erro ao verificar duplicata da fatura: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner e Foto'),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: ListView(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () async {
                await _scanQRCode();

                if (_scannedQRCode != null) {
                  await _takePhoto();
                  await _showCategoryDialog();
                }
              },
              child: Container(
                constraints: BoxConstraints(maxHeight: 50),
                child: Center(child: Text('Escanear QR Code e Tirar Foto')),
              ),
            ),
          ),
          SizedBox(
            height: 16,
          ),
          ElevatedButton(
            onPressed: () async {
              await _takePhoto();

              if (_capturedImage != null) {
                await _uploadReciboVerdeData();
              }
            },
            child: Container(
              constraints: BoxConstraints(maxHeight: 50),
              child: Center(child: Text('Recibo Verde')),
            ),
          ),
          if (_capturedImage != null) _buildImagePreview(),
          if (_scannedQRCode != null) _buildQRCodeResult(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.file(_capturedImage!),
    );
  }

  Widget _buildQRCodeResult() {
    Map<String, String> processedData = processQRCodeData(_scannedQRCode!);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildInfoWidgets(processedData),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoWidget(String key, String value) {
    String formattedValue = value;

    List<String> camposComEuro = [
      "Outro valor dos itens da fatura",
      "Outro valor líquido da fatura",
      "Valor final da fatura",
      "Valor total do IVA da fatura",
      "Valor total dos itens da fatura"
    ];

    if (camposComEuro.contains(key)) {
      formattedValue = '€$value';
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15.0,
            ),
          ),
          Text(
            formattedValue,
            style: TextStyle(fontSize: 15.0),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInfoWidgets(Map<String, String> processedData) {
    return processedData.entries.map((entry) {
      return _buildInfoWidget(entry.key, entry.value);
    }).toList();
  }
}
