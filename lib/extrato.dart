import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';

Future<List<String>> getPDFUrls() async {
  try {
    String userId = FirebaseAuth.instance.currentUser!.uid;

    ListResult result = await FirebaseStorage.instance
        .ref()
        .child('users/$userId/extratos')
        .list();

    List<Reference> pdfReferences = result.items
        .where((item) => item.name.toLowerCase().endsWith('.pdf'))
        .toList();

    List<String> downloadURLs = await Future.wait(
        pdfReferences.map((pdfReference) => pdfReference.getDownloadURL()));

    print("URLs de Download dos PDFs: $downloadURLs");

    return downloadURLs;
  } catch (e) {
    print("Error getting the PDF file URLs: $e");
    return [];
  }
}

class ExtratosScreen extends StatelessWidget {
  Future<void> _openPDF(BuildContext context, String pdfUrl) async {
    try {
      if (await canLaunch(pdfUrl)) {
        await launch(pdfUrl);
      } else {
        throw 'Could not launch $pdfUrl';
      }
    } catch (e) {
      print('Error opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir o extrato.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Extratos'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<String>>(
        future: getPDFUrls(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError || snapshot.data == null) {
              print("Error loading PDFs: ${snapshot.error}");
              return Text("Error loading PDFs");
            }

            List<String> pdfUrls = snapshot.data!;

            if (pdfUrls.isNotEmpty) {
              return ListView.builder(
                itemCount: pdfUrls.length,
                itemBuilder: (context, index) {
                  String fileName =
                      Uri.decodeFull(pdfUrls[index].split('/').last);

                  return Container(
                    margin: EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Nome do Arquivo: $fileName",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          height: 15,
                          child: PDFView(
                            filePath: pdfUrls[index],
                            autoSpacing: true,
                            pageSnap: true,
                            pageFling: true,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _openPDF(context, pdfUrls[index]),
                          child: Text('Abrir PDF'),
                        ),
                      ],
                    ),
                  );
                },
              );
            } else {
              return Text("No PDFs found in the 'extratos' directory");
            }
          } else {
            return CircularProgressIndicator();
          }
        },
      ),
    );
  }
}
