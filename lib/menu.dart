import 'package:flutter/material.dart';
import 'package:qrcode/faturas.dart';
import 'package:qrcode/faturasupload.dart';
import 'package:qrcode/main.dart';
import 'package:qrcode/perfil.dart';
import 'package:qrcode/home.dart';

class Menu extends StatefulWidget {
  const Menu({Key? key}) : super(key: key);

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  int _selectedIndex = 0;
  late PageController _pageController;

  static final List<Widget> _widgetOptions = [
    HomeScreen(),
    FaturasScreen(),
    Upload(),
    PerfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
        _pageController.animateToPage(index,
            duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
      });
    }
  }

  void _showWelcomeSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ' UPLOAD: a opção de fotografia presente dentro do botão não funciona. Por favor, não tente tirar uma fotografia, pois nenhum dado será enviado, escolha apenas uma imagem da galeria.',
        ),
        duration: Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _widgetOptions,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (_selectedIndex == 2) {
            _showWelcomeSnackBar();
          }
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        elevation: 10,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Color.fromARGB(245, 69, 230, 20),
        unselectedItemColor: Colors.blueGrey,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(
              icon: Icon(Icons.description), label: 'Fatura'),
          BottomNavigationBarItem(
              icon: Icon(Icons.upload_sharp), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
