import 'package:qrcode/faturas.dart';
import 'package:qrcode/login.dart';
import 'package:qrcode/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PerfilScreen extends StatefulWidget {
  @override
  _PerfilScreenState createState() => _PerfilScreenState();
}

class ThemeIcon extends StatefulWidget {
  @override
  _ThemeIconState createState() => _ThemeIconState();
}

class _ThemeIconState extends State<ThemeIcon> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: ThemeService().isDarkMode()
          ? Icon(Icons.wb_sunny)
          : Icon(Icons.nightlight_round),
      onPressed: () {
        ThemeService().switchTheme();
        setState(() {});
      },
    );
  }
}

class _PerfilScreenState extends State<PerfilScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _appName = '';
  String _appVersion = '';
  String _appEmail = 'gustavo.pessoa2017@hotmail.com';
  late String _username = '';
  late String _email = '';
  late String _uid = '';
  late User? _user;
  TextEditingController _bugReportController = TextEditingController();
  String? _selectedOption;
  String? _displayedOption;
  bool _isDarkMode = false;
  late String _periodo;
  late String _rendimentos;
  late String _frota;
  late String _outrasFaturas;
  late String _reciboVerdeEmitido;
  late String _reciboVerdeEmitir;
  late String _iva;

  List<String> meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  List<String> anos = [
    '2022',
    '2023',
    '2024',
  ];

  String _selectedMonth = 'Janeiro';
  String _selectedYear = '2022';

 @override
void initState() {
  super.initState();
  _user = _auth.currentUser;

  if (_user != null) {
    _uid = _user!.uid;
    _loadUserData();
  } else {
    print('Usuário não autenticado.');
  }

  _loadAppInfo();
  _initializeLateVariables(); 
}
  Future<void> _loadAppInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appName = packageInfo.appName;
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      print('Erro ao carregar informações da aplicação: $e');
    }
  }
  void _initializeLateVariables() {
  _periodo = 'Carregando...';
  _rendimentos = 'Carregando...';
  _frota = 'Carregando...';
  _outrasFaturas = 'Carregando...';
  _reciboVerdeEmitido = 'Carregando...';
  _reciboVerdeEmitir = 'Carregando...';
  _iva = 'Carregando...';
}

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_user?.uid).get();

      if (userDoc.exists) {
        if (mounted) {
          setState(() {
            _username = userDoc['nomeUsuario'];
            _email = userDoc['email'];
            _uid = _user!.uid;

            _loadAdditionalUserData(userDoc);
          });
        }
      } else {
        print('Documento de usuário não encontrado.');
      }
    } catch (e) {
      print('Erro ao carregar dados do usuário: $e');
    }
  }

  void _loadAdditionalUserData(DocumentSnapshot userDoc) {
    setState(() {
      _periodo = userDoc['periodo'] ?? 'Não definido';
      _rendimentos = userDoc['rendimentos'] ?? 'Não definido';
      _frota = userDoc['frota'] ?? 'Não definido';
      _outrasFaturas = userDoc['outrasFaturas'] ?? 'Não definido';
      _reciboVerdeEmitido = userDoc['reciboVerdeEmitido'] ?? 'Não definido';
      _reciboVerdeEmitir = userDoc['reciboVerdeEmitir'] ?? 'Não definido';
      _iva = userDoc['iva'] ?? 'Não definido';
    });
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  Future<void> _submitBugReport(String selectedOption) async {
    String message = _bugReportController.text;

    if (message.isNotEmpty) {
      await FirebaseFirestore.instance.collection('bug_reports').add({
        'option': selectedOption,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Relatório de bug enviado com sucesso!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, insira uma mensagem antes de enviar.'),
        ),
      );
    }
  }

  Future<void> _showBugReportDialog() async {
    List<String> bugOptions = [
      "tirar foto",
      "baixar foto",
      "visualizar foto",
      "escanear qr code",
      "salvar fatura",
      "visualizar fatura",
      "baixar fatura",
      "quero mudar o meu nome",
    ];

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Escolha uma opção'),
          content: Column(
            children: [
              DropdownButton<String>(
                hint: Text('Selecione uma opção'),
                value: _selectedOption,
                items: bugOptions.map((option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOption = value;
                    _displayedOption = value;
                  });

                  Navigator.of(context).pop();
                  _showBugReportDialog();
                },
              ),
              TextFormField(
                controller: _bugReportController,
                maxLength: 100,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Descreva o problema',
                ),
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
                if (_selectedOption != null) {
                  _submitBugReport(_selectedOption!);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor, selecione uma opção.'),
                    ),
                  );
                }
              },
              child: Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Informações do Aplicativo'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nome do App: $_appName',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Versão do App: $_appVersion',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Desenvolvedor: $_appEmail',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          ThemeIcon(),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              await _auth.signOut();
              GetStorage().remove('isLoggedIn');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Login()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () {
              _showAppInfo();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Nome de Usuário:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                _username ?? 'Carregando...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Text(
                'Email:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                _email ?? 'Carregando...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Text(
                'UID do Usuário:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                _uid ?? 'Carregando...',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Text(
                'Selecione o Mês:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _selectedMonth,
                items: meses.map((String mes) {
                  return DropdownMenuItem<String>(
                    value: mes,
                    child: Text(mes),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedMonth = value!;
                  });
                },
              ),
              SizedBox(height: 20),
              Text(
                'Selecione o Ano:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _selectedYear,
                items: anos.map((String ano) {
                  return DropdownMenuItem<String>(
                    value: ano,
                    child: Text(ano),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedYear = value!;
                  });
                },
              ),
              SizedBox(height: 20),
              Text(
                'Campos para $_selectedMonth de $_selectedYear:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text('Periodo: $_periodo'),
              Text('Rendimentos: $_rendimentos'),
              Text('Frota: $_frota'),
              Text('Outras Faturas: $_outrasFaturas'),
              Text('Recibo Verde Emitido: $_reciboVerdeEmitido'),
              Text('Recibo Verde Emitir: $_reciboVerdeEmitir'),
              Text('IVA: $_iva'),
              ElevatedButton(
                onPressed: () {
                  _showBugReportDialog();
                },
                child: Text('Reportar erro na app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
